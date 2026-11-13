-- Default cents-over-rack by price tier and product family, used when a
-- customer has no agreement that matches a sale.
select
    upper(price_tier)                           as price_tier,
    product_family,
    cast(rack_differential as decimal(12, 4))   as rack_differential
from {{ ref('raw_tier_differentials') }}
