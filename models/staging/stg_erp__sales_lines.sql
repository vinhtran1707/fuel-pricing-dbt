-- Invoice lines from the ERP extract. Re-extracts occasionally load the same
-- line twice, so keep only the latest load per (invoice_id, line_number).
with ranked as (
    select
        *,
        row_number() over (
            partition by invoice_id, line_number
            order by loaded_at desc
        ) as load_rank
    from {{ ref('raw_sales_lines') }}
)

select
    invoice_id || '-' || cast(line_number as varchar)   as sales_line_id,
    invoice_id,
    line_number,
    cast(invoice_date as date)                          as invoice_date,
    company_code || '|' || account_number               as account_key,
    upper(product_code)                                 as product_code,
    upper(terminal_code)                                as terminal_code,
    cast(gallons as integer)                            as gallons,
    cast(invoice_unit_price as decimal(12, 4))          as invoice_unit_price,
    loaded_at
from ranked
where load_rank = 1
