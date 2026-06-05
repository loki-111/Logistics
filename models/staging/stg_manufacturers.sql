-- models/staging/stg_manufacturers.sql
-- Cleans and casts raw manufacturer data from the CRM source.
-- Handles: invalid emails, invalid pincodes, null phones, whitespace.

with source as (
    select * from {{ source('raw', 'raw_manufacturers') }}
),

cleaned as (
    select
        -- Primary key
        trim(manufacturer_id)                                   as manufacturer_id,

        -- Name fields
        initcap(trim(manufacturer_name))                        as manufacturer_name,
        initcap(trim(contact_person))                           as contact_person,

        -- Contact — cleaned via macros
        {{ clean_email('email') }}                              as email,
        {{ clean_phone('phone') }}                              as phone,

        -- Location
        initcap(trim(city))                                     as city,
        upper(trim(state))                                      as state,
        upper(trim(country))                                    as country,

        -- Pincode: valid Indian pincode = exactly 6 digits
        case
            when regexp_like(trim(pincode), '^[1-9][0-9]{5}$')
                then trim(pincode)
            else pincode
        end                                                     as pincode,

        -- Category
        upper(trim(manufacturer_type))                          as manufacturer_type,

        -- Dates
        {{ safe_to_date('created_date') }}                      as created_date,

        -- Metadata
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['manufacturer_id']) }}       as manufacturer_sk

    from source
    where trim(manufacturer_id) is not null
      and trim(manufacturer_id) != ''
),

-- Flag records with data quality issues (do not drop them — keep for auditability)
with_dq_flags as (
    select
        *,
        case when email is null then true else false end        as dq_invalid_email,
        case when pincode is null then true else false end      as dq_invalid_pincode,
        case when phone is null then true else false end        as dq_null_phone
    from cleaned
)

select * from with_dq_flags