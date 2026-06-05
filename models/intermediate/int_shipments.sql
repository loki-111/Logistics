-- models/intermediate/int_shipments.sql
-- Joins shipment requests with allocations and delivery confirmations to
-- produce a unified shipment-level record with derived KPIs.
-- Materialized as incremental (append-only on new shipment_ids).

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'shipment_id',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge'
    )
}}

with shipments as (
    select * from {{ ref('stg_shipment_requests') }}
    where dq_invalid_date = false
      and shipment_id is not null
),

allocations as (
    select * from {{ ref('stg_shipment_allocation') }}
    where allocation_status != 'UNKNOWN'
),

deliveries as (
    select
        shipment_id,
        delivery_status,
        delivery_timestamp,
        delivery_date
    from {{ ref('stg_delivery_confirmation') }}
    -- Keep one delivery row per shipment (latest)
    qualify row_number() over (
        partition by shipment_id
        order by delivery_timestamp desc nulls last
    ) = 1
),

manufacturers as (
    select manufacturer_id, manufacturer_name, city as manufacturer_city
    from {{ ref('stg_manufacturers') }}
),

retailers as (
    select retailer_id, retailer_name, city as retailer_city
    from {{ ref('stg_retailers') }}
),

joined as (
    select
        -- ── Core shipment fields ──────────────────────────────────────────
        s.shipment_id,
        s.shipment_sk,
        s.manufacturer_id,
        m.manufacturer_name,
        m.manufacturer_city,
        s.retailer_id,
        r.retailer_name,
        r.retailer_city,
        s.pickup_location,
        s.delivery_location,
        s.shipment_date,
        s.shipment_timestamp,
        s.priority,
        s.total_weight_kg,
        s.shipment_status,

        -- ── Allocation fields ─────────────────────────────────────────────
        a.allocation_id,
        a.transport_partner_id,
        a.vehicle_id,
        a.allocated_timestamp,
        a.estimated_delivery_timestamp,
        a.allocation_status,
        a.estimated_transit_hours,

        -- ── Delivery fields ───────────────────────────────────────────────
        d.delivery_status,
        d.delivery_timestamp,
        d.delivery_date,

        -- ── Derived KPIs ──────────────────────────────────────────────────
        datediff('hour', s.shipment_timestamp, a.allocated_timestamp)
            as hours_to_allocation,

        datediff('hour', a.allocated_timestamp, d.delivery_timestamp)
            as actual_transit_hours,

        datediff('hour', a.estimated_delivery_timestamp, d.delivery_timestamp)
            as delivery_variance_hours,   -- positive = late, negative = early

        case
            when d.delivery_status = 'DELIVERED'
                 and d.delivery_timestamp <= a.estimated_delivery_timestamp
                then 'ON_TIME'
            when d.delivery_status = 'DELIVERED'
                 and d.delivery_timestamp > a.estimated_delivery_timestamp
                then 'LATE'
            when d.delivery_status in ('FAILED', 'RETURNED')
                then 'FAILED'
            when d.delivery_status is null
                then 'PENDING'
            else 'OTHER'
        end                                                     as delivery_outcome,

        case
            when s.priority = 'CRITICAL' then 1
            when s.priority = 'HIGH'     then 2
            when s.priority = 'MEDIUM'   then 3
            when s.priority = 'LOW'      then 4
            else 99
        end                                                     as priority_rank,

        -- ── Metadata ─────────────────────────────────────────────────────
        s._snowpipe_loaded_at,
        current_timestamp()::timestamp_ntz                     as _dbt_updated_at

    from shipments s
    left join allocations     a on s.shipment_id = a.shipment_id
    left join deliveries      d on s.shipment_id = d.shipment_id
    left join manufacturers   m on s.manufacturer_id = m.manufacturer_id
    left join retailers       r on s.retailer_id = r.retailer_id
)

select * from joined

{% if is_incremental() %}
    -- On incremental runs, process only new or updated shipments
    where _snowpipe_loaded_at > (
        select max(_snowpipe_loaded_at) from {{ this }}
    )
{% endif %}