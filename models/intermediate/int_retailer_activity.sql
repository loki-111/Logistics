-- models/intermediate/int_retailer_activity.sql
-- Retailer-level activity summary: order volumes, delivery performance,
-- and engagement recency. Used by dim_retailer and fct_orders.

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'retailer_id',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge'
    )
}}

with retailers as (
    select * from {{ ref('stg_retailers') }}
),

orders as (
    select * from {{ ref('stg_retailer_orders') }}
    where dq_invalid_order_date = false
),

shipments as (
    select * from {{ ref('int_shipments') }}
),

order_summary as (
    select
        o.retailer_id,
        count(*)                                               as total_orders,
        sum(case when o.order_status = 'DELIVERED' then 1 else 0 end) as delivered_orders,
        sum(case when o.order_status = 'CANCELLED' then 1 else 0 end) as cancelled_orders,
        sum(case when o.order_status = 'PENDING' then 1 else 0 end) as pending_orders,
        min(o.order_date)                                      as first_order_date,
        max(o.order_date)                                      as last_order_date,
        avg(o.days_to_expected_delivery)                       as avg_expected_lead_days
    from orders o
    group by o.retailer_id
),

shipment_summary as (
    select
        s.retailer_id,
        count(*)                                               as total_shipments_received,
        sum(case when s.delivery_outcome = 'ON_TIME' then 1 else 0 end) as on_time_received,
        sum(case when s.delivery_outcome = 'LATE' then 1 else 0 end) as late_received,
        sum(case when s.delivery_outcome = 'FAILED' then 1 else 0 end) as failed_received,
        sum(s.total_weight_kg)                                 as total_weight_received_kg,
        avg(s.actual_transit_hours)                            as avg_actual_transit_hours
    from shipments s
    where s.retailer_id is not null
    group by s.retailer_id
),

joined as (
    select
        r.retailer_id,
        r.retailer_sk,
        r.retailer_name,
        r.retailer_type,
        r.city,
        r.state,
        r.country,

        -- Order KPIs
        coalesce(o.total_orders, 0)                            as total_orders,
        coalesce(o.delivered_orders, 0)                        as delivered_orders,
        coalesce(o.cancelled_orders, 0)                        as cancelled_orders,
        coalesce(o.pending_orders, 0)                          as pending_orders,
        o.first_order_date,
        o.last_order_date,
        o.avg_expected_lead_days,
        datediff('day', o.last_order_date, current_date())    as days_since_last_order,

        -- Shipment KPIs
        coalesce(s.total_shipments_received, 0)                as total_shipments_received,
        coalesce(s.on_time_received, 0)                        as on_time_received,
        coalesce(s.late_received, 0)                           as late_received,
        coalesce(s.failed_received, 0)                         as failed_received,
        coalesce(s.total_weight_received_kg, 0)                as total_weight_received_kg,
        s.avg_actual_transit_hours,

        -- Derived
        {{ safe_divide('s.on_time_received', 's.total_shipments_received') }}
                                                               as on_time_receipt_rate,
        case
            when datediff('day', o.last_order_date, current_date()) <= 30  then 'ACTIVE'
            when datediff('day', o.last_order_date, current_date()) <= 90  then 'MODERATE'
            when datediff('day', o.last_order_date, current_date()) <= 180 then 'LAPSING'
            else 'INACTIVE'
        end                                                    as retailer_engagement_tier,

        current_timestamp()::timestamp_ntz                    as _dbt_updated_at

    from retailers r
    left join order_summary    o on r.retailer_id = o.retailer_id
    left join shipment_summary s on r.retailer_id = s.retailer_id
)

select * from joined

{% if is_incremental() %}
    where retailer_id in (
        select distinct retailer_id from {{ ref('stg_retailer_orders') }}
        where _dbt_loaded_at > (select max(_dbt_updated_at) from {{ this }})
    )
{% endif %}