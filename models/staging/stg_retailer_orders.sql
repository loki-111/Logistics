-- models/staging/stg_retailer_orders.sql
-- Cleans and casts retailer order data.

with source as (
    select * from {{ source('raw', 'raw_retailer_orders') }}
),

cleaned as (
    select
        -- Keys
        trim(order_id)                                          as order_id,
        trim(retailer_id)                                       as retailer_id,
        trim(shipment_id)                                       as shipment_id,

        -- Dates
        {{ safe_to_date('order_date') }}                        as order_date,
        {{ safe_to_date('expected_delivery_date') }}            as expected_delivery_date,

        -- Status — standardize to uppercase
        upper(trim(order_status))                               as order_status,

        -- Derived
        datediff(
            'day',
            {{ safe_to_date('order_date') }},
            {{ safe_to_date('expected_delivery_date') }}
        )                                                       as days_to_expected_delivery,

        -- Metadata
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['order_id']) }}              as order_sk

    from source
    where trim(order_id) is not null
      and trim(order_id) != ''
),

with_dq_flags as (
    select
        *,
        case when order_date is null             then true else false end  as dq_invalid_order_date,
        case when expected_delivery_date is null then true else false end  as dq_invalid_expected_date,
        case when days_to_expected_delivery < 0  then true else false end  as dq_negative_lead_time,
        case
            when order_status not in ('OPEN', 'PROCESSING', 'CLOSED', 'CANCELLED')
                then true
            else false
        end                                                               as dq_invalid_status
    from cleaned
)

select * from with_dq_flags