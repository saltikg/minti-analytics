
with comments_src as (
    select
        platform,
        comment_id,
        parent_id,
        thread_id,
        video_id as comment_video_id,
        instagram_media_id as comment_instagram_media_id,
        queue_id,
        owner_user_id,
        video_title as source_video_title,
        author as commenter_name,
        text as comment_text,
        status as comment_status,
        comment_url,
        -- published_at: dirty TEXT in source -> safe_cast_timestamp
        {{ safe_cast_timestamp('published_at') }} as comment_published_at,
        like_count,
        moderation_flagged,
        moderation_reason,
        -- moderation_checked_at: clean TIMESTAMP_NTZ -> cast_timestamp
        {{ cast_timestamp('moderation_checked_at') }} as moderation_checked_at,
        -- updated_at: clean TIMESTAMP_NTZ -> cast_timestamp
        {{ cast_timestamp('updated_at') }} as comment_updated_at
    from {{ ref('stg_social_comment_cache') }}
),

comments_dedup as (
    select *
    from (
        select
            *,
            row_number() over (
                partition by platform, comment_id
                order by comment_updated_at desc nulls last, comment_published_at desc nulls last
            ) as rn
        from comments_src
    ) t
    where rn = 1
),

videos as (
    select *
    from (
        select
            id as generated_video_id,
            brand_id,
            source_video_id,
            youtube_video_id,
            instagram_media_id,
            facebook_video_id,
            publish_status,
            {{ cast_timestamp('planned_publish_at') }} as planned_publish_at,
            {{ cast_timestamp('published_at') }} as published_at,
            generated_title,
            {{ cast_timestamp('created_at') }} as video_created_at,
            {{ cast_timestamp('updated_at') }} as video_updated_at,
            row_number() over (
                partition by id
                order by updated_at desc nulls last, created_at desc nulls last
            ) as rn
        from {{ ref('stg_shorts_generated_videos') }}
    ) v
    where rn = 1
),

-- Cross-join comments with videos and rank candidate matches by priority
candidate_matches as (
    select
        c.*,
        v.generated_video_id,
        v.brand_id,
        v.source_video_id,
        v.youtube_video_id,
        v.instagram_media_id,
        v.facebook_video_id,
        v.publish_status,
        v.planned_publish_at,
        v.published_at as video_published_at,
        v.generated_title,
        v.video_updated_at,
        case
            when c.platform = 'instagram'
                 and c.comment_instagram_media_id is not null
                 and v.instagram_media_id = c.comment_instagram_media_id then 1
            when c.platform = 'youtube'
                 and v.youtube_video_id = c.comment_video_id then 1
            when c.platform = 'facebook'
                 and v.facebook_video_id = c.comment_video_id then 1
            else 2
        end as match_priority,
        row_number() over (
            partition by c.platform, c.comment_id
            order by
                case
                    when c.platform = 'instagram'
                         and c.comment_instagram_media_id is not null
                         and v.instagram_media_id = c.comment_instagram_media_id then 1
                    when c.platform = 'youtube'
                         and v.youtube_video_id = c.comment_video_id then 1
                    when c.platform = 'facebook'
                         and v.facebook_video_id = c.comment_video_id then 1
                    else 2
                end,
                v.video_updated_at desc nulls last
        ) as match_rank
    from comments_dedup c
    left join videos v
        on (
            (c.platform = 'youtube' and v.youtube_video_id = c.comment_video_id)
            or (
                c.platform = 'instagram'
                and (
                    (c.comment_instagram_media_id is not null and v.instagram_media_id = c.comment_instagram_media_id)
                    or v.source_video_id = c.comment_video_id
                )
            )
            or (
                c.platform = 'facebook'
                and (
                    (v.facebook_video_id is not null and v.facebook_video_id = c.comment_video_id)
                    or v.source_video_id = c.comment_video_id
                )
            )
        )
),

-- Keep only the best-priority video match per comment
mapped as (
    select *
    from candidate_matches
    where match_rank = 1
)

select
    md5(coalesce(platform, '') || '|' || coalesce(comment_id, '')) as comment_sk,

    platform,
    comment_id,
    parent_id,
    thread_id,
    (parent_id is not null) as is_reply,

    owner_user_id,
    commenter_name,
    comment_text,
    comment_status,
    moderation_flagged,
    moderation_reason,

    like_count,
    comment_url,
    comment_published_at,
    comment_updated_at,
    moderation_checked_at,

    comment_video_id,
    comment_instagram_media_id,
    queue_id,
    source_video_title,

    generated_video_id,
    brand_id,
    source_video_id,
    youtube_video_id,
    instagram_media_id,
    facebook_video_id,
    publish_status,
    planned_publish_at,
    video_published_at,
    generated_title
from mapped
