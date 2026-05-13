select
    *
from {{ source('minti_raw', 'shorts_channel_subscriber_daily') }}
