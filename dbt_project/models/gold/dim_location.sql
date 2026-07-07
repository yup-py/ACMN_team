{{ config(
    materialized='table',
    schema='GOLD',
    tags=['gold', 'dimension']
) }}

SELECT DISTINCT
    country,
    city,
    neighborhood,
    COUNT(*) OVER (PARTITION BY country, city, neighborhood) as listing_count,
    ROUND(AVG(price) OVER (PARTITION BY country, city), 2) as avg_price_city,
    ROUND(AVG(surface_m2) OVER (PARTITION BY country, city), 2) as avg_surface_city,
    CURRENT_TIMESTAMP() as created_at

FROM {{ ref('stg_listings') }}
