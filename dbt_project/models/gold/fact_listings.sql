{{ config(
    materialized='table',
    schema='GOLD',
    tags=['gold', 'fact']
) }}

SELECT
    listing_id,
    country,
    city,
    neighborhood,
    property_type,
    listing_date,
    listing_year,
    listing_month,
    listing_quarter,
    price,
    price_per_m2,
    surface_m2,
    num_rooms,
    num_bathrooms,
    condition,
    energy_rating,
    parking,
    days_on_market,
    CASE 
        WHEN price < 100000 THEN 'BUDGET'
        WHEN price < 300000 THEN 'MID'
        WHEN price < 600000 THEN 'PREMIUM'
        ELSE 'LUXURY' 
    END as price_segment,
    CURRENT_TIMESTAMP() as created_at

FROM {{ ref('stg_listings') }}
