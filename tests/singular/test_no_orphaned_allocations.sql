-- tests/singular/test_no_orphaned_allocations.sql
-- Asserts that every allocation in stg_shipment_allocation references
-- a shipment that exists in stg_shipment_requests.
-- Returns rows that violate this referential integrity check.

select
    a.allocation_id,
    a.shipment_id
from {{ ref('stg_shipment_allocation') }}   a
left join {{ ref('stg_shipment_requests') }} s
    on a.shipment_id = s.shipment_id
where s.shipment_id is null
  and a.allocation_status != 'UNKNOWN'