-- snapshots/snapshot_vehicles.sql
-- SCD Type 2 snapshot tracking changes to vehicle status and availability.
-- Triggers on: vehicle_status, vehicle_capacity_kg, current_location, is_available.
-- Strategy: check — compares a hash of tracked columns to detect changes.

{% snapshot snapshot_vehicles %}


select
    vehicle_id,
    transport_partner_id,
    vehicle_type,
    vehicle_capacity_kg,
    vehicle_status,
    current_location,
    is_available,
    is_truly_available,
    partner_company_name,
    transport_mode,
    current_timestamp()::timestamp_ntz   as _snapshot_captured_at

from {{ ref('int_vehicle_status') }}

{% endsnapshot %}