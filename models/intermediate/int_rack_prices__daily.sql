-- Rack prices are only published on business days, but fuel is sold every day.
-- For each day x terminal x product, carry forward the most recent published
-- price (as-of join). Resolving this once here means every downstream model
-- uses the same rack price for a weekend sale instead of re-deriving it.
with spine as (
    select date_day from {{ ref('int_date_spine') }}
),

rack as (
    select * from {{ ref('stg_erp__rack_prices') }}
),

combos as (
    select distinct terminal_code, product_code from rack
),

candidates as (
    select
        spine.date_day,
        combos.terminal_code,
        combos.product_code,
        rack.price_date,
        rack.rack_price,
        row_number() over (
            partition by spine.date_day, combos.terminal_code, combos.product_code
            order by rack.price_date desc
        ) as recency_rank
    from spine
    cross join combos
    inner join rack
        on  rack.terminal_code = combos.terminal_code
        and rack.product_code  = combos.product_code
        and rack.price_date   <= spine.date_day
        -- bound the as-of search to a week so the join stays cheap at scale
        and rack.price_date   >= cast({{ dbt.dateadd('day', -7, 'spine.date_day') }} as date)
)

select
    cast(date_day as varchar) || '|' || terminal_code || '|' || product_code as rack_price_day_key,
    date_day,
    terminal_code,
    product_code,
    rack_price,
    price_date                     as rack_published_date,
    (price_date <> date_day)       as is_carried_forward
from candidates
where recency_rank = 1
