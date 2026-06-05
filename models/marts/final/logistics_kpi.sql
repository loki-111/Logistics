{{ config(
    materialized='table'
) }}

with shipments as (

    select *
    from {{ ref('fct_shipments') }}

),

vehicles as (

    select *
    from {{ ref('dim_vehicle') }}

),

partners as (

    select *
    from {{ ref('dim_transport_partner') }}

)

select


    /* Volume KPIs */

    count(distinct shipment_id)                     as total_shipments,

    count(distinct manufacturer_sk)                as active_manufacturers,

    count(distinct retailer_sk)                    as active_retailers,

    count(distinct s.transport_partner_sk)           as active_transport_partners,

    count(distinct s.vehicle_sk)                     as active_vehicles,

    /* Delivery KPIs */

    sum(on_time_flag)                                as on_time_shipments,

    sum(late_flag)                                   as late_shipments,

    sum(failed_flag)                                 as failed_shipments,

    round(
        sum(on_time_flag) / count(distinct shipment_id)   ,
        4
    )                                              as on_time_rate,

    round(
        sum(late_flag) / count(distinct shipment_id)   ,
        4
    )                                              as late_rate,

    round(
        sum(failed_flag) / count(distinct shipment_id)   ,
        4
    )                                              as failure_rate,

    /* Transit KPIs */

    avg(actual_transit_hours)                      as avg_transit_hours,

    avg(hours_to_allocation)                       as avg_allocation_hours,

    avg(delivery_variance_hours)                   as avg_delivery_variance_hours,

    /* Weight KPIs */

    sum(total_weight_kg)                           as total_weight_kg,

    avg(total_weight_kg)                           as avg_weight_per_shipment,

    /* Partner KPIs */

    avg(
        coalesce(p.performance_score,0)
    )                                              as avg_partner_score,

    /* Vehicle KPIs */

    count(distinct
        case
            when v.is_truly_available = true
            then v.vehicle_id
        end
    )                                              as available_vehicles,

    count(distinct v.vehicle_id)                   as total_vehicles,

    round(
        count(distinct case
            when v.is_truly_available = true
            then v.vehicle_id
        end)
        /
        nullif(count(distinct v.vehicle_id),0),
        4
    )                                              as vehicle_availability_rate

from shipments s

left join vehicles v
    on s.vehicle_sk = v.vehicle_sk

left join partners p
    on s.transport_partner_sk = p.transport_partner_sk

