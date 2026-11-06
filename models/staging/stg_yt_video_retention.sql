select
    snapshot_date,
    video_id,
    generated_video_id,
    owner_user_id,
    brand_id,
    views,
    average_view_duration_seconds,
    average_view_percentage,
    subscribers_gained,
    fetched_at,
    average_view_percentage > 100 as is_loop_video
from {{ source('minti_raw', 'raw_yt_video_retention') }}
