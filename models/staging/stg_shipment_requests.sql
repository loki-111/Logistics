-- models/staging/stg_shipment_requests.sql
-- Flattens JSON VARIANT payloads from Snowpipe into a clean columnar model.
-- Each raw row contains a batch with a "records" array — we LATERAL FLATTEN it.
-- Handles: invalid manufacturer IDs, invalid dates, invalid priority values,
--           text in numeric fields.

with source as (
    select
        raw_data,
        loaded_at
    from {{ source('raw', 'raw_shipment_requests') }}
    where raw_data is not null
),

-- Flatten the nested records array out of each batch payload
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
        trim(record:shipment_id::string)                        as shipment_id,

        -- Foreign keys
        trim(record:manufacturer_id::string)                    as manufacturer_id,
        trim(record:retailer_id::string)                        as retailer_id,

        -- Location
        initcap(trim(record:pickup_location::string))           as pickup_location,
        initcap(trim(record:delivery_location::string))         as delivery_location,

        -- Dates / timestamps
        {{ safe_to_timestamp("record:shipment_date::string") }} as shipment_timestamp,
        date({{ safe_to_timestamp("record:shipment_date::string") }}) as shipment_date,

        -- Priority: only allow known valid values
        case
            when upper(trim(record:priority::string)) in ('HIGH', 'MEDIUM', 'LOW', 'CRITICAL')
                then upper(trim(record:priority::string))
            else null
        end                                                     as priority,

        -- Numeric: guard against text values
        case
            when try_to_number(record:total_weight::string, 18, 4) > 0
                then try_to_number(record:total_weight::string, 18, 4)
            else null
        end                                                     as total_weight_kg,

        -- Status
        upper(trim(record:shipment_status::string))             as shipment_status,

        -- Batch metadata
        loaded_at                                               as _snowpipe_loaded_at,
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['record:shipment_id::string']) }}  as shipment_sk

    from flattened
    where trim(record:shipment_id::string) is not null
      and trim(record:shipment_id::string) != ''
),

with_dq_flags as (
    select
        *,
        case when shipment_timestamp is null   then true else false end  as dq_invalid_date,
        case when priority is null             then true else false end  as dq_invalid_priority,
        case when total_weight_kg is null      then true else false end  as dq_invalid_weight,
        -- Flag manufacturer IDs that look malformed (expect M + digits pattern)
        case
            when not regexp_like(manufacturer_id, '^M[0-9]+$')
                then true
            else false
        end                                                             as dq_invalid_manufacturer_id
    from parsed
)

select * from with_dq_flags