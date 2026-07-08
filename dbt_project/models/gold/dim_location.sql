{{ config(
    materialized='table',
    schema='GOLD',
    tags=['gold', 'dimension']
) }}


WITH distinct_locations AS (
    SELECT DISTINCT
        country,
        city,
        neighborhood
    FROM {{ ref('stg_listings') }}
),

city_stats AS (
    
    SELECT
        country,
        city,
        COUNT(*) AS listing_count_city,
        ROUND(AVG(price), 2) AS avg_price_city,
        ROUND(AVG(surface_m2), 2) AS avg_surface_city
    FROM {{ ref('stg_listings') }}
    GROUP BY country, city
),

neighborhood_stats AS (
    SELECT
        country,
        city,
        neighborhood,
        COUNT(*) AS listing_count_neighborhood
    FROM {{ ref('stg_listings') }}
    GROUP BY country, city, neighborhood
)

SELECT
    HASH(dl.country, dl.city, dl.neighborhood) AS location_key,
    dl.country,
    dl.city,
    dl.neighborhood,
    ns.listing_count_neighborhood,
    cs.listing_count_city,
    cs.avg_price_city,
    cs.avg_surface_city,
    CURRENT_TIMESTAMP() AS created_at
FROM distinct_locations dl
LEFT JOIN city_stats cs
    ON dl.country = cs.country AND dl.city = cs.city
LEFT JOIN neighborhood_stats ns
    ON dl.country = ns.country AND dl.city = ns.city AND dl.neighborhood = ns.neighborhood
