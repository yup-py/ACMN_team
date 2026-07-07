{{ config(
    materialized='table',
    schema='GOLD',
    tags=['gold', 'dimension']
) }}

SELECT DISTINCT
    listing_date,
    listing_year,
    listing_month,
    listing_quarter,
    CURRENT_TIMESTAMP() as created_at

FROM {{ ref('stg_listings') }}
WHERE listing_date IS NOT NULL
ORDER BY listing_date
