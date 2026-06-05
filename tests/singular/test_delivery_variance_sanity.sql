-- tests/singular/test_delivery_variance_sanity.sql
-- Asserts that no delivered shipment has an implausibly large variance.
-- Flags any shipment delivered more than 30 days late or 7 days early —
-- these indicate data quality issues upstream (e.g., wrong year in timestamp).
{{ config(severity='warn') }}
select
    shipment_id,
    delivery_outcome,
    delivery_variance_hours,
    actual_transit_hours,
    estimated_transit_hours
from {{ ref('fct_shipments') }}
where delivery_outcome in ('ON_TIME', 'LATE')
  and (
      delivery_variance_hours > (30 * 24)   -- more than 30 days late
      or delivery_variance_hours < -(7 * 24) -- more than 7 days early
  )