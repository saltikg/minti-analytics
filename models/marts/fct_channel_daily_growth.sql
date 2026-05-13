{{ config(materialized='table') }}

with base as (
    select
        snapshot_date::date as snapshot_date,
        effective_at,
        channel_type,
        channel_id,
        channel_name,
        brand_id,
        stats_source,
        coalesce(subscriber_count_exact, subscriber_count, subscriber_count_api_rounded) as subscriber_count,
        subscribers_gained,
        subscribers_lost,
        subscribers_net
    from {{ source('minti_raw', 'shorts_channel_subscriber_daily') }}
),
final as (

    select
        snapshot_date,
        channel_type,
        channel_id,
        channel_name,
        brand_id,
        stats_source,
        subscriber_count,
        subscribers_gained,
        subscribers_lost,
        subscribers_net,
        lag(subscriber_count) over (
            partition by channel_type, channel_id
            order by snapshot_date
        ) as prev_subscriber_count,
        coalesce(
            subscribers_net,
            subscriber_count - lag(subscriber_count) over (
                partition by channel_type, channel_id
                order by snapshot_date
            )
        ) as daily_subscriber_delta
    from base

)

select *
from final
order by snapshot_date desc, channel_type, channel_name
