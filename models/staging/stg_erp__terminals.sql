select
    upper(terminal_code) as terminal_code,
    terminal_name,
    island
from {{ ref('raw_terminals') }}
