-- tests/singular/test_dq_rate_threshold.sql
-- Monitoring test: fails if the overall data quality error rate in
-- stg_shipment_requests exceeds 10% for any single DQ dimension.
-- This catches upstream pipeline degradation early.

with totals as (
    SELECT
        COUNT(*) AS total_records,

        SUM(CASE WHEN dq_invalid_date THEN 1 ELSE 0 END)
            AS invalid_date_count,

        SUM(CASE WHEN dq_invalid_priority THEN 1 ELSE 0 END)
            AS invalid_priority_count,

        SUM(CASE WHEN dq_invalid_weight THEN 1 ELSE 0 END)
            AS invalid_weight_count,

        SUM(CASE WHEN dq_invalid_manufacturer_id THEN 1 ELSE 0 END)
            AS invalid_manufacturer_id_count
    from {{ ref('stg_shipment_requests') }}
),

rates as (
    select
        total_records,
        round(invalid_date_count           / nullif(total_records, 0), 4) as invalid_date_rate,
        round(invalid_priority_count       / nullif(total_records, 0), 4) as invalid_priority_rate,
        round(invalid_weight_count         / nullif(total_records, 0), 4) as invalid_weight_rate,
        round(invalid_manufacturer_id_count / nullif(total_records, 0), 4) as invalid_manufacturer_id_rate
    from totals
)

-- Return rows where any rate exceeds 10% threshold — test fails if any rows returned
select *
from rates
where invalid_date_rate            > 0.10
   or invalid_priority_rate        > 0.10
   or invalid_weight_rate          > 0.10
   or invalid_manufacturer_id_rate > 0.10