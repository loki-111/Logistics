-- tests/generic/test_longitude_range.sql
-- Generic test: asserts that a longitude column is within [-180, 180].
--
-- Usage in schema.yml:
--   - name: longitude
--     tests:
--       - longitude_range

{% test longitude_range(model, column_name) %}

select
    {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and (
    {{ column_name }} < -180.0
    or {{ column_name }} > 180.0
  )

{% endtest %}