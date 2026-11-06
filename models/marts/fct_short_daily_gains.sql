{{ config(
    materialized='table'
) }}

with generated as (

    select
        generated_video_id,
        brand_id,
        source_video_id,
        generated_title,
        youtube_video_id,
        instagram_media_id,
        facebook_video_id,
        youtube_published_at,
        instagram_published_at,
        facebook_published_at,
        published_at,
        (
            select min(platform_published_at)
            from (
                values
                    (youtube_published_at),
                    (instagram_published_at),
                    (facebook_published_at)
            ) successful_publications(platform_published_at)
            where platform_published_at is not null
        ) as canonical_published_at
    from {{ ref('dim_generated_videos') }}
    where brand_id is not null
      and publish_status = 'published'

),

platform_map as (

    select
        generated_video_id,
        brand_id,
        source_video_id,
        generated_title,
        'youtube'::text as platform,
        youtube_video_id as platform_video_id,
        youtube_video_id,
        instagram_media_id,
        facebook_video_id,
        youtube_published_at as platform_published_at,
        canonical_published_at
    from generated
    where youtube_video_id is not null
      and youtube_published_at is not null

    union all

    select
        generated_video_id,
        brand_id,
        source_video_id,
        generated_title,
        'instagram'::text as platform,
        instagram_media_id as platform_video_id,
        youtube_video_id,
        instagram_media_id,
        facebook_video_id,
        instagram_published_at as platform_published_at,
        canonical_published_at
    from generated
    where instagram_media_id is not null
      and instagram_published_at is not null

    union all

    select
        generated_video_id,
        brand_id,
        source_video_id,
        generated_title,
        'facebook'::text as platform,
        facebook_video_id as platform_video_id,
        youtube_video_id,
        instagram_media_id,
        facebook_video_id,
        facebook_published_at as platform_published_at,
        canonical_published_at
    from generated
    where facebook_video_id is not null
      and facebook_published_at is not null

),

raw_snapshots as (

    select
        brand_id,
        channel_type as platform,
        video_id as platform_video_id,
        coalesce(
            (((effective_at at time zone 'UTC') at time zone 'America/Los_Angeles')::date),
            snapshot_date
        ) as metric_date,
        effective_at,
        case
            when channel_type = 'instagram' then coalesce(views, impressions)
            else views
        end as lifetime_views,
        likes as lifetime_likes,
        comments as lifetime_comments,
        stats_source,
        row_number() over (
            partition by
                brand_id,
                channel_type,
                video_id,
                coalesce(
                    (((effective_at at time zone 'UTC') at time zone 'America/Los_Angeles')::date),
                    snapshot_date
                )
            order by effective_at desc nulls last, snapshot_date desc
        ) as rn
    from {{ ref('stg_video_daily_snapshots') }}
    where brand_id is not null
      and channel_type in ('youtube', 'instagram', 'facebook')
      and video_id is not null

),

snapshots as (

    select *
    from raw_snapshots
    where rn = 1

),

collection_bounds as (

    select
        brand_id,
        platform,
        min(metric_date) as collection_start_date,
        max(metric_date) as collection_end_date
    from snapshots
    group by brand_id, platform

),

mapped_snapshots as (

    select
        p.*,
        s.metric_date,
        s.effective_at,
        s.lifetime_views,
        s.lifetime_likes,
        s.lifetime_comments,
        s.stats_source,
        b.collection_start_date,
        b.collection_end_date,
        ((p.platform_published_at at time zone 'UTC') at time zone 'America/Los_Angeles')::date
            as platform_publish_date,
        ((p.canonical_published_at at time zone 'UTC') at time zone 'America/Los_Angeles')::date
            as canonical_publish_date
    from platform_map p
    join snapshots s
      on s.brand_id = p.brand_id
     and s.platform = p.platform
     and s.platform_video_id = p.platform_video_id
    join collection_bounds b
      on b.brand_id = p.brand_id
     and b.platform = p.platform

),

