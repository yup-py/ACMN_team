{{ config(
    materialized='table',
    schema='GOLD',
    tags=['gold', 'dimension']
) }}



SELECT DISTINCT
    TO_NUMBER(TO_CHAR(listing_date, 'YYYYMMDD')) AS time_key,
    listing_date,
    listing_year,
    listing_quarter,
    listing_month,
    MONTHNAME(listing_date) AS month_name,
    DAY(listing_date) AS day_of_month,
    DAYOFWEEK(listing_date) AS day_of_week,
    DAYNAME(listing_date) AS day_name,
    CASE WHEN DAYOFWEEK(listing_date) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend,
    CURRENT_TIMESTAMP() AS created_at

FROM {{ ref('stg_listings') }}
WHERE listing_date IS NOT NULL
ORDER BY listing_date
