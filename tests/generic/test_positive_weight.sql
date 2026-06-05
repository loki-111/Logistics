-- tests/generic/test_positive_weight.sql
-- Generic test: asserts that a weight column is strictly positive (> 0).
-- Null values are allowed (no not_null constraint enforced here).
--
-- Usage in schema.yml:
--   - name: weight_kg
--     tests:
--       - positive_weight

{% test positive_weight(model, column_name) %}

select
    {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} <= 0

{% endtest %}