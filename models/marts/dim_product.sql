select
    product_code,
    product_name,
    product_family,
    unit_of_measure
from {{ ref('stg_erp__products') }}
