select
    date_day                                            as date_key,
    extract(year from date_day)                         as year_number,
    extract(quarter from date_day)                      as quarter_number,
    extract(month from date_day)                        as month_number,
    cast({{ dbt.date_trunc('month', 'date_day') }} as date) as month_start_date,
    extract(dayofweek from date_day)                    as day_of_week,      -- 0 = Sunday
    extract(dayofweek from date_day) in (0, 6)          as is_weekend
from {{ ref('int_date_spine') }}
