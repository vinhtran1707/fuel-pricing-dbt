{{ config(materialized='ephemeral') }}
-- The ERP's live customer master: one row per customer showing only the
-- CURRENT price tier. Like most operational systems it overwrites the tier in
-- place, so history is lost unless a snapshot captures it.
--
-- The `profile_as_of_date` var replays what this table looked like on a given
-- day, which lets the snapshot demo (see README) observe real changes:
--   dbt snapshot --vars '{profile_as_of_date: 2026-01-01}'   -- initial state
--   dbt snapshot                                              -- current state
-- It is ephemeral so each `dbt snapshot` compiles it with that run's vars.
with onboarding as (
    select
        customer_id,
        max(price_tier)          as price_tier,
        max(segment)             as segment,
        min(account_created_at)  as onboarded_at
    from {{ ref('stg_erp__customer_accounts') }}
    group by customer_id
),

latest_change as (
    select *
    from (
        select
            customer_id,
            new_price_tier,
            changed_at,
            row_number() over (partition by customer_id order by changed_at desc) as change_rank
        from {{ ref('stg_erp__customer_tier_changes') }}
        where changed_at <= cast('{{ var("profile_as_of_date") }}' as date)
    ) ranked
    where change_rank = 1
)

select
    o.customer_id,
    coalesce(c.new_price_tier, o.price_tier)                    as price_tier,
    o.segment,
    cast(coalesce(c.changed_at, o.onboarded_at) as timestamp)   as updated_at
from onboarding o
left join latest_change c on c.customer_id = o.customer_id
