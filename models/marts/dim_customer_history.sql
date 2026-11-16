-- SCD Type 2 customer dimension. Join facts on customer_history_key to report
-- each sale with the price tier that was in effect on the sale date.
select * from {{ ref('int_customer_tier_history') }}
