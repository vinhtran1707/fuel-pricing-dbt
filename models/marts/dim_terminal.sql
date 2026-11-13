select
    terminal_code,
    terminal_name,
    island
from {{ ref('stg_erp__terminals') }}
