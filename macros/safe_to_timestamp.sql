{% macro safe_to_timestamp(column_name, format_str='AUTO') %}
    {#-
        Safely casts a string column to TIMESTAMP_NTZ.
        Returns NULL instead of erroring on invalid/malformed values.
        Usage: {{ safe_to_timestamp('delivery_timestamp') }}
                {{ safe_to_timestamp('tracking_time', 'YYYY-MM-DDTHH24:MI:SS') }}
    -#}
    try_to_timestamp_ntz(
        trim({{ column_name }}),
        '{{ format_str }}'
    )
{% endmacro %}