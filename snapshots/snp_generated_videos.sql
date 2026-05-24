{% snapshot snp_generated_videos %}

{{
    config
    (
        target_schema= 'analytics' if target.type == 'postgres' else 'SNAPSHOTS',
        unique_key='id',
        strategy='timestamp',
        updated_at='updated_at',
    )
}}

select
    id,
    brand_id,
    source_video_id,
    source_channel_type,
    generation_status,
    publish_status,
    planned_publish_at,
    published_at,
    youtube_published_at,
    instagram_published_at,
    facebook_published_at,
    tiktok_published_at,
    primary_publish_platform,
    generated_title,
    created_at,
    updated_at
from {{ source('minti_raw', 'shorts_generated_videos') }}


{% endsnapshot %}