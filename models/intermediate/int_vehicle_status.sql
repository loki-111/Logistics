-- models/intermediate/int_vehicle_status.sql
-- Enriches vehicle records with transport partner context and current
-- allocation state derived from shipment_allocation.
-- Materialized incrementally, keyed on vehicle_id.

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'vehicle_id',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge'
    )
}}

with vehicles as (

    select *
    from {{ ref('stg_vehicles') }}

    qualify row_number() over (
        partition by vehicle_id
        order by _snowpipe_loaded_at desc
    ) = 1

),
partners as (
    select
        transport_partner_id,
        company_name,
        transport_mode,
        service_area,
        rating,
        is_active
    from {{ ref('stg_transport_partners') }}
),

-- Most recent active allocation per vehicle
latest_allocation as (
    select
        vehicle_id,
        shipment_id,
        allocated_timestamp,
        estimated_delivery_timestamp,
        allocation_status
    from {{ ref('stg_shipment_allocation') }}
    where allocation_status in ('ALLOCATED', 'CONFIRMED')
    qualify row_number() over (
        partition by vehicle_id
        order by allocated_timestamp desc nulls last
    ) = 1
),

-- Lifetime utilization stats per vehicle
vehicle_utilization as (
    select
        vehicle_id,
        count(*)                                                as total_allocations,
        sum(case when allocation_status = 'COMPLETED' then 1 else 0 end)               as completed_allocations,
        sum(case when allocation_status = 'CANCELLED' then 1 else 0 end)               as cancelled_allocations,
        sum(estimated_transit_hours)                           as total_estimated_transit_hours,
        max(allocated_timestamp)                               as last_allocated_at
    from {{ ref('stg_shipment_allocation') }}
    group by vehicle_id
),

joined as (
    select
        -- ── Vehicle identity ──────────────────────────────────────────────
        v.vehicle_id,
        v.vehicle_sk,
        v.vehicle_type,
        v.vehicle_capacity_kg,
        v.vehicle_status,
        v.current_location,
        v.is_available,

        -- ── Partner context ───────────────────────────────────────────────
        v.transport_partner_id,
        p.company_name                                          as partner_company_name,
        p.transport_mode,
        p.service_area,
        p.rating                                               as partner_rating,
        p.is_active                                            as partner_is_active,

        -- ── Current allocation ────────────────────────────────────────────
        la.shipment_id                                         as current_shipment_id,
        la.allocation_status                                   as current_allocation_status,
        la.allocated_timestamp                                 as current_allocated_at,
        la.estimated_delivery_timestamp                        as current_estimated_delivery,

        -- ── Derived availability ──────────────────────────────────────────
        case
            when v.is_available = true
                 and la.shipment_id is null
                 and v.vehicle_status = 'AVAILABLE'
                then true
            else false
        end                                                    as is_truly_available,

        -- ── Utilization KPIs ──────────────────────────────────────────────
        coalesce(u.total_allocations, 0)                       as total_allocations,
        coalesce(u.completed_allocations, 0)                   as completed_allocations,
        coalesce(u.cancelled_allocations, 0)                   as cancelled_allocations,
        coalesce(u.total_estimated_transit_hours, 0)           as total_estimated_transit_hours,
        {{ safe_divide('u.completed_allocations', 'u.total_allocations') }}
                                                               as completion_rate,
        u.last_allocated_at,

        -- ── DQ flags ─────────────────────────────────────────────────────
        v.dq_invalid_partner_id,
        v.dq_negative_capacity,

        -- ── Metadata ─────────────────────────────────────────────────────
        v._snowpipe_loaded_at,
        current_timestamp()::timestamp_ntz                     as _dbt_updated_at

    from vehicles v
    left join partners          p  on v.transport_partner_id = p.transport_partner_id
    left join latest_allocation la on v.vehicle_id = la.vehicle_id
    left join vehicle_utilization u on v.vehicle_id = u.vehicle_id
)

select * from joined j

{% if is_incremental() %}
    where not exists (
        select 1 from {{ this }} t
        where t.vehicle_id = j.vehicle_id
    )
    or _snowpipe_loaded_at > (select max(_snowpipe_loaded_at) from {{ this }})
{% endif %}