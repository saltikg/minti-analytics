{{ config(
    materialized = 'view',
    tags = ['staging', 'comments']
) }}

with src as (

    select
        platform,
        comment_id,
        parent_id,
        thread_id,
        video_id,
        instagram_media_id,
        queue_id,
        owner_user_id,
        video_title,
        author,
        text,
        status,
        comment_url,
        published_at,
        like_count,
        moderation_flagged,
        moderation_reason,
        moderation_checked_at,
        created_at,
        updated_at
    from main.social_comment_cache

),

cleaned as (

    select
        lower(trim(platform)) as platform,
        trim(comment_id) as comment_id,
        nullif(trim(parent_id), '') as parent_id,
        nullif(trim(thread_id), '') as thread_id,
        nullif(trim(video_id), '') as video_id,
        nullif(trim(instagram_media_id), '') as instagram_media_id,
        nullif(trim(queue_id), '') as queue_id,
        nullif(trim(owner_user_id), '') as owner_user_id,
        nullif(trim(video_title), '') as video_title,
        nullif(trim(author), '') as author,
        nullif(trim(text), '') as comment_text,

        case
            when lower(trim(status)) in ('heldforreview', 'likelyspam', 'pending') then 'pending'
            when lower(trim(status)) in ('published', 'approved') then 'published'
            when lower(trim(status)) in ('rejected', 'hidden', 'deleted') then 'rejected'
            else lower(trim(status))
        end as comment_status,

        nullif(trim(comment_url), '') as comment_url,

        try_cast(published_at as timestamp) as published_at,
        try_cast(like_count as bigint) as like_count,
        try_cast(moderation_flagged as boolean) as moderation_flagged,
        nullif(trim(moderation_reason), '') as moderation_reason,
        try_cast(moderation_checked_at as timestamp) as moderation_checked_at,
        try_cast(created_at as timestamp) as created_at,
        try_cast(updated_at as timestamp) as updated_at

    from src
    where nullif(trim(comment_id), '') is not null

),

deduped as (

    select *
    from (
        select
            *,
            row_number() over (
                partition by platform, comment_id
                order by updated_at desc nulls last, created_at desc nulls last
            ) as rn
        from cleaned
    ) t
    where rn = 1

)

select
    platform,
    comment_id,
    parent_id,
    thread_id,
    video_id,
    instagram_media_id,
    queue_id,
    owner_user_id,
    video_title,
    author,
    comment_text,
    comment_status,
    comment_url,
    published_at,
    like_count,
    moderation_flagged,
    moderation_reason,
    moderation_checked_at,
    created_at,
    updated_at
from deduped
