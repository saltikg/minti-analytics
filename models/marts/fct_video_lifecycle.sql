{{
    config(
        materialized='incremental',
        unique_key=['video_id','snapshot_date'],
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
    from {{  ref('fct_video_daily_deltas') }} d
    join {{ ref('stg_shorts_generated_videos') }} g
        on d.video_id = g.youtube_video_id

    where d.channel_type = 'youtube'
      and g.youtube_video_id is not null
      and g.publish_status = 'published'
      and g.planned_publish_at is not null
    {% if is_incremental() %}
       and d.snapshot_date >= 
        (select max(snapshot_date) - interval '3 days' from {{ this }})
    {% endif %}

)
select
    video_id,
    snapshot_date,
    publish_date,
    days_since_publish,
    daily_views,
    brand_id
from daily_deltas
where days_since_publish >= 0
