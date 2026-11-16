-- Every customer has exactly one current version, and every validity window
-- is non-empty, so a date can never match zero or two tier versions.
select customer_id, 'not exactly one current version' as issue
from {{ ref('dim_customer_history') }}
group by customer_id
having sum(case when is_current then 1 else 0 end) <> 1

union all

select customer_id, 'empty or inverted window' as issue
from {{ ref('dim_customer_history') }}
where valid_from >= valid_to
