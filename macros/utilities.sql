{% macro get_fiscal_year(date_column, fiscal_year_start_month=4) %}
    {#-
        Returns the fiscal year for a given date.
        Default: fiscal year starts in April (common in India).
        Usage: {{ get_fiscal_year('shipment_date') }}
    -#}
    case
        when month({{ date_column }}) >= {{ fiscal_year_start_month }}
            then year({{ date_column }})
        else year({{ date_column }}) - 1
    end
{% endmacro %}


{% macro get_fiscal_quarter(date_column, fiscal_year_start_month=4) %}
    {#-
        Returns fiscal quarter (Q1-Q4) based on fiscal year start month.
        Default: April = Q1.
        Usage: {{ get_fiscal_quarter('shipment_date') }}
    -#}
    case
        when month({{ date_column }}) >= {{ fiscal_year_start_month }}
            then ceil((month({{ date_column }}) - {{ fiscal_year_start_month }} + 1) / 3.0)
        else ceil((month({{ date_column }}) + 12 - {{ fiscal_year_start_month }} + 1) / 3.0)
    end
{% endmacro %}


{% macro safe_divide(numerator, denominator, default_value=0) %}
    {#-
        Safe division — returns default_value (default 0) when denominator is zero or null.
        Usage: {{ safe_divide('total_revenue', 'shipment_count') }}
    -#}
    iff(
        {{ denominator }} is null or {{ denominator }} = 0,
        {{ default_value }},
        {{ numerator }} / {{ denominator }}
    )
{% endmacro %}


{% macro current_timestamp_ntz() %}
    {#- Returns current timestamp in UTC (no timezone) for Snowflake -#}
    convert_timezone('UTC', current_timestamp())::timestamp_ntz
{% endmacro %}