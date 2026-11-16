-- Slowly changing dimension (Type 2) for customer price tier, rebuilt from the
-- tier-change audit log so it is fully reproducible on every run.
-- One row per customer per tier version with a half-open validity window
-- [valid_from, valid_to). The current version has valid_to = 9999-12-31.
with onboarding as (
    select
        customer_id,
        max(price_tier)          as price_tier,
        max(segment)             as segment,
        min(account_created_at)  as valid_from,
        'onboarding'             as change_source
    from {{ ref('stg_erp__customer_accounts') }}
    group by customer_id
),

changes as (
    select
        c.customer_id,
        c.new_price_tier         as price_tier,
        o.segment,
        c.changed_at             as valid_from,
        c.change_id              as change_source
    from {{ ref('stg_erp__customer_tier_changes') }} c
    inner join onboarding o on o.customer_id = c.customer_id
),

versions as (
    select * from onboarding
    union all
    select * from changes
)

select
    customer_id || '|' || cast(valid_from as varchar)        as customer_history_key,
    customer_id,
    price_tier,
    segment,
    valid_from,
    coalesce(
        lead(valid_from) over (partition by customer_id order by valid_from),
        cast('9999-12-31' as date)
    )                                                        as valid_to,
    lead(valid_from) over (partition by customer_id order by valid_from) is null as is_current,
    row_number() over (partition by customer_id order by valid_from)            as version_number,
    change_source
from versions
