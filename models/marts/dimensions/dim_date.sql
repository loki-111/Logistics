-- models/marts/dimensions/dim_date.sql
-- Date dimension covering 2020-01-01 through 2030-12-31.
-- Includes calendar and fiscal year attributes (fiscal year starts April 1).
-- Materialized as a table — full rebuild on each run (date spine is small).

{{
    config(
        materialized    = 'table'
    )
}}

with date_spine as (
    {{
        dbt_utils.date_spine(
            datepart    = "day",
            start_date  = "cast('2020-01-01' as date)",
            end_date    = "cast('2030-12-31' as date)"
        )
    }}
),

enriched as (
    select
        -- ── Primary key ───────────────────────────────────────────────────
        cast(date_day as date)                                 as date_id,

        -- ── Calendar attributes ───────────────────────────────────────────
        year(date_day)                                         as year,
        quarter(date_day)                                      as quarter_number,
        'Q' || quarter(date_day)                               as quarter_name,
        month(date_day)                                        as month_number,
        monthname(date_day)                                    as month_name,
        left(monthname(date_day), 3)                           as month_short_name,
        week(date_day)                                         as week_of_year,
        dayofweek(date_day)                                    as day_of_week,        -- 0=Sun
        dayofweekiso(date_day)                                 as day_of_week_iso,   -- 1=Mon
        dayname(date_day)                                      as day_name,
        left(dayname(date_day), 3)                             as day_short_name,
        dayofmonth(date_day)                                   as day_of_month,
        dayofyear(date_day)                                    as day_of_year,

        -- ── Boolean calendar flags ────────────────────────────────────────
        case when dayofweekiso(date_day) in (6, 7) then true else false end
                                                               as is_weekend,
        case when dayofweekiso(date_day) between 1 and 5 then true else false end
                                                               as is_weekday,

        -- ── Period start/end flags ────────────────────────────────────────
        case when dayofmonth(date_day) = 1 then true else false end
                                                               as is_month_start,
        case when date_day = last_day(date_day) then true else false end
                                                               as is_month_end,
        case when dayofyear(date_day) = 1 then true else false end
                                                               as is_year_start,
        case when date_trunc('quarter', date_day) = date_day then true else false end
                                                               as is_quarter_start,

        -- ── Formatted strings for reporting ──────────────────────────────
        to_varchar(date_day, 'YYYY-MM-DD')                    as date_iso,
        to_varchar(date_day, 'YYYYMMDD')                      as date_key_int,
        to_varchar(date_day, 'DD-Mon-YYYY')                   as date_display,
        year(date_day) || '-' || lpad(month(date_day), 2, '0')
                                                               as year_month,
        year(date_day) || '-Q' || quarter(date_day)           as year_quarter,

        -- ── Fiscal year (April start) ─────────────────────────────────────
        {{ get_fiscal_year('date_day', 4) }}                   as fiscal_year,
        {{ get_fiscal_quarter('date_day', 4) }}                as fiscal_quarter,
        'FY' || {{ get_fiscal_year('date_day', 4) }}          as fiscal_year_name,
        'FY' || {{ get_fiscal_year('date_day', 4) }}
            || '-Q' || {{ get_fiscal_quarter('date_day', 4) }} as fiscal_year_quarter,

        -- ── Relative date flags ───────────────────────────────────────────
        case when date_day = current_date()   then true else false end  as is_today,
        case when date_day < current_date()   then true else false end  as is_past,
        case when date_day > current_date()   then true else false end  as is_future,

        datediff('day', current_date(), date_day)             as days_from_today

    from date_spine
)

select * from enriched
order by date_id