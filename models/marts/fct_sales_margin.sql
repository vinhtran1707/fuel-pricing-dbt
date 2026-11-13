-- Grain: one row per invoice line.
-- Margin is measured against the rack price for the sale date (carried forward
-- on non-publish days). Price variance compares what was billed with what the
-- customer's agreement says they should pay, which flags billing exceptions.
with priced as (
    select * from {{ ref('int_sales_lines__priced') }}
)

select
    sales_line_id,
    invoice_id,
    line_number,
    invoice_date                                                    as date_key,
    customer_id,
    account_key,
    split_part(account_key, '|', 1)                                 as company_code,
    product_code,
    terminal_code,
    pricing_source,
    agreement_id,
    rack_is_carried_forward,

    gallons,
    invoice_unit_price,
    rack_price,
    expected_unit_price,

    cast(invoice_unit_price - rack_price as decimal(12, 4))                     as margin_per_gallon,
    cast(invoice_unit_price - expected_unit_price as decimal(12, 4))            as price_variance_per_gallon,
    cast(gallons * invoice_unit_price as decimal(18, 2))                        as revenue_amount,
    cast(gallons * (invoice_unit_price - rack_price) as decimal(18, 2))         as margin_amount,
    cast(gallons * (invoice_unit_price - expected_unit_price) as decimal(18, 2)) as price_variance_amount,
    abs(invoice_unit_price - expected_unit_price) >= 0.0001                     as is_price_exception
from priced
