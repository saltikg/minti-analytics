with src as (
    select *
    from {{ ref('stg_shorts_generated_videos') }}
),
dedup as (
    select *
    from (
        select
            *,
            row_number() over (
                partition by id
                order by updated_at desc nulls last, created_at desc nulls last
            ) as rn
        from src
    ) t
    where rn = 1
)
select
    id as generated_video_id,

    generated_title,
    generated_description,
    generated_excerpt,
    generated_transcript_full,

    created_at,
    updated_at
from dedup
