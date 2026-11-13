-- Published rack prices. Only exist on business days; gaps are filled
-- downstream in int_rack_prices__daily.
select
    cast(price_date as date)              as price_date,
    upper(terminal_code)                  as terminal_code,
    upper(product_code)                   as product_code,
    cast(rack_price as decimal(12, 4))    as rack_price
from {{ ref('raw_rack_prices') }}
