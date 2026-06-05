-- models/marts/facts/fct_orders.sql
-- Retailer order fact table. One row per order.
-- Enriched with shipment and delivery context.

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'surrogate_key',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge',
        cluster_by          = ['order_date', 'order_status']
    )
}}

with orders as (
    select * from {{ ref('stg_retailer_orders') }}
    where dq_invalid_order_date = false
),

shipments as (
    select
        shipment_id,
        manufacturer_sk,
        transport_partner_sk,
        vehicle_sk,
        delivery_outcome,
        delivery_date,
        delivery_timestamp,
        actual_transit_hours,
        delivery_variance_hours,
        total_weight_kg
    from {{ ref('fct_shipments') }}
),

dim_retailer as (
    select retailer_id, retailer_sk from {{ ref('dim_retailer') }}
),

dim_date_order as (
    select date_id, date_key_int from {{ ref('dim_date') }}
),

dim_date_delivery as (
    select date_id, date_key_int from {{ ref('dim_date') }}
),

final as (
    select
        -- ── Surrogate key ─────────────────────────────────────────────────
        {{ generate_surrogate_key(['o.order_id']) }}            as surrogate_key,

        -- ── Natural keys ──────────────────────────────────────────────────
        o.order_id,
        o.retailer_id,
        o.shipment_id,

        -- ── Dimension FKs ─────────────────────────────────────────────────
        dr.retailer_sk,
        s.manufacturer_sk,
        s.transport_partner_sk,
        s.vehicle_sk,
        dd_order.date_key_int                                   as order_date_key,
        dd_delivery.date_key_int                                as delivery_date_key,

        -- ── Date attributes ───────────────────────────────────────────────
        o.order_date,
        o.expected_delivery_date,
        s.delivery_date                                         as actual_delivery_date,

        -- ── Status attributes ─────────────────────────────────────────────
        o.order_status,
        s.delivery_outcome,

        -- ── Measures ─────────────────────────────────────────────────────
        o.days_to_expected_delivery,
        s.total_weight_kg,
        s.actual_transit_hours,
        s.delivery_variance_hours,

        -- ── SLA measures ──────────────────────────────────────────────────
        case when s.delivery_outcome = 'ON_TIME' then 1 else 0 end  as is_on_time,
        case when s.delivery_outcome = 'LATE'    then 1 else 0 end  as is_late,
        case when o.order_status     = 'CANCELLED' then 1 else 0 end as is_cancelled,

        -- ── DQ flags ─────────────────────────────────────────────────────
        o.dq_invalid_order_date,
        o.dq_invalid_expected_date,
        o.dq_negative_lead_time,
        o.dq_invalid_status,

        -- ── Metadata ─────────────────────────────────────────────────────
        o._dbt_loaded_at

    from orders o
    left join shipments        s          on o.shipment_id          = s.shipment_id
    left join dim_retailer     dr         on o.retailer_id          = dr.retailer_id
    left join dim_date_order   dd_order   on o.order_date           = dd_order.date_id
    left join dim_date_delivery dd_delivery on s.delivery_date      = dd_delivery.date_id
)

select * from final

{% if is_incremental() %}
    where _dbt_loaded_at > (
        select max(_dbt_loaded_at) from {{ this }}
    )
    or not exists (select 1 from {{ this }})
{% endif %}