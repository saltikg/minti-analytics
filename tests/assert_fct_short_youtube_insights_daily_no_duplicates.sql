select
    generated_video_id,
    metric_date,
    count(*) as row_count
from {{ ref('fct_short_youtube_insights_daily') }}
group by generated_video_id, metric_date
having count(*) > 1

