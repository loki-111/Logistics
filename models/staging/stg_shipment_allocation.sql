-- models/staging/stg_shipment_allocation.sql
-- Cleans and casts shipment allocation records.

with source as (
    select * from {{ source('raw', 'raw_shipment_allocation') }}
),

cleaned as (
    select
        -- Keys
        trim(allocation_id)                                     as allocation_id,
        trim(shipment_id)                                       as shipment_id,
        trim(transport_partner_id)                              as transport_partner_id,
        trim(vehicle_id)                                        as vehicle_id,

        -- Timestamps
        {{ safe_to_timestamp('allocated_timestamp') }}          as allocated_timestamp,
        {{ safe_to_timestamp('estimated_delivery') }}           as estimated_delivery_timestamp,

        -- Status
        case
            when upper(trim(allocation_status)) in (
                'ALLOCATED', 'CONFIRMED', 'CANCELLED', 'COMPLETED'
            )
                then upper(trim(allocation_status))
            else 'UNKNOWN'
        end                                                     as allocation_status,

        -- Derived
        datediff(
            'hour',
            {{ safe_to_timestamp('allocated_timestamp') }},
            {{ safe_to_timestamp('estimated_delivery') }}
        )                                                       as estimated_transit_hours,

        -- Metadata
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['allocation_id']) }}         as allocation_sk

    from source
    where trim(allocation_id) is not null
      and trim(allocation_id) != ''
),

with_dq_flags as (
    select
        *,
        case when allocated_timestamp is null          then true else false end  as dq_missing_allocated_ts,
        case when estimated_delivery_timestamp is null then true else false end  as dq_missing_estimated_ts,
        case when allocation_status = 'UNKNOWN'        then true else false end  as dq_invalid_status,
        case when estimated_transit_hours < 0          then true else false end  as dq_negative_transit_hours
    from cleaned
)

select * from with_dq_flags