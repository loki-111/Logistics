-- models/marts/facts/fct_deliveries.sql
-- Delivery-level fact table. One row per confirmed delivery event.
-- Joins with fct_shipments to inherit shipment-level attributes.

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'surrogate_key',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge',
        cluster_by          = ['delivery_date', 'delivery_status']
    )
}}

with deliveries as (
    select * from {{ ref('stg_delivery_confirmation') }}
),

shipments as (
    select
        shipment_id,
        manufacturer_sk,
        retailer_sk,
        transport_partner_sk,
        vehicle_sk,
        shipment_date_key,
        pickup_location,
        delivery_location,
        priority,
        total_weight_kg,
        estimated_delivery_timestamp,
        actual_transit_hours,
        delivery_outcome,
        delivery_variance_hours
    from {{ ref('fct_shipments') }}
),

dim_retailer as (
    select retailer_id, retailer_sk from {{ ref('dim_retailer') }}
),

dim_date as (
    select date_id, date_key_int from {{ ref('dim_date') }}
),

final as (
    select
        -- ── Surrogate key ─────────────────────────────────────────────────
        {{ generate_surrogate_key(['d.delivery_id']) }}         as surrogate_key,

        -- ── Natural keys ──────────────────────────────────────────────────
        d.delivery_id,
        d.shipment_id,
        d.retailer_id,

        -- ── Dimension FKs from shipment ───────────────────────────────────
        s.manufacturer_sk,
        dr.retailer_sk,
        s.transport_partner_sk,
        s.vehicle_sk,
        s.shipment_date_key,
        dd.date_key_int                                         as delivery_date_key,

        -- ── Date/time ────────────────────────────────────────────────────
        d.delivery_date,
        d.delivery_timestamp,

        -- ── Status ───────────────────────────────────────────────────────
        d.delivery_status,
        s.delivery_outcome,

        -- ── Descriptive attributes ────────────────────────────────────────
        s.pickup_location,
        s.delivery_location,
        s.priority,
        d.received_by,

        -- ── Measures ─────────────────────────────────────────────────────
        s.total_weight_kg,
        s.actual_transit_hours,
        s.delivery_variance_hours,

        -- ── SLA measures ──────────────────────────────────────────────────
        case when s.delivery_outcome = 'ON_TIME' then 1 else 0 end  as is_on_time,
        case when s.delivery_outcome = 'LATE'    then 1 else 0 end  as is_late,
        case when d.delivery_status  = 'FAILED'  then 1 else 0 end  as is_failed,
        case when d.delivery_status  = 'PARTIAL' then 1 else 0 end  as is_partial,

        -- ── DQ flags ─────────────────────────────────────────────────────
        d.dq_missing_timestamp,
        d.dq_invalid_status,

        -- ── Metadata ─────────────────────────────────────────────────────
        d._dbt_loaded_at

    from deliveries d
    left join shipments    s  on d.shipment_id  = s.shipment_id
    left join dim_retailer dr on d.retailer_id  = dr.retailer_id
    left join dim_date     dd on d.delivery_date = dd.date_id
)

select * from final

{% if is_incremental() %}
    where _dbt_loaded_at > (
        select max(_dbt_loaded_at) from {{ this }}
    )
{% endif %}