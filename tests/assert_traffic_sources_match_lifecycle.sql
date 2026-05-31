--if the video total views not equal then sum of all traffic sources 

with traffic_totals as (
    select
        video_id,
        sum(views) as total_traffic_views
    from {{ source('minti_raw','raw_yt_traffic_sources') }}
    group by video_id
),
lifecycle_totals as (
    select 
    video_id,
    SUM(daily_views) AS TotalViewsFromLC
    FROM {{ ref('fct_video_lifecycle')}}
    group by video_id
),
ErrorVideo AS(
    SELECT 
        tt.video_id
        FROM traffic_totals tt 
    JOIN lifecycle_totals lt ON tt.video_id=lt.video_id
    WHERE 
        abs(tt.total_traffic_views-lt.TotalViewsFromLC)> 
        nullif(lt.totalviewsfromlc,0) * 0.10
)

SELECT 
    video_id 
    FROM ErrorVideo  