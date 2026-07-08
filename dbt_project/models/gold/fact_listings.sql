{{ config(
    materialized='table',
    schema='GOLD',
    tags=['gold', 'fact']
) }}



SELECT
    listing_id AS listing_key,                                      
    HASH(country, city, neighborhood) AS location_key,               
    listing_id AS property_key,                                      
    TO_NUMBER(TO_CHAR(listing_date, 'YYYYMMDD')) AS time_key,         
    price,
    price_per_m2,
    surface_m2,
    days_on_market,
    CASE
        WHEN price < 100000 THEN 'BUDGET'
        WHEN price < 300000 THEN 'MID'
        WHEN price < 600000 THEN 'PREMIUM'
        ELSE 'LUXURY'
    END AS price_segment,
    CURRENT_TIMESTAMP() AS created_at

FROM {{ ref('stg_listings') }}
