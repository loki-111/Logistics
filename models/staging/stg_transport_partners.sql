-- models/staging/stg_transport_partners.sql
-- Cleans and casts transport partner data.
-- Handles: invalid ratings, boolean normalization, phone cleaning.

with source as (
    select * from {{ source('raw', 'raw_transport_partners') }}
),

cleaned as (
    select
        -- Keys
        trim(transport_partner_id)                              as transport_partner_id,

        -- Company
        initcap(trim(company_name))                             as company_name,

        -- Enums — standardize
        upper(trim(transport_mode))                             as transport_mode,
        trim(service_area)                                      as service_area,

        -- Rating: valid range 1.0 – 5.0
        case
            when try_to_number(trim(rating), 3, 1) between 1.0 and 5.0
                then try_to_number(trim(rating), 3, 1)
            else null
        end                                                     as rating,

        -- Contact
        initcap(trim(contact_person))                           as contact_person,
        {{ clean_phone('phone') }}                              as phone,

        -- Boolean
        {{ boolean_normalization('active_flag') }}              as is_active,

        -- Metadata
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['transport_partner_id']) }}  as transport_partner_sk

    from source
    where trim(transport_partner_id) is not null
      and trim(transport_partner_id) != ''
),

with_dq_flags as (
    select
        *,
        case when rating is null then true else false end       as dq_invalid_rating
    from cleaned
)

select * from with_dq_flags