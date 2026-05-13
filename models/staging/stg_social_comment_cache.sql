select
    *
from {{ source('minti_raw', 'social_comment_cache') }}
