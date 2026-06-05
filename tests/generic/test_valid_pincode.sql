-- tests/generic/test_valid_pincode.sql
-- Generic test: asserts that a column contains only valid Indian pincodes
-- (exactly 6 digits, first digit 1-9) or NULL.
--
-- Usage in schema.yml:
--   - name: pincode
--     tests:
--       - valid_pincode

{% test valid_pincode(model, column_name) %}

select
    {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and not regexp_like(
    {{ column_name }},
    '^[1-9][0-9]{5}$'
  )

{% endtest %}