ordered_snapshots as (

    select
        *,
        lag(metric_date) over series_order as previous_metric_date,
        lag(lifetime_views) over series_order as previous_lifetime_views,
        lag(lifetime_likes) over series_order as previous_lifetime_likes,
        lag(lifetime_comments) over series_order as previous_lifetime_comments,
        row_number() over series_order as series_row_number
    from mapped_snapshots
    window series_order as (
        partition by brand_id, generated_video_id, platform
        order by metric_date
    )

),

observed_gains as (

    select
        *,
        case
            when series_row_number = 1 and platform_publish_date >= collection_start_date
                then 'zero_at_publication'
            when previous_metric_date is not null
                then 'previous_snapshot'
            else 'missing'
        end as baseline_kind,
        case
            when lifetime_views is null then null
            when previous_lifetime_views is not null
                then greatest(lifetime_views - previous_lifetime_views, 0)
            when series_row_number = 1 and platform_publish_date >= collection_start_date
                then greatest(lifetime_views, 0)
            else null
        end as views_gain,
        case
            when lifetime_likes is null then null
            when previous_lifetime_likes is not null
                then greatest(lifetime_likes - previous_lifetime_likes, 0)
            when series_row_number = 1 and platform_publish_date >= collection_start_date
                then greatest(lifetime_likes, 0)
            else null
        end as likes_gain,
        case
            when lifetime_comments is null then null
            when previous_lifetime_comments is not null
                then greatest(lifetime_comments - previous_lifetime_comments, 0)
            when series_row_number = 1 and platform_publish_date >= collection_start_date
                then greatest(lifetime_comments, 0)
            else null
        end as comments_gain
    from ordered_snapshots

),

platform_bounds as (

    select
        p.*,
        b.collection_start_date,
        b.collection_end_date,
        ((p.platform_published_at at time zone 'UTC') at time zone 'America/Los_Angeles')::date
            as platform_publish_date,
        ((p.canonical_published_at at time zone 'UTC') at time zone 'America/Los_Angeles')::date
            as canonical_publish_date
    from platform_map p
    join collection_bounds b
      on b.brand_id = p.brand_id
     and b.platform = p.platform
    where ((p.platform_published_at at time zone 'UTC') at time zone 'America/Los_Angeles')::date
        <= b.collection_end_date

),

date_spine as (

    select
        p.*,
        generated_date::date as metric_date
    from platform_bounds p
    cross join lateral generate_series(
        p.platform_publish_date::timestamp,
        p.collection_end_date::timestamp,
        interval '1 day'
    ) generated_date

),

instagram_links as (

    select brand_id, instagram_media_id, permalink
    from (
        select
            brand_id,
            instagram_media_id,
            permalink,
            row_number() over (
                partition by brand_id, instagram_media_id
                order by updated_at desc nulls last, id desc
            ) as rn
        from {{ source('minti_raw', 'shorts_instagram_queue') }}
        where instagram_media_id is not null
    ) links
    where rn = 1

)

select
    d.metric_date,
    d.brand_id,
    d.generated_video_id,
    d.source_video_id,
    d.generated_title,
    d.platform,
    d.platform_video_id,
    d.youtube_video_id,
    d.instagram_media_id,
    d.facebook_video_id,
    i.permalink as instagram_permalink,
    d.canonical_publish_date,
    d.platform_publish_date,
    o.lifetime_views,
    o.lifetime_likes,
    o.lifetime_comments,
    o.views_gain,
    o.likes_gain,
    o.comments_gain,
    o.baseline_kind,
    case
        when o.metric_date is null then 'pending'
        when o.lifetime_views is null
          or o.lifetime_likes is null
          or o.lifetime_comments is null then 'pending'
        when o.views_gain is null
          or o.likes_gain is null
          or o.comments_gain is null then 'partial'
        when o.previous_metric_date is not null
         and o.previous_metric_date <> o.metric_date - 1 then 'partial'
        else 'complete'
    end as completeness_status,
    (o.metric_date is not null) as has_snapshot,
    o.stats_source,
    o.effective_at
from date_spine d
left join observed_gains o
  on o.brand_id = d.brand_id
 and o.generated_video_id = d.generated_video_id
 and o.platform = d.platform
 and o.metric_date = d.metric_date
left join instagram_links i
  on i.brand_id = d.brand_id
 and i.instagram_media_id = d.instagram_media_id
