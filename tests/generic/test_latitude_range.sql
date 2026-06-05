-- tests/generic/test_latitude_range.sql
-- Generic test: asserts that a latitude column is within [-90, 90].
-- Null values pass (no constraint on nullability here).
--
-- Usage in schema.yml:
--   - name: latitude
--     tests:
--       - latitude_range

{% test latitude_range(model, column_name) %}

select
    {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and (
    {{ column_name }} < -90.0
    or {{ column_name }} > 90.0
  )

{% endtest %}