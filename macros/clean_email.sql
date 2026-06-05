{% macro clean_email(column_name) %}
    case
        when {{ column_name }} is null then null
        when trim({{ column_name }}) = '' then null

        when not regexp_like(
            trim(lower({{ column_name }})),
            '^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$'
        ) then null

        else trim(lower({{ column_name }}))
    end
{% endmacro %}
