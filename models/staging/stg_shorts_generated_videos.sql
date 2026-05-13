select
    *
from {{ source('minti_raw', 'shorts_generated_videos') }}
