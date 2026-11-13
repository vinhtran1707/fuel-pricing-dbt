{#- Normalize ERP account names: trim, collapse repeated spaces, drop legal
    suffixes (LLC, Inc, Co., Ltd) and upper-case. regexp_replace takes different
    arguments on each warehouse, so this macro dispatches per adapter. -#}
{% macro clean_account_name(column) -%}
    {{ return(adapter.dispatch('clean_account_name')(column)) }}
{%- endmacro %}

{% macro default__clean_account_name(column) -%}
    upper(trim(regexp_replace(
        regexp_replace(trim({{ column }}), '\s+', ' ', 'g'),
        '\s+(llc|inc\.?|co\.?|ltd\.?)$', '', 'gi'
    )))
{%- endmacro %}

{% macro snowflake__clean_account_name(column) -%}
    upper(trim(regexp_replace(
        regexp_replace(trim({{ column }}), '\\s+', ' '),
        '\\s+(llc|inc\\.?|co\\.?|ltd\\.?)$', '', 1, 0, 'i'
    )))
{%- endmacro %}
