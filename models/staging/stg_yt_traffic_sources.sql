select
    snapshot_date,
    video_id,
    traffic_source_type,
    views,
    fetched_at,
    case traffic_source_type
        when 'SHORTS'         then 'feed_algorithm'
        when 'NOTIFICATION'   then 'feed_algorithm'
        when 'YT_OTHER_PAGE'  then 'feed_algorithm'
        when 'RELATED_VIDEO'  then 'feed_algorithm'
        when 'YT_SEARCH'      then 'organic_search'
        when 'EXT_URL'        then 'organic_external'
        when 'YT_CHANNEL'     then 'organic_channel'
        when 'SUBSCRIBER'     then 'subscriber'
        else                       'other'
    end as source_category
from {{ source('minti_raw', 'raw_yt_traffic_sources') }}