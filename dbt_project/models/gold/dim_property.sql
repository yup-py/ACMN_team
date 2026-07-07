{{ config(
    materialized='table',
    schema='GOLD',
    tags=['gold', 'dimension']
) }}

SELECT
    listing_id,
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
    CURRENT_TIMESTAMP() as created_at

FROM {{ ref('stg_listings') }}
