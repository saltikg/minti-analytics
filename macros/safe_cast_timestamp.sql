{#
  safe_cast_timestamp: target-aware timestamp cast for TEXT/VARCHAR source columns
  Use when source column is stored as text (e.g. social_comment_cache.published_at)
#}
{% macro safe_cast_timestamp(col) -%}
    {%- if target.type == 'snowflake' -%}
        try_to_timestamp_ntz({{ col }})
    {%- else -%}
        {{ col }}::timestamp
    {%- endif -%}
{%- endmacro %}

{#
  cast_timestamp: target-aware cast for real TIMESTAMP source columns
  Use when source column is already timestamp type (safe direct cast)
#}
{% macro cast_timestamp(col) -%}
    {%- if target.type == 'snowflake' -%}
        {{ col }}::timestamp_ntz
    {%- else -%}
        {{ col }}::timestamp
    {%- endif -%}
{%- endmacro %}
