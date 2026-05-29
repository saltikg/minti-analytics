{{
    config(
        materialized='table',
        on_schema_change='sync_all_columns'
    )
}}

with daily_deltas as (

    select
        d.video_id,
        d.snapshot_date,
        d.brand_id,
        d.views                                                     as daily_views,
        g.planned_publish_at::date                                  as publish_date,
        (d.snapshot_date - g.planned_publish_at::date)::integer     as days_since_publish
    from {{ ref('fct_video_daily_deltas') }} d
    join {{ ref('stg_shorts_generated_videos') }} g
        on d.video_id = g.youtube_video_id
    where d.channel_type = 'youtube'
      and g.youtube_video_id is not null
      and g.publish_status = 'published'
      and g.planned_publish_at is not null

),

with_performance as (

    select
        d.*,
        p.generated_title,
        p.avg_retention_pct,
        p.retention_tier,
        p.discovery_label,
        p.total_views                                               as video_total_views
    from daily_deltas d
    left join {{ ref('fct_video_performance_summary') }} p
        on d.video_id = p.youtube_video_id

)

select
    video_id,
    generated_title,
    snapshot_date,
    publish_date,
    days_since_publish,
    daily_views,
    brand_id,
    avg_retention_pct,
    retention_tier,
    discovery_label,
    video_total_views
from with_performance
where days_since_publish >= 0
