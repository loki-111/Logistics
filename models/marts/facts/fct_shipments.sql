-- models/marts/facts/fct_shipments.sql
-- Core shipment fact table. One row per shipment.
-- All dimension FKs use surrogate keys for warehouse join efficiency.
-- Materialized incrementally using merge on surrogate_key.

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'surrogate_key',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge',
        cluster_by          = ['shipment_date', 'delivery_outcome']
    )
}}

with shipments as (
    select * from {{ ref('int_shipments') }}
),

dim_manufacturer as (
    select manufacturer_id, manufacturer_sk from {{ ref('dim_manufacturer') }}
),

dim_retailer as (
    select retailer_id, retailer_sk from {{ ref('dim_retailer') }}
),

dim_transport_partner as (
    select transport_partner_id, transport_partner_sk from {{ ref('dim_transport_partner') }}
),

dim_vehicle as (
    select vehicle_id, vehicle_sk from {{ ref('dim_vehicle') }}
),

dim_date as (
    select date_id, date_key_int from {{ ref('dim_date') }}
),

final as (
    select
        -- ── Surrogate key (degenerate on shipment_id) ─────────────────────
        {{ generate_surrogate_key(['s.shipment_id']) }}        as surrogate_key,

        -- ── Natural/degenerate keys ───────────────────────────────────────
        s.shipment_id,
        s.allocation_id,

        -- ── Dimension foreign keys (surrogate) ────────────────────────────
        dm.manufacturer_sk,
        dr.retailer_sk,
        dtp.transport_partner_sk,
        dv.vehicle_sk,
        dd_ship.date_key_int                                   as shipment_date_key,
        dd_del.date_key_int                                    as delivery_date_key,

        -- ── Dimension natural keys (for debugging) ────────────────────────
        s.manufacturer_id,
        s.retailer_id,
        s.transport_partner_id,
        s.vehicle_id,

        -- ── Date attributes ───────────────────────────────────────────────
        s.shipment_date,
        s.shipment_timestamp,
        s.delivery_date,
        s.delivery_timestamp,
        s.allocated_timestamp,
        s.estimated_delivery_timestamp,

        -- ── Descriptive attributes ────────────────────────────────────────
        s.pickup_location,
        s.delivery_location,
        s.priority,
        s.priority_rank,
        s.shipment_status,
        s.allocation_status,
        s.delivery_status,
        s.delivery_outcome,
        case when s.delivery_outcome = 'ON_TIME'  then 1 else 0 end as on_time_flag,

        case when s.delivery_outcome = 'LATE'
            then 1 else 0 end as late_flag,

        case when s.delivery_outcome = 'FAILED'
             then 1 else 0 end as failed_flag,

        case when s.delivery_outcome in ('ON_TIME','LATE')
            then 1 else 0 end as delivered_flag,
        case
    when s.delivery_outcome='ON_TIME'
        then 'WITHIN_SLA'

    when s.delivery_outcome='LATE'
        then 'BREACHED_SLA'

    when s.delivery_outcome='FAILED'
        then 'FAILED'

    when s.delivery_outcome='PARTIAL'
        then 'PARTIAL'

    else 'PENDING'
end as sla_status,
    case

    when s.actual_transit_hours < 12
        then '0-12 Hours'

    when s.actual_transit_hours < 24
        then '12-24 Hours'

    when s.actual_transit_hours < 48
        then '1-2 Days'

    when s.actual_transit_hours < 120
        then '2-5 Days'

    else '5+ Days'

end as transit_bucket,
    case

    when s.delivery_variance_hours < 0
        then 'EARLY'

    when s.delivery_variance_hours <= 6
        then '0-6 Hours'

    when s.delivery_variance_hours <= 24
        then '6-24 Hours'

    when s.delivery_variance_hours <= 48
        then '1-2 Days'

    else '2+ Days'

end as delay_bucket,

case

    when s.total_weight_kg < 100
        then 'LIGHT'

    when s.total_weight_kg < 1000
        then 'MEDIUM'

    when s.total_weight_kg < 5000
        then 'HEAVY'

    else 'VERY_HEAVY'

end as weight_bucket,
case

    when s.hours_to_allocation <= 1
        then '0-1 Hour'

    when s.hours_to_allocation <= 4
        then '1-4 Hours'

    when s.hours_to_allocation <= 12
        then '4-12 Hours'

    when s.hours_to_allocation <= 24
        then '12-24 Hours'

    else '24+ Hours'

end as allocation_bucket,


        -- ── Measures ─────────────────────────────────────────────────────
        s.total_weight_kg,
        s.hours_to_allocation,
        s.actual_transit_hours,
        s.estimated_transit_hours,
        s.delivery_variance_hours,


        -- ── Metadata ─────────────────────────────────────────────────────
        s._snowpipe_loaded_at,
        s._dbt_updated_at

    from shipments s
    left join dim_manufacturer    dm  on s.manufacturer_id     = dm.manufacturer_id
    left join dim_retailer        dr  on s.retailer_id         = dr.retailer_id
    left join dim_transport_partner dtp on s.transport_partner_id = dtp.transport_partner_id
    left join dim_vehicle          dv  on s.vehicle_id         = dv.vehicle_id
    left join dim_date             dd_ship on s.shipment_date  = dd_ship.date_id
    left join dim_date             dd_del  on s.delivery_date  = dd_del.date_id
)

select * from final f

{% if is_incremental() %}
    -- Filter on _snowpipe_loaded_at for new raw batches, AND also pick up
    -- any shipment that int_shipments re-processed (e.g. delivery data arrived
    -- after the shipment was first loaded). We compare against the last time
    -- fct_shipments ran using _snowpipe_loaded_at which exists in {{ this }},
    -- but drive completeness via int_shipments._dbt_updated_at directly.
    where f.shipment_id in (
        select shipment_id
        from {{ ref('int_shipments') }}
        where _dbt_updated_at > (
            select coalesce(max(_snowpipe_loaded_at), '1900-01-01'::timestamp_ntz)
            from {{ this }}
        )
    )
{% endif %}