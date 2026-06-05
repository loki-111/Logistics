-- models/marts/dimensions/dim_vehicle.sql
-- Current-state vehicle dimension. SCD Type 2 history tracked in snapshot.

{{
    config(
        materialized    = 'table',
        cluster_by      = ['vehicle_type', 'vehicle_status']
    )
}}

with vehicle_status as (
    select * from {{ ref('int_vehicle_status') }}
),

final as (
    select
        -- Surrogate key
        v.vehicle_sk,

        -- Natural key
        v.vehicle_id,

        -- Core attributes
        v.vehicle_type,
        v.vehicle_capacity_kg,
        v.vehicle_status,
        v.current_location,
        v.is_available,
        v.is_truly_available,

        -- Partner context
        v.transport_partner_id,
        v.partner_company_name,
        v.transport_mode,
        v.service_area,
        v.partner_rating,
        v.partner_is_active,

        -- Current assignment
        v.current_shipment_id,
        v.current_allocation_status,
        v.current_allocated_at,
        v.current_estimated_delivery,

        -- Utilization
        v.total_allocations,
        v.completed_allocations,
        v.cancelled_allocations,
        v.total_estimated_transit_hours,
        v.completion_rate,
        v.last_allocated_at,

        -- Capacity tier
        case
            when v.vehicle_capacity_kg >= 20000 then 'HEAVY'
            when v.vehicle_capacity_kg >= 10000 then 'MEDIUM'
            when v.vehicle_capacity_kg >= 3000  then 'LIGHT'
            else 'MICRO'
        end                                                    as capacity_tier,

        case

    when v.completion_rate >= 0.90
        then 'HIGH'

    when v.completion_rate >= 0.70
        then 'MEDIUM'

    else 'LOW'

end as utilization_band,

        -- DQ flags
        v.dq_invalid_partner_id,
        v.dq_negative_capacity,

        -- Metadata
        current_timestamp()::timestamp_ntz                    as dbt_updated_at

    from vehicle_status v
)

select * from final