-- Aynı video, aynı marka, aynı kanal, aynı gün kombinasyonu
-- birden fazla kez görünmemeli.
-- Bu sorgu satır döndürürse test fail olur.

select
    snapshot_date,
    brand_id,
    channel_type,
    video_id,
    count(*) as row_count
from {{ ref('fct_video_daily_deltas') }}
group by snapshot_date,
    brand_id,
    channel_type,
    video_id
having count(*) > 1