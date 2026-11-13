-- margin over rack = (expected price - rack) + billing variance, per line.
select sales_line_id
from {{ ref('fct_sales_margin') }}
where abs(margin_per_gallon - ((expected_unit_price - rack_price) + price_variance_per_gallon)) > 0.0001
