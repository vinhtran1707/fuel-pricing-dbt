-- Audit log of price tier changes (one row per change event).
select
    change_id,
    customer_id,
    upper(new_price_tier)       as new_price_tier,
    cast(changed_at as date)    as changed_at,
    change_reason
from {{ ref('raw_customer_tier_changes') }}
