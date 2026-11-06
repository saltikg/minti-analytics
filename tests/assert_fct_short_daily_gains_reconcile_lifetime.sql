with views_observations as (

    select
        brand_id,
        generated_video_id,
        platform,
        metric_date,
        lifetime_views as lifetime_value,
        lag(lifetime_views) over series_order as previous_lifetime_value,
        sum(views_gain) over series_order as cumulative_gain
    from {{ ref('fct_short_daily_gains') }}
    where lifetime_views is not null
    window series_order as (
        partition by brand_id, generated_video_id, platform
        order by metric_date
        rows between unbounded preceding and current row
    )

),

likes_observations as (

    select
        brand_id,
        generated_video_id,
        platform,
        metric_date,
        lifetime_likes as lifetime_value,
        lag(lifetime_likes) over series_order as previous_lifetime_value,
        sum(likes_gain) over series_order as cumulative_gain
    from {{ ref('fct_short_daily_gains') }}
    where lifetime_likes is not null
    window series_order as (
        partition by brand_id, generated_video_id, platform
        order by metric_date
        rows between unbounded preceding and current row
    )

),

comments_observations as (

    select
        brand_id,
        generated_video_id,
        platform,
        metric_date,
        lifetime_comments as lifetime_value,
        lag(lifetime_comments) over series_order as previous_lifetime_value,
        sum(comments_gain) over series_order as cumulative_gain
    from {{ ref('fct_short_daily_gains') }}
    where lifetime_comments is not null
    window series_order as (
        partition by brand_id, generated_video_id, platform
        order by metric_date
        rows between unbounded preceding and current row
    )

),

observations as (

    select 'views' as metric, * from views_observations
    union all
    select 'likes' as metric, * from likes_observations
    union all
    select 'comments' as metric, * from comments_observations

),

with_corrections as (

    -- Platform counters can be corrected downward. Those ranges retain the mart's
    -- non-negative gain semantics and are covered by the nonnegative test instead.
    select
        *,
        count(*) filter (
            where previous_lifetime_value is not null
              and lifetime_value < previous_lifetime_value
        ) over (
            partition by brand_id, generated_video_id, platform, metric
            order by metric_date
            rows between unbounded preceding and current row
        ) as correction_count
    from observations

)

select *
from with_corrections
where correction_count = 0
  and cumulative_gain is distinct from lifetime_value
