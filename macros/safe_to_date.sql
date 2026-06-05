{% macro safe_to_date(column_name, format_str='AUTO') %}
    {#-
        Safely casts a string column to DATE.
        Returns NULL instead of erroring on invalid values.
        Supports AUTO format detection or explicit format strings.
        Usage: {{ safe_to_date('order_date') }}
                {{ safe_to_date('created_date', 'YYYY-MM-DD') }}
    -#}
    try_to_date(
        trim({{ column_name }}),
        '{{ format_str }}'
    )
{% endmacro %}