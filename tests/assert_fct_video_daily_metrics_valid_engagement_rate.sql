-- Engagement rate 0 ile 1 arasında olmalı.
-- Negatif veya 1'i geçen değer iş kuralı ihlali.
-- NULL kabul edilebilir (primary_exposure sıfırsa nullif ile null döner).

select
    snapshot_date,
    brand_id,
    channel_type,
    video_id,
    engagement_rate
from {{ ref('fct_video_daily_metrics') }}
where engagement_rate < 0
   or engagement_rate > 1