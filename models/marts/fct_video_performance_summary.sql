{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

with traffic as (

    select
        video_id,
        sum(views)                                                        as total_views,
        sum(case when source_category = 'feed_algorithm' then views else 0 end) as algorithm_views,
        sum(case when source_category = 'organic_search' then views else 0 end) as search_views,
        sum(case when source_category = 'organic_external' then views else 0 end) as external_views,
        sum(case when source_category = 'organic_channel' then views else 0 end) as channel_views,
        sum(case when source_category = 'subscriber' then views else 0 end) as subscriber_views,
        sum(case when source_category = 'other' then views else 0 end)    as other_views
    from {{ ref('stg_yt_traffic_sources') }}
    group by video_id

),

retention as (

    select
        video_id,
        round(avg(average_view_percentage)::numeric, 1)       as avg_retention_pct,
        round(avg(average_view_duration_seconds)::numeric, 1) as avg_duration_sec,
        sum(subscribers_gained)                               as total_subs_gained,
        bool_or(is_loop_video)                                as ever_looped,
        count(distinct snapshot_date)                         as days_with_data
    from {{ ref('stg_yt_video_retention') }}
    group by video_id

),

videos as (

    select
        youtube_video_id,
        generated_title,
        coalesce(youtube_published_at, planned_publish_at)    as effective_publish_at,
        brand_id,
        (raw_plan_entry_json->>'end')::numeric
            - (raw_plan_entry_json->>'start')::numeric        as video_duration_sec
    from {{ ref('stg_shorts_generated_videos') }}
    where youtube_video_id is not null
      and publish_status = 'published'

),

final as (

    select
        v.youtube_video_id,
        v.generated_title,
        v.effective_publish_at,
        v.brand_id,
        round(v.video_duration_sec::numeric, 1)               as video_duration_sec,

        -- trafik hacimleri
        coalesce(t.total_views, 0)                            as total_views,
        coalesce(t.algorithm_views, 0)                        as algorithm_views,
        coalesce(t.search_views, 0)                           as search_views,
        coalesce(t.external_views, 0)                         as external_views,
        coalesce(t.channel_views, 0)                          as channel_views,
        coalesce(t.subscriber_views, 0)                       as subscriber_views,
        coalesce(t.other_views, 0)                            as other_views,

        -- yüzdesel dağılım
        round(coalesce(t.algorithm_views, 0) * 100.0
            / nullif(t.total_views, 0), 1)                    as algorithm_pct,
        round(coalesce(t.search_views, 0) * 100.0
            / nullif(t.total_views, 0), 1)                    as search_pct,
        round(coalesce(t.subscriber_views, 0) * 100.0
            / nullif(t.total_views, 0), 1)                    as subscriber_pct,

        -- sınıflandırma
        case
            when coalesce(t.algorithm_views, 0) * 1.0
                / nullif(t.total_views, 0) > 0.7 then 'algorithm_driven'
            when (coalesce(t.search_views, 0)
                + coalesce(t.external_views, 0)) * 1.0
                / nullif(t.total_views, 0) > 0.3 then 'demand_driven'
            else 'mixed'
        end                                                   as discovery_label,

        -- retention
        r.avg_retention_pct,
        r.avg_duration_sec,
        r.total_subs_gained,
        coalesce(r.ever_looped, false)                        as ever_looped,
        coalesce(r.days_with_data, 0)                         as days_with_data,

        case
            when r.avg_retention_pct > 75 then 'high'
            when r.avg_retention_pct > 50 then 'mid'
            when r.avg_retention_pct is not null then 'low'
            else null
        end                                                   as retention_tier

    from videos v
    left join traffic t  on v.youtube_video_id = t.video_id
    left join retention r on v.youtube_video_id = r.video_id

)

select * from final