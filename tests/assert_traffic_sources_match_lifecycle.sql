-- Traffic-source reconciliation should use the traffic-source denominator,
-- not the snapshot-based total_views in fct_video_performance_summary.
-- Only videos that actually have traffic-source rows participate in this test.

with summary as (
    select
        youtube_video_id as video_id,
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
traffic as (
    select
        video_id,
        sum(views) as traffic_total_views
    from {{ ref('stg_yt_traffic_sources') }}
    group by video_id
),
joined as (
    select
        s.video_id,
        t.traffic_total_views,
        s.algorithm_views,
        s.search_views,
        s.external_views,
        s.channel_views,
        s.subscriber_views,
        s.other_views,
        s.algorithm_pct,
        s.search_pct,
        s.subscriber_pct
    from summary s
    join traffic t
      on s.video_id = t.video_id
),
violations as (
    select
        video_id
    from joined
    where
        abs(
            (
                algorithm_views
                + search_views
                + external_views
                + channel_views
                + subscriber_views
                + other_views
            ) - traffic_total_views
        ) > 1
        or coalesce(algorithm_pct, 0) > 100.5
        or coalesce(search_pct, 0) > 100.5
        or coalesce(subscriber_pct, 0) > 100.5
        or coalesce(algorithm_pct, 0) < 0
        or coalesce(search_pct, 0) < 0
        or coalesce(subscriber_pct, 0) < 0
        or (
            traffic_total_views = 0
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
