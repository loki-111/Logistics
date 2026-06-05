{% macro generate_surrogate_key(field_list) %}
    {#-
        Generates a SHA-256-based surrogate key from a list of fields.
        Null-safe: coerces nulls to empty string before hashing.
        Usage: {{ generate_surrogate_key(['col1', 'col2']) }}
    -#}
    {% set fields = [] %}
    {% for field in field_list %}
        {% set _ = fields.append(
            "coalesce(cast(" ~ field ~ " as varchar), '')"
        ) %}
    {% endfor %}
    sha2({{ fields | join(" || '|' || ") }}, 256)
{% endmacro %}