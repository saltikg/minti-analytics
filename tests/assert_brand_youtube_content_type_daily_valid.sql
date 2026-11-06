with invalid_rows as (
    select brand_id, metric_date
    from {{ ref('fct_brand_youtube_content_type_daily') }}
    group by brand_id, metric_date
    having count(*) <> 1
       or min(shorts_views) < 0
       or min(vod_views) < 0
       or min(live_views) < 0
)

select * from invalid_rows

