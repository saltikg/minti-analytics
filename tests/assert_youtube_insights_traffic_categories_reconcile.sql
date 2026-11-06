select
    generated_video_id,
    metric_date
from {{ ref('fct_short_youtube_insights_daily') }}
where source_attributed_views is not null
  and source_attributed_views <> (
      coalesce(shorts_feed_views, 0)
      + coalesce(search_views, 0)
      + coalesce(subscriber_views, 0)
      + coalesce(notification_views, 0)
      + coalesce(channel_page_views, 0)
      + coalesce(external_views, 0)
      + coalesce(other_views, 0)
  )

