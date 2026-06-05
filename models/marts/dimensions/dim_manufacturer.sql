-- models/marts/dimensions/dim_manufacturer.sql
-- SCD Type 1 dimension — always reflects the latest manufacturer state.
-- Enriched with shipment volume KPIs for self-service analytics.

{{
    config(
        materialized    = 'table',
        cluster_by      = ['country', 'state']
    )
}}

with manufacturers as (
    select * from {{ ref('stg_manufacturers') }}
),

shipment_summary as (
    select
        manufacturer_id,
        count(*)                                               as total_shipments,
        SUM(case when shipment_status = 'DELIVERED' then 1 else 0 end)                 as delivered_shipments,
        sum(total_weight_kg)                                   as total_weight_shipped_kg,
        min(shipment_date)                                     as first_shipment_date,
        max(shipment_date)                                     as last_shipment_date
    from {{ ref('stg_shipment_requests') }}
    where dq_invalid_manufacturer_id = false
    group by manufacturer_id
),

final as (
    select
        -- Surrogate key (use as FK in fact tables)
        m.manufacturer_sk,

        -- Natural key
        m.manufacturer_id,

        -- Attributes
        m.manufacturer_name,
        m.contact_person,
        m.phone,
        m.email,
        m.city,
        m.state,
        m.country,
        m.pincode,
        m.manufacturer_type,
        m.created_date,

        -- Data quality flags
        m.dq_invalid_email,
        m.dq_invalid_pincode,
        m.dq_null_phone,

        -- Embedded KPIs (denormalized for BI convenience)
        coalesce(s.total_shipments, 0)                         as total_shipments,
        coalesce(s.delivered_shipments, 0)                     as delivered_shipments,
        coalesce(s.total_weight_shipped_kg, 0)                 as total_weight_shipped_kg,
        s.first_shipment_date,
        s.last_shipment_date,
        {{ safe_divide('s.delivered_shipments', 's.total_shipments') }}
                                                               as delivery_success_rate,

        -- Metadata
        current_timestamp()::timestamp_ntz                    as dbt_updated_at

    from manufacturers m
    left join shipment_summary s on m.manufacturer_id = s.manufacturer_id
)

select * from final