-- models/staging/stg_shipment_tracking.sql
-- Flattens high-volume JSON VARIANT tracking events from Snowpipe.
-- Handles: invalid lat/lon ranges, malformed timestamps.
-- This model is the source for the incremental fct_shipment_tracking fact table.

with source as (
    select
        raw_data,
        loaded_at
    from {{ source('raw', 'raw_shipment_tracking') }}
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
        trim(record:tracking_id::string)                        as tracking_id,

        -- Foreign keys
        trim(record:shipment_id::string)                        as shipment_id,
        trim(record:vehicle_id::string)                         as vehicle_id,

        -- Coordinates: valid lat -90 to 90, valid lon -180 to 180
        case
            when try_to_number(record:latitude::string, 9, 6) between -90.0 and 90.0
                then try_to_number(record:latitude::string, 9, 6)
            else null
        end                                                     as latitude,

        case
            when try_to_number(record:longitude::string, 10, 6) between -180.0 and 180.0
                then try_to_number(record:longitude::string, 10, 6)
            else null
        end                                                     as longitude,

        -- Timestamp
        {{ safe_to_timestamp("record:tracking_time::string") }} as tracking_timestamp,
        date({{ safe_to_timestamp("record:tracking_time::string") }}) as tracking_date,

        -- Status
        upper(trim(record:shipment_status::string))             as shipment_status,

        -- Batch metadata
        loaded_at                                               as _snowpipe_loaded_at,
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['record:tracking_id::string']) }} as tracking_sk

    from flattened
    where trim(record:tracking_id::string) is not null
      and trim(record:tracking_id::string) != ''
),

with_dq_flags as (
    select
        *,
        case when latitude is null           then true else false end  as dq_invalid_latitude,
        case when longitude is null          then true else false end  as dq_invalid_longitude,
        case when tracking_timestamp is null then true else false end  as dq_malformed_timestamp
    from parsed
)

select * from with_dq_flags