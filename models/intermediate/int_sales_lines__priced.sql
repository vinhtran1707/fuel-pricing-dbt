-- Attach the rack price and the expected contract price to every invoice line.
--
-- Pricing waterfall (most specific agreement wins):
--   1. contract for this customer + product + terminal
--   2. contract for this customer + product (any terminal)
--   3. contract for this customer (all products)
--   4. no contract -> tier default differential over rack
-- Ranking candidate agreements with row_number() keeps exactly one price per
-- line, so the fact table can never fan out when agreements overlap.
with sales as (
    select
        s.*,
        a.customer_id,
        a.price_tier,
        p.product_family
    from {{ ref('stg_erp__sales_lines') }} s
    inner join {{ ref('stg_erp__customer_accounts') }} a on a.account_key = s.account_key
    inner join {{ ref('stg_erp__products') }} p          on p.product_code = s.product_code
),

agreement_matches as (
    select
        s.sales_line_id,
        ag.agreement_id,
        ag.price_type,
        ag.price_value,
        case
            when ag.product_code is not null and ag.terminal_code is not null then 1
            when ag.product_code is not null then 2
            else 3
        end as match_specificity
    from sales s
    inner join {{ ref('stg_erp__price_agreements') }} ag
        on  ag.customer_id = s.customer_id
        and s.invoice_date between ag.effective_from and ag.effective_to
        and (ag.product_code  is null or ag.product_code  = s.product_code)
        and (ag.terminal_code is null or ag.terminal_code = s.terminal_code)
),

best_agreement as (
    select
        *,
        row_number() over (
            partition by sales_line_id
            order by match_specificity, agreement_id
        ) as agreement_rank
    from agreement_matches
)

select
    s.sales_line_id,
    s.invoice_id,
    s.line_number,
    s.invoice_date,
    s.account_key,
    s.customer_id,
    s.price_tier,
    s.product_code,
    s.product_family,
    s.terminal_code,
    s.gallons,
    s.invoice_unit_price,
    r.rack_price,
    r.rack_published_date,
    r.is_carried_forward                    as rack_is_carried_forward,
    b.agreement_id,
    case b.match_specificity
        when 1 then 'contract_product_terminal'
        when 2 then 'contract_product'
        when 3 then 'contract_customer'
        else 'tier_default'
    end                                     as pricing_source,
    cast(
        case
            when b.price_type = 'fixed'     then b.price_value
            when b.price_type = 'rack_plus' then r.rack_price + b.price_value
            else r.rack_price + td.rack_differential
        end as decimal(12, 4)
    )                                       as expected_unit_price
from sales s
left join best_agreement b
    on  b.sales_line_id = s.sales_line_id
    and b.agreement_rank = 1
left join {{ ref('int_rack_prices__daily') }} r
    on  r.date_day      = s.invoice_date
    and r.terminal_code = s.terminal_code
    and r.product_code  = s.product_code
left join {{ ref('stg_erp__tier_differentials') }} td
    on  td.price_tier     = s.price_tier
    and td.product_family = s.product_family
