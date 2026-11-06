select
    brand_id,
    generated_video_id,
    platform,
    metric_date,
    count(*) as row_count
from {{ ref('fct_short_daily_gains') }}
group by 1, 2, 3, 4
having count(*) > 1
