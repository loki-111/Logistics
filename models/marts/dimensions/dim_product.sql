-- models/marts/dimensions/dim_product.sql
-- Product dimension enriched with manufacturer name for self-service analytics.

{{
    config(
        materialized    = 'table',
        cluster_by      = ['category']
    )
}}

with products as (
    select * from {{ ref('stg_products') }}
),

manufacturers as (
    select manufacturer_id, manufacturer_name, manufacturer_type
    from {{ ref('stg_manufacturers') }}
),

final as (
    select
        -- Surrogate key
        p.product_sk,

        -- Natural key
        p.product_id,

        -- Attributes
        p.product_name,
        p.category,
        p.weight_kg,
        p.unit_price,
        p.is_fragile,
        p.created_date,

        -- Manufacturer context (denormalized)
        p.manufacturer_id,
        m.manufacturer_name,
        m.manufacturer_type,

        -- Weight tier
        case
            when p.weight_kg >= 1000 then 'HEAVY'
            when p.weight_kg >= 100  then 'MEDIUM'
            when p.weight_kg >= 1    then 'LIGHT'
            when p.weight_kg > 0     then 'MICRO'
            else 'UNKNOWN'
        end                                                    as weight_tier,

        -- Price tier
        case
            when p.unit_price >= 10000 then 'PREMIUM'
            when p.unit_price >= 1000  then 'MID_RANGE'
            when p.unit_price >= 100   then 'ECONOMY'
            when p.unit_price > 0      then 'BUDGET'
            else 'UNKNOWN'
        end                                                    as price_tier,

        -- DQ flags
        p.dq_invalid_weight,
        p.dq_null_price,

        -- Metadata
        current_timestamp()::timestamp_ntz                    as dbt_updated_at

    from products p
    left join manufacturers m on p.manufacturer_id = m.manufacturer_id
)

select * from final