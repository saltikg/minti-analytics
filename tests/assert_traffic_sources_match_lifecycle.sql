-- Source-share must be computed from a same-source denominator.
-- This test enforces that the traffic-source components in
-- fct_video_performance_summary add back up to total_views and that
-- the exposed share columns stay within sane percentage bounds.

with summary as (
    select
        youtube_video_id as video_id,
        coalesce(total_views, 0) as total_views,
        coalesce(algorithm_views, 0) as algorithm_views,
        coalesce(search_views, 0) as search_views,
        coalesce(external_views, 0) as external_views,
        coalesce(channel_views, 0) as channel_views,
        coalesce(subscriber_views, 0) as subscriber_views,
        coalesce(other_views, 0) as other_views,
        algorithm_pct,
        search_pct,
        subscriber_pct
    from {{ ref('fct_video_performance_summary') }}
),
violations as (
    select
        video_id
    from summary
    where
        abs(
            (
                algorithm_views
                + search_views
                + external_views
                + channel_views
                + subscriber_views
                + other_views
            ) - total_views
        ) > 1
        or coalesce(algorithm_pct, 0) > 100.5
        or coalesce(search_pct, 0) > 100.5
        or coalesce(subscriber_pct, 0) > 100.5
        or coalesce(algorithm_pct, 0) < 0
        or coalesce(search_pct, 0) < 0
        or coalesce(subscriber_pct, 0) < 0
        or (
            total_views = 0
            and (
                algorithm_views
                + search_views
                + external_views
                + channel_views
                + subscriber_views
                + other_views
            ) > 0
        )
)

select video_id
from violations
