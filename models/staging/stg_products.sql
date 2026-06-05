-- models/staging/stg_products.sql
-- Cleans and casts raw product catalog data.
-- Handles: negative weights, null prices, text in numeric fields.

with source as (
    select * from {{ source('raw', 'raw_products') }}
),

cleaned as (
    select
        -- Keys
        trim(product_id)                                        as product_id,
        trim(manufacturer_id)                                   as manufacturer_id,

        -- Descriptors
        initcap(trim(product_name))                             as product_name,
        upper(trim(category))                                   as category,

        -- Weight: must be positive numeric; nullify negatives/text
        case
            when try_to_number(trim(weight_kg), 18, 4) > 0
                then try_to_number(trim(weight_kg), 18, 4)
            else null
        end                                                     as weight_kg,

        -- Price: must be positive numeric
        case
            when try_to_number(trim(unit_price), 18, 4) > 0
                then try_to_number(trim(unit_price), 18, 4)
            else null
        end                                                     as unit_price,

        -- Fragile flag
        {{ boolean_normalization('fragile_flag') }}             as is_fragile,

        -- Date
        {{ safe_to_date('created_date') }}                      as created_date,

        -- Metadata
        current_timestamp()::timestamp_ntz                     as _dbt_loaded_at,

        -- Surrogate key
        {{ generate_surrogate_key(['product_id']) }}            as product_sk

    from source
    where trim(product_id) is not null
      and trim(product_id) != ''
),

with_dq_flags as (
    select
        *,
        case when weight_kg is null  then true else false end   as dq_invalid_weight,
        case when unit_price is null then true else false end   as dq_null_price
    from cleaned
)

select * from with_dq_flags