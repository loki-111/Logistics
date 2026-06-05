-- models/intermediate/int_transport_partner_performance.sql
-- Rolling performance scorecard per transport partner.
-- Aggregates over all-time history and last-30-day window.

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'transport_partner_id',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge'
    )
}}

with daily_perf as (
    select * from {{ ref('int_delivery_performance') }}
),

partners as (
    select
        transport_partner_id,
        company_name,
        transport_mode,
        service_area,
        rating                                                 as source_rating,
        is_active
    from {{ ref('stg_transport_partners') }}
),

all_time as (
    select
        transport_partner_id,
        sum(total_shipments)                                   as total_shipments_alltime,
        sum(on_time_deliveries)                                as on_time_alltime,
        sum(late_deliveries)                                   as late_alltime,
        sum(failed_deliveries)                                 as failed_alltime,
        sum(total_weight_kg_delivered)                         as total_weight_alltime,
        avg(avg_actual_transit_hours)                          as avg_transit_hours_alltime,
        avg(on_time_rate)                                      as avg_on_time_rate_alltime,
        min(delivery_date)                                     as first_delivery_date,
        max(delivery_date)                                     as last_delivery_date
    from daily_perf
    group by transport_partner_id
),

last_30_days as (
    select
        transport_partner_id,
        sum(total_shipments)                                   as total_shipments_l30d,
        sum(on_time_deliveries)                                as on_time_l30d,
        sum(failed_deliveries)                                 as failed_l30d,
        avg(on_time_rate)                                      as avg_on_time_rate_l30d,
        avg(avg_actual_transit_hours)                          as avg_transit_hours_l30d
    from daily_perf
    where delivery_date >= dateadd('day', -30, current_date())
    group by transport_partner_id
),

joined as (
    select
        p.transport_partner_id,
        p.company_name,
        p.transport_mode,
        p.service_area,
        p.source_rating,
        p.is_active,

        -- All-time
        coalesce(a.total_shipments_alltime, 0)                 as total_shipments_alltime,
        coalesce(a.on_time_alltime, 0)                         as on_time_alltime,
        coalesce(a.late_alltime, 0)                            as late_alltime,
        coalesce(a.failed_alltime, 0)                          as failed_alltime,
        coalesce(a.total_weight_alltime, 0)                    as total_weight_alltime,
        a.avg_transit_hours_alltime,
        a.avg_on_time_rate_alltime,
        a.first_delivery_date,
        a.last_delivery_date,

        -- Last 30 days
        coalesce(l.total_shipments_l30d, 0)                    as total_shipments_l30d,
        coalesce(l.on_time_l30d, 0)                            as on_time_l30d,
        coalesce(l.failed_l30d, 0)                             as failed_l30d,
        l.avg_on_time_rate_l30d,
        l.avg_transit_hours_l30d,

        -- Computed score (weighted: 60% on-time rate, 40% inverse failure rate)
        round(
            (coalesce(a.avg_on_time_rate_alltime, 0) * 0.6)
            + ((1 - coalesce({{ safe_divide('a.failed_alltime', 'a.total_shipments_alltime') }}, 0)) * 0.4),
            4
        )                                                      as performance_score,

        current_timestamp()::timestamp_ntz                    as _dbt_updated_at

    from partners p
    left join all_time   a on p.transport_partner_id = a.transport_partner_id
    left join last_30_days l on p.transport_partner_id = l.transport_partner_id
)

select * from joined

{% if is_incremental() %}
    where transport_partner_id in (
        select distinct transport_partner_id
        from {{ ref('int_delivery_performance') }}
        where _dbt_updated_at > (select max(_dbt_updated_at) from {{ this }})
    )
{% endif %}