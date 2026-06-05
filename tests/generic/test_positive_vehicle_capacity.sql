-- tests/generic/test_positive_vehicle_capacity.sql
-- Generic test: asserts that vehicle_capacity_kg is strictly positive.
--
-- Usage in schema.yml:
--   - name: vehicle_capacity_kg
--     tests:
--       - positive_vehicle_capacity

{% test positive_vehicle_capacity(model, column_name) %}

select
    {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} <= 0

{% endtest %}