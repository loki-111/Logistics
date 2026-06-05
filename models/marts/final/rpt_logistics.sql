select
    s.*,

    d.year,
    d.month_name,
    d.quarter_name,
    d.fiscal_year,
    d.date_id,

    m.manufacturer_name,
    m.manufacturer_type,

    r.retailer_name,
    r.retailer_type,

    tp.company_name,
    tp.transport_mode,
    tp.performance_score,
    tp.performance_tier,

    v.vehicle_type,
    v.capacity_tier,
    v.is_available,
    v.utilization_band

from {{ ref('fct_shipments') }} s

left join {{ ref('dim_date') }} d
    on s.shipment_date_key = d.date_key_int

left join {{ ref('dim_manufacturer') }} m
    on s.manufacturer_sk = m.manufacturer_sk

left join {{ ref('dim_retailer') }} r
    on s.retailer_sk = r.retailer_sk

left join {{ ref('dim_transport_partner') }} tp
    on s.transport_partner_sk = tp.transport_partner_sk

left join {{ ref('dim_vehicle') }} v
    on s.vehicle_sk = v.vehicle_sk