-- Conformed customer dimension: one row per customer across all operating
-- companies. The display name comes from the customer's oldest account so it
-- stays stable when new accounts are opened under different spellings.
with accounts as (
    select * from {{ ref('stg_erp__customer_accounts') }}
),

named as (
    select
        customer_id,
        account_name_clean,
        row_number() over (
            partition by customer_id
            order by account_created_at, account_key
        ) as account_age_rank
    from accounts
),

rollup as (
    select
        customer_id,
        max(price_tier)                     as price_tier,
        max(segment)                        as segment,
        count(*)                            as account_count,
        min(account_created_at)             as first_account_created_at,
        {{ dbt.listagg('company_code', "', '", "order by company_code") }} as company_codes
    from accounts
    group by customer_id
)

select
    r.customer_id,
    n.account_name_clean                    as customer_name,
    r.price_tier,
    r.segment,
    r.account_count,
    r.company_codes,
    r.first_account_created_at
from rollup r
inner join named n
    on  n.customer_id = r.customer_id
    and n.account_age_rank = 1
