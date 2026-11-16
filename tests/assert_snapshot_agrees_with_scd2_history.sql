-- The dbt snapshot (captured from the overwrite-in-place ERP table) and the
-- SCD2 history (rebuilt from the audit log) must tell the same story:
--   1. every version the snapshot recorded exists in the history, and
--   2. both agree on each customer's current tier.
with snap as (
    select
        customer_id,
        price_tier,
        cast(dbt_valid_from as date) as valid_from,
        dbt_valid_to is null         as is_current
    from {{ ref('snap_customer_profile') }}
),

hist as (
    select customer_id, price_tier, valid_from, is_current
    from {{ ref('dim_customer_history') }}
)

select s.customer_id, 'snapshot version missing from history' as issue
from snap s
left join hist h
    on  h.customer_id = s.customer_id
    and h.valid_from  = s.valid_from
    and h.price_tier  = s.price_tier
where h.customer_id is null

union all

select s.customer_id, 'current tier disagrees' as issue
from snap s
inner join hist h
    on  h.customer_id = s.customer_id
    and s.is_current and h.is_current
where s.price_tier <> h.price_tier
