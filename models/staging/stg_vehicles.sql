-- models/staging/stg_vehicles.sql
-- Flattens JSON VARIANT vehicle payloads from Snowpipe into columnar form.
-- Handles: invalid transport_partner_ids, negative capacities,
--           inconsistent boolean values for availability_flag.

with source as (
    select
        raw_data,
        loaded_at
    from {{ source('raw', 'raw_vehicles') }}
    where raw_data is not null
),

flattened as (
    select
        f.value                                                 as record,
        s.loaded_at
    from source s,
    lateral flatten(input => s.raw_data:records)               f
),

parsed as (
    select
        -- Natural key
        trim(record:vehicle_id::string)                         as vehicle_id,

        -- Foreign key — validate pattern (expect T + digits)
        case
            when regexp_like(trim(record:transport_partner_id::string), '^T[0-9]+$')
                then trim(record:transport_partner_id::string)
            else null
        end                                                     as transport_partner_id,

        -- Vehicle descriptors
        initcap(trim(record:vehicle_type::string))              as vehicle_type,

        -- Capacity: must be positive
        case
            when try_to_number(record:vehicle_capacity_kg::string, 18, 2) > 0
                then try_to_number(record:vehicle_capacity_kg::string, 18, 2)
            else null
        end                                                     as vehicle_capacity_kg,

        -- Status
        upper(trim(record:vehicle_status::string))              as vehicle_status,

        -- Location
        initcap(trim(record:current_location::string))          as current_location,

        -- Boolean availability — normalize all variants
        {{ boolean_normalization('record:availability_flag') }} as is_available,

        -- Batch metadata
        loaded_at                                               as _snowpipe_loaded_at,
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['record:vehicle_id::string']) }}  as vehicle_sk

    from flattened
    where trim(record:vehicle_id::string) is not null
      and trim(record:vehicle_id::string) != ''
),

with_dq_flags as (
    select
        *,
        case when transport_partner_id is null  then true else false end as dq_invalid_partner_id,
        case when vehicle_capacity_kg is null   then true else false end as dq_negative_capacity,
        case when is_available is null          then true else false end as dq_inconsistent_boolean,
        case
            when vehicle_status not in ('AVAILABLE', 'IN_USE', 'MAINTENANCE', 'INACTIVE')
                then true
            else false
        end                                                             as dq_invalid_status
    from parsed
)

select * from with_dq_flags