{% macro boolean_normalization(column_name) %}
    {#-
        Normalizes inconsistent boolean representations to TRUE/FALSE/NULL.
        Handles: true/false, 1/0, yes/no, y/n, active/inactive, available/unavailable
        Returns: boolean TRUE, FALSE, or NULL
        Usage: {{ boolean_normalization('availability_flag') }}
    -#}
    case
        when lower(trim(cast({{ column_name }} as varchar))) in ('true',  '1', 'yes', 'y', 'active',   'available', 'on',  'enabled')  then true
        when lower(trim(cast({{ column_name }} as varchar))) in ('false', '0', 'no',  'n', 'inactive', 'unavailable','off', 'disabled') then false
        else null
    end
{% endmacro %}