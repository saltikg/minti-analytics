with src as (
    select *
    from {{ ref('stg_shorts_generated_videos') }}
),
dedup as (
    select *
    from (
        select
            *,
            row_number() over (
                partition by id
                order by updated_at desc nulls last, created_at desc nulls last
            ) as rn
        from src
    ) t
    where rn = 1
)
select
    id as generated_video_id,
    brand_id,
    source_video_id,

    publish_status,
    primary_publish_platform,

    youtube_video_id,
    instagram_media_id,
    facebook_video_id,
    tiktok_video_id,

    planned_publish_at,
    published_at,
    youtube_published_at,
    instagram_published_at,
    facebook_published_at,
    tiktok_published_at,

    generated_title,

    created_at,
    updated_at
from dedup
