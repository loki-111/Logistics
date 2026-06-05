-- models/staging/stg_delivery_confirmation.sql
-- Cleans delivery confirmation records.
-- Handles: invalid statuses, missing timestamps.

with source as (
    select * from {{ source('raw', 'raw_delivery_confirmation') }}
),

cleaned as (
    select
        -- Keys
        trim(delivery_id)                                       as delivery_id,
        trim(shipment_id)                                       as shipment_id,
        trim(retailer_id)                                       as retailer_id,

        -- Status: only accept known valid values
        case
            when upper(trim(delivery_status)) in (
                'DELIVERED', 'FAILED', 'PARTIAL', 'RETURNED', 'PENDING'
            )
                then upper(trim(delivery_status))
            else 'UNKNOWN'
        end                                                     as delivery_status,

        -- Timestamp
        {{ safe_to_timestamp('delivery_timestamp') }}           as delivery_timestamp,

        -- Received by
        initcap(trim(case when received_by is null then 'unknown' else received_by end))                              as received_by,

        -- Derived
        date({{ safe_to_timestamp('delivery_timestamp') }})    as delivery_date,

        -- Metadata
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['delivery_id']) }}           as delivery_sk

    from source
    where trim(delivery_id) is not null
      and trim(delivery_id) != ''
),

with_dq_flags as (
    select
        *,
        case when delivery_timestamp is null   then true else false end   as dq_missing_timestamp,
        case when delivery_status = 'UNKNOWN'  then true else false end   as dq_invalid_status
    from cleaned
)

select * from with_dq_flags