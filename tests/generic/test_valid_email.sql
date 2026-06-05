-- tests/generic/test_valid_email.sql
-- Generic test: asserts that a column contains only valid email addresses
-- (or NULL). Fails if any non-null value fails the regex check.
--
-- Usage in schema.yml:
--   - name: email
--     tests:
--       - valid_email

{% test valid_email(model, column_name) %}

select
    {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and not regexp_like(
    {{ column_name }},
    '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$'
  )

{% endtest %}