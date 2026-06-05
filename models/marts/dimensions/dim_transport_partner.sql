-- models/marts/dimensions/dim_transport_partner.sql
-- Transport partner dimension enriched with performance scorecard.
-- Note: SCD Type 2 history lives in the snapshot; this dim reflects current state.

{{
    config(
        materialized    = 'table',
        cluster_by      = ['transport_mode', 'is_active']
    )
}}

with perf as (
    select * from {{ ref('int_transport_partner_performance') }}
),

final as (
    select
        -- Surrogate key
        {{ generate_surrogate_key(['p.transport_partner_id']) }}  as transport_partner_sk,

        -- Natural key
        p.transport_partner_id,

        -- Attributes
        p.company_name,
        p.transport_mode,
        p.service_area,
        p.source_rating,
        p.is_active,

        -- Performance scorecard
        p.total_shipments_alltime,
        p.on_time_alltime,
        p.late_alltime,
        p.failed_alltime,
        p.total_weight_alltime,
        p.avg_transit_hours_alltime,
        p.avg_on_time_rate_alltime,
        p.first_delivery_date,
        p.last_delivery_date,

        -- Last 30 days
        p.total_shipments_l30d,
        p.on_time_l30d,
        p.failed_l30d,
        p.avg_on_time_rate_l30d,
        p.avg_transit_hours_l30d,

        -- Computed score
        p.performance_score,

        -- Tier classification based on score
        case
            when p.performance_score >= 0.9 then 'PLATINUM'
            when p.performance_score >= 0.75 then 'GOLD'
            when p.performance_score >= 0.6 then 'SILVER'
            else 'BRONZE'
        end                                                    as performance_tier,

        -- Metadata
        current_timestamp()::timestamp_ntz                    as dbt_updated_at

    from perf p
)

select * from final