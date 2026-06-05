-- snapshots/snapshot_transport_partners.sql
-- SCD Type 2 snapshot tracking changes to transport partner attributes.
-- Triggers on: is_active, rating, service_area, transport_mode changes.
-- Strategy: check — hash of monitored columns.

{% snapshot snapshot_transport_partners %}

{{config(target_schema   = 'SNAPSHOTS',
        target_database = 'LOGISTIC',
        unique_key      = 'transport_partner_id',
        strategy        = 'check',
        check_cols      = [
            'is_active',
            'source_rating',
            'service_area',
            'transport_mode',
            'company_name'
        ],
        invalidate_hard_deletes = true
    )
}}

select
    transport_partner_id,
    company_name,
    transport_mode,
    service_area,
    source_rating,
    is_active,
    performance_score,
    performance_tier,
    avg_on_time_rate_alltime,

    current_timestamp()::timestamp_ntz                        as _snapshot_captured_at

from {{ ref('dim_transport_partner') }}

{% endsnapshot %}