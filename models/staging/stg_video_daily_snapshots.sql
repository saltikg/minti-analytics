select
    *
from {{ source('minti_raw', 'shorts_video_daily_snapshots') }}
