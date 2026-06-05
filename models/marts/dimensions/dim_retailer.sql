-- models/marts/dimensions/dim_retailer.sql
-- SCD Type 1 retailer dimension, enriched with activity KPIs from the
-- intermediate layer.

{{
    config(
        materialized    = 'table',
        cluster_by      = ['country', 'state']
    )
}}

with activity as (
    select * from {{ ref('int_retailer_activity') }}
),

final as (
    select
        -- Surrogate key
        a.retailer_sk,

        -- Natural key
        a.retailer_id,

        -- Attributes
        a.retailer_name,
        a.retailer_type,
        a.city,
        a.state,
        a.country,

        -- Order KPIs
        a.total_orders,
        a.delivered_orders,
        a.cancelled_orders,
        a.pending_orders,
        a.first_order_date,
        a.last_order_date,
        a.avg_expected_lead_days,
        a.days_since_last_order,

        -- Shipment receipt KPIs
        a.total_shipments_received,
        a.on_time_received,
        a.late_received,
        a.failed_received,
        a.total_weight_received_kg,
        a.avg_actual_transit_hours,
        a.on_time_receipt_rate,

        -- Engagement
        a.retailer_engagement_tier,

        -- Metadata
        current_timestamp()::timestamp_ntz                    as dbt_updated_at

    from activity a
)

select * from final