-- Customer price agreements. Blank product/terminal means "applies to all".
select
    agreement_id,
    customer_id,
    nullif(trim(product_code), '')                          as product_code,
    nullif(trim(terminal_code), '')                         as terminal_code,
    lower(price_type)                                       as price_type,
    cast(price_value as decimal(12, 4))                     as price_value,
    cast(effective_from as date)                            as effective_from,
    coalesce(cast(effective_to as date), cast('9999-12-31' as date)) as effective_to
from {{ ref('raw_price_agreements') }}
