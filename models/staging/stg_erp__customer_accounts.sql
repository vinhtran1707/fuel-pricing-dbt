-- One row per ERP account (company_code + account_number).
-- The same customer can hold accounts in several operating companies under
-- differently formatted names, so the shared customer_id is the conformed key.
select
    company_code,
    account_number,
    company_code || '|' || account_number          as account_key,
    customer_id,
    account_name                                    as account_name_raw,
    {{ clean_account_name('account_name') }}        as account_name_clean,
    upper(price_tier)                               as price_tier,
    segment,
    cast(created_at as date)                        as account_created_at
from {{ ref('raw_customer_accounts') }}
