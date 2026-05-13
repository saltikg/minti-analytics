{{ config(materialized='table') }}

with source_data as (

    select
        snapshot_date,
        brand_id,
        channel_type,
        video_id,
        impressions,
        views,
        comments,
        likes,
        shares,
        reach,
        saved,
        stats_source
    from {{ ref('stg_video_daily_snapshots') }}

),

enriched as (

    select
        snapshot_date,
        brand_id,
        channel_type,
        video_id,
        impressions,
        views,
        comments,
        likes,
        shares,
        reach,
        saved,
        stats_source,
        case
            when channel_type = 'instagram' then reach
            when channel_type = 'youtube' then views
            else views
        end as primary_exposure,
        likes + comments + shares + saved as engagement_count
    from source_data

)

select
    snapshot_date,
    brand_id,
    channel_type,
    video_id,
    impressions,
    views,
    comments,
    likes,
    shares,
    reach,
    saved,
    stats_source,
    primary_exposure,
    engagement_count,
    engagement_count::numeric / nullif(primary_exposure, 0) as engagement_rate
from enriched
