{{ config(
    materialized='table'
) }}

with base as (

    select
        snapshot_date,
        brand_id,
        channel_type,
        video_id,
        views,
        likes,
        comments,
        shares,
        reach,
        saved,

        row_number() over (
            partition by brand_id, channel_type, video_id
            order by snapshot_date
        ) as rn,

        lag(views) over (
            partition by brand_id, channel_type, video_id
            order by snapshot_date
        ) as prev_views,

        lag(likes) over (
            partition by brand_id, channel_type, video_id
            order by snapshot_date
        ) as prev_likes,

        lag(comments) over (
            partition by brand_id, channel_type, video_id
            order by snapshot_date
        ) as prev_comments,

        lag(shares) over (
            partition by brand_id, channel_type, video_id
            order by snapshot_date
        ) as prev_shares,

        lag(reach) over (
            partition by brand_id, channel_type, video_id
            order by snapshot_date
        ) as prev_reach,

        lag(saved) over (
            partition by brand_id, channel_type, video_id
            order by snapshot_date
        ) as prev_saved

    from {{ ref('fct_video_daily_metrics') }}

),

final as (

    select
        snapshot_date,
        brand_id,
        channel_type,
        video_id,

        case
            when rn = 1 then views
            else views - prev_views
        end as views,

        case
            when rn = 1 then likes
            else likes - prev_likes
        end as likes,

        case
            when rn = 1 then comments
            else comments - prev_comments
        end as comments,

        case
            when rn = 1 then shares
            else shares - prev_shares
        end as shares,

        case
            when rn = 1 then reach
            else reach - prev_reach
        end as reach,

        case
            when rn = 1 then saved
            else saved - prev_saved
        end as saved

    from base

)

select *
from final
