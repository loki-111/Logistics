-- models/staging/stg_retailers.sql
-- Cleans and casts raw retailer data.
-- Handles: null phones, whitespace, type standardization.

with source as (
    select * from {{ source('raw', 'raw_retailers') }}
),

cleaned as (
    select
        -- Keys
        trim(retailer_id)                                       as retailer_id,

        -- Name fields
        initcap(trim(retailer_name))                            as retailer_name,
        upper(trim(retailer_type))                              as retailer_type,

        -- Location
        initcap(trim(city))                                     as city,
        upper(trim(state))                                      as state,
        upper(trim(country))                                    as country,

        -- Contact
        initcap(trim(contact_person))                           as contact_person,
        {{ clean_phone('phone') }}                              as phone,

        -- Date
        {{ safe_to_date('created_date') }}                      as created_date,

        -- Metadata
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['retailer_id']) }}           as retailer_sk

    from source
    where trim(retailer_id) is not null
      and trim(retailer_id) != ''
),

with_dq_flags as (
    select
        *,
        case when phone is null then true else false end        as dq_null_phone
    from cleaned
)

select * from with_dq_flags