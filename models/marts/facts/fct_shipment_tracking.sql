-- models/marts/facts/fct_shipment_tracking.sql
-- High-volume GPS tracking event fact table.
-- One row per tracking event. Incrementally loaded by _snowpipe_loaded_at.

{{
    config(
        materialized        = 'incremental',
        unique_key          = 'surrogate_key',
        on_schema_change    = 'sync_all_columns',
        incremental_strategy = 'merge',
        cluster_by          = ['tracking_date', 'shipment_id']
    )
}}

with tracking as (
    select * from {{ ref('stg_shipment_tracking') }}
    -- Exclude records with critical DQ issues
    where dq_invalid_latitude   = false
      and dq_invalid_longitude  = false
      and dq_malformed_timestamp = false
),

dim_date as (
    select date_id, date_key_int from {{ ref('dim_date') }}
),

dim_vehicle as (
    select vehicle_id, vehicle_sk from {{ ref('dim_vehicle') }}
),

final as (
    select
        -- ── Surrogate key ─────────────────────────────────────────────────
        {{ generate_surrogate_key(['t.tracking_id']) }}         as surrogate_key,

        -- ── Natural keys ──────────────────────────────────────────────────
        t.tracking_id,
        t.shipment_id,
        t.vehicle_id,

        -- ── Dimension FKs ─────────────────────────────────────────────────
        dv.vehicle_sk,
        dd.date_key_int                                         as tracking_date_key,

        -- ── Date/time ────────────────────────────────────────────────────
        t.tracking_date,
        t.tracking_timestamp,

        -- ── Coordinates ───────────────────────────────────────────────────
        t.latitude,
        t.longitude,

        -- ── Status ───────────────────────────────────────────────────────
        t.shipment_status,

        -- ── DQ flags ─────────────────────────────────────────────────────
        t.dq_invalid_latitude,
        t.dq_invalid_longitude,
        t.dq_malformed_timestamp,

        -- ── Metadata ─────────────────────────────────────────────────────
        t._snowpipe_loaded_at,
        t._dbt_loaded_at

    from tracking t
    left join dim_vehicle dv on t.vehicle_id = dv.vehicle_id
    left join dim_date    dd on t.tracking_date = dd.date_id
)

select * from final

{% if is_incremental() %}
    where _snowpipe_loaded_at > coalesce(
        (select max(_snowpipe_loaded_at) from {{ this }}),
        '1900-01-01 00:00:00'::timestamp_ntz
    )
{% endif %}