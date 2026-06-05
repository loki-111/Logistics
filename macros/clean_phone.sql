{% macro clean_phone(column_name) %}
    {#-
        Cleans phone numbers:
        - Removes all non-numeric characters
        - Keeps last 10 digits (removes country code)
        - Returns NULL if fewer than 10 digits
    -#}

    case
        when {{ column_name }} is null then 0

        else
            case
                when length(regexp_replace(trim({{ column_name }}), '[^0-9]', '')) < 10 
                    then {{ column_name }} -- Return original value if it has fewer than 10 digits
                else
                    right(regexp_replace(trim({{ column_name }}), '[^0-9]', ''), 10)
            end
    end
{% endmacro %}