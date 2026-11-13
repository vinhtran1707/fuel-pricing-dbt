-- Reporting rollup behind the "margin by island" view: monthly gallons,
-- revenue, margin and billing exceptions by island and product family.
with rollup as (
select
    d.month_start_date,
    t.island,
    p.product_family,
    sum(f.gallons)                                              as gallons,
    sum(f.revenue_amount)                                       as revenue_amount,
    sum(f.margin_amount)                                        as margin_amount,
    cast(sum(f.margin_amount) / nullif(sum(f.gallons), 0) as decimal(12, 4)) as margin_per_gallon,
    sum(case when f.is_price_exception then 1 else 0 end)       as price_exception_lines,
    sum(f.price_variance_amount)                                as price_variance_amount
from {{ ref('fct_sales_margin') }} f
inner join {{ ref('dim_date') }} d     on d.date_key = f.date_key
inner join {{ ref('dim_terminal') }} t on t.terminal_code = f.terminal_code
inner join {{ ref('dim_product') }} p  on p.product_code = f.product_code
group by 1, 2, 3
)

select
    cast(month_start_date as varchar) || '|' || island || '|' || product_family as island_month_key,
    *
from rollup
