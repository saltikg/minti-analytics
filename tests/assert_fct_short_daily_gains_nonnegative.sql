select *
from {{ ref('fct_short_daily_gains') }}
where views_gain < 0
   or likes_gain < 0
   or comments_gain < 0
