-- One row per calendar day across the full span of rack prices and sales.
-- Recursive CTE + dbt.dateadd keeps this portable between DuckDB and Snowflake.
with recursive bounds as (
    select
        min(d) as start_date,
        max(d) as end_date
    from (
        select price_date as d from {{ ref('stg_erp__rack_prices') }}
        union all
        select invoice_date as d from {{ ref('stg_erp__sales_lines') }}
    ) all_dates
),

spine (date_day) as (
    select start_date from bounds
    union all
    select cast({{ dbt.dateadd('day', 1, 'date_day') }} as date)
    from spine
    where date_day < (select end_date from bounds)
)

select date_day from spine
