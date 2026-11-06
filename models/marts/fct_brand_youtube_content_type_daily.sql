{{ config(
    materialized='table',
    on_schema_change='sync_all_columns'
) }}

with ranked as (

    select
        brand_id,
        owner_user_id,
        channel_id,
        metric_date,
        upper(creator_content_type) as creator_content_type,
        views,
        fetched_at,
        row_number() over (
            partition by brand_id, metric_date, upper(creator_content_type)
            order by fetched_at desc, channel_id desc
        ) as current_connection_rank
    from {{ source('minti_raw', 'raw_yt_channel_content_type_daily') }}

),

current_connection as (

    select *
    from ranked
    where current_connection_rank = 1

)

select
    brand_id,
    max(owner_user_id) as owner_user_id,
    max(channel_id) as channel_id,
    metric_date,
    coalesce(sum(views) filter (where creator_content_type = 'SHORTS'), 0) as shorts_views,
    coalesce(sum(views) filter (where creator_content_type = 'VIDEO_ON_DEMAND'), 0) as vod_views,
    coalesce(sum(views) filter (where creator_content_type = 'LIVE_STREAM'), 0) as live_views,
    max(fetched_at) as effective_at
from current_connection
group by brand_id, metric_date

