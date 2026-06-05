-- tests/singular/test_shipment_delivery_outcome_consistency.sql
-- Asserts that when a delivery confirmation exist (delivery_status = DELIVERED),
-- fct_shipments.delivery_outcome is either ON_TIME or LATE — never PENDING or FAILED.

select
    fs.shipment_id,
    fs.delivery_outcome,
    fd.delivery_status
from {{ ref('fct_shipments') }}   fs
join {{ ref('fct_deliveries') }}  fd
    on fs.shipment_id = fd.shipment_id
where fd.delivery_status = 'DELIVERED'
  and fs.delivery_outcome in ('PENDING', 'FAILED')