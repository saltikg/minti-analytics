{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

with retention as (

    select
        snapshot_date as metric_date,
        video_id as youtube_video_id,
        max(generated_video_id) as generated_video_id,
        max(owner_user_id) as owner_user_id,
        max(brand_id) as brand_id,
        max(views) as views,
        max(average_view_percentage) as average_view_percentage,
        max(average_view_duration_seconds) as average_view_duration_seconds,
        max(subscribers_gained) as subscribers_gained,
        max(fetched_at) as fetched_at
    from {{ ref('stg_yt_video_retention') }}
    group by snapshot_date, video_id

),

traffic as (

    select
        snapshot_date as metric_date,
        video_id as youtube_video_id,
        max(generated_video_id) as generated_video_id,
        max(owner_user_id) as owner_user_id,
        max(brand_id) as brand_id,
        sum(views) filter (where traffic_source_type = 'SHORTS') as shorts_feed_views,
        sum(views) filter (where traffic_source_type = 'YT_SEARCH') as search_views,
        sum(views) filter (where traffic_source_type = 'SUBSCRIBER') as subscriber_views,
        sum(views) filter (where traffic_source_type = 'NOTIFICATION') as notification_views,
        sum(views) filter (where traffic_source_type = 'YT_CHANNEL') as channel_page_views,
        sum(views) filter (where traffic_source_type = 'EXT_URL') as external_views,
        sum(views) filter (
            where traffic_source_type not in (
                'SHORTS',
                'YT_SEARCH',
                'SUBSCRIBER',
                'NOTIFICATION',
                'YT_CHANNEL',
                'EXT_URL'
            )
        ) as other_views,
        sum(views) as source_attributed_views,
        max(fetched_at) as fetched_at
    from {{ ref('stg_yt_traffic_sources') }}
    group by snapshot_date, video_id

),

daily as (

    select
        coalesce(r.metric_date, t.metric_date) as metric_date,
        coalesce(r.youtube_video_id, t.youtube_video_id) as youtube_video_id,
        coalesce(r.generated_video_id, t.generated_video_id) as generated_video_id,
        coalesce(r.owner_user_id, t.owner_user_id) as owner_user_id,
        coalesce(r.brand_id, t.brand_id) as brand_id,
        r.views,
        t.shorts_feed_views,
        t.search_views,
        t.subscriber_views,
        t.notification_views,
        t.channel_page_views,
        t.external_views,
        t.other_views,
        t.source_attributed_views,
        r.subscribers_gained,
        r.average_view_percentage,
        r.average_view_duration_seconds,
        greatest(r.fetched_at, t.fetched_at) as effective_at
    from retention r
    full outer join traffic t
      on t.metric_date = r.metric_date
     and t.youtube_video_id = r.youtube_video_id

),

generated as (

    select
        generated_video_id,
        brand_id,
        youtube_video_id,
        generated_title
    from {{ ref('dim_generated_videos') }}
    where youtube_video_id is not null

)

select
    d.metric_date,
    d.generated_video_id,
    d.owner_user_id,
    d.brand_id,
    d.youtube_video_id,
    g.generated_title,
    d.views,
    d.shorts_feed_views,
    d.search_views,
    d.subscriber_views,
    d.notification_views,
    d.channel_page_views,
    d.external_views,
    d.other_views,
    d.source_attributed_views,
    d.subscribers_gained,
    d.average_view_percentage,
    d.average_view_duration_seconds,
    case
        when d.views is null then 'pending'
        when d.source_attributed_views is null then 'partial'
        else 'complete'
    end as completeness_status,
    d.effective_at
from daily d
left join generated g
  on g.generated_video_id = d.generated_video_id
 and g.brand_id = d.brand_id
 and g.youtube_video_id = d.youtube_video_id
where d.generated_video_id is not null
  and d.owner_user_id is not null
  and d.brand_id is not null

