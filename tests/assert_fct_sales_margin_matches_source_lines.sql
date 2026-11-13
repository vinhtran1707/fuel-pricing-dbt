-- The fact table must have exactly one row per deduplicated invoice line.
-- Any difference means a join fanned out or dropped rows.
select
    (select count(*) from {{ ref('fct_sales_margin') }})     as fact_rows,
    (select count(*) from {{ ref('stg_erp__sales_lines') }}) as source_rows
where (select count(*) from {{ ref('fct_sales_margin') }})
   <> (select count(*) from {{ ref('stg_erp__sales_lines') }})
