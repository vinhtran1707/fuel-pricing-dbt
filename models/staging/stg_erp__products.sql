select
    upper(product_code)  as product_code,
    product_name,
    product_family,
    unit_of_measure
from {{ ref('raw_products') }}
