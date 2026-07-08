{{ config(
    materialized='table',
    schema='GOLD',
    tags=['gold', 'dimension']
) }}


SELECT
    listing_id AS property_key,
    property_type,
    surface_m2,
    num_rooms,
    num_bathrooms,
    floor,
    year_built,
    property_age,
    condition,
    heating_type,
    parking,
    energy_rating,
    CURRENT_TIMESTAMP() AS created_at

FROM {{ ref('stg_listings') }}
