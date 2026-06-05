-- models/intermediate/int_delivery_performance.sql
-- Aggregates delivery performance metrics at the transport-partner + date grain.
-- Used directly by fct_deliveries and the analytics team's SLA dashboards.

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'performance_sk',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge'
    )
}}

with shipments as (
    select * from {{ ref('int_shipments') }}
    where delivery_date is not null
      and transport_partner_id is not null
),

aggregated as (
    select
        -- Grain: transport partner × delivery date
        transport_partner_id,
        delivery_date,

        -- Volume
        count(*)                                                as total_shipments,
        sum(case when delivery_outcome = 'ON_TIME' then 1 else 0 end) as on_time_deliveries,
        sum(case when delivery_outcome = 'LATE' then 1 else 0 end) as late_deliveries,
        sum(case when delivery_outcome = 'FAILED' then 1 else 0 end) as failed_deliveries,
        sum(case when delivery_outcome = 'PENDING' then 1 else 0 end) as pending_deliveries,

        -- Weight
        sum(total_weight_kg)                                   as total_weight_kg_delivered,
        avg(total_weight_kg)                                   as avg_shipment_weight_kg,

        -- Transit time KPIs (hours)
        avg(actual_transit_hours)                              as avg_actual_transit_hours,
        avg(estimated_transit_hours)                           as avg_estimated_transit_hours,
        avg(delivery_variance_hours)                           as avg_delivery_variance_hours,
        min(actual_transit_hours)                              as min_transit_hours,
        max(actual_transit_hours)                              as max_transit_hours,

        -- Priority breakdown
        sum(case when priority = 'CRITICAL' then 1 else 0 end) as critical_shipments,
        sum(case when priority = 'HIGH' then 1 else 0 end) as high_priority_shipments,

        -- SLA rate
        {{ safe_divide('sum(case when delivery_outcome = \'ON_TIME\' then 1 else 0 end)', 'count(*)') }}
                                                               as on_time_rate,
        {{ safe_divide('sum(case when delivery_outcome = \'FAILED\' then 1 else 0 end)', 'count(*)') }}
                                                               as failure_rate

    from shipments
    group by transport_partner_id, delivery_date
),

with_sk as (
    select
        {{ generate_surrogate_key(['transport_partner_id', 'delivery_date']) }}
                                                               as performance_sk,
        *,
        current_timestamp()::timestamp_ntz                    as _dbt_updated_at
    from aggregated
)

select * from with_sk

{% if is_incremental() %}
    where delivery_date >= (
        select dateadd('day', -3, max(delivery_date)) from {{ this }}
    )
{% endif %}