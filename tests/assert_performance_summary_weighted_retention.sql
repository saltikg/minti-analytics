with expected as (

    select
        video_id,
        round(
            (
                sum(average_view_percentage * views) filter (
                    where views > 5 and average_view_percentage is not null
                )
                / nullif(sum(views) filter (
                    where views > 5 and average_view_percentage is not null
                ), 0)
            )::numeric,
            1
        ) as avg_retention_pct,
        round(
            (
                sum(average_view_duration_seconds * views) filter (
                    where views > 5 and average_view_duration_seconds is not null
                )
                / nullif(sum(views) filter (
                    where views > 5 and average_view_duration_seconds is not null
                ), 0)
            )::numeric,
            1
        ) as avg_duration_sec
    from {{ ref('stg_yt_video_retention') }}
    group by video_id

)

select summary.youtube_video_id
from {{ ref('fct_video_performance_summary') }} summary
join expected
  on expected.video_id = summary.youtube_video_id
where summary.avg_retention_pct is distinct from expected.avg_retention_pct
   or summary.avg_duration_sec is distinct from expected.avg_duration_sec

