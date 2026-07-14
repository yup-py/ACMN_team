{{ config(
    materialized='table',
    schema='SILVER',
    tags=['silver', 'cleaned']
) }}

-- STEP 1 : REMOVE DUPLICATES
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY listing_id
               ORDER BY ingestion_timestamp DESC
           ) AS rn
    FROM {{ source('bronze', 'ODS_REALESTATE') }}
),

-- STEP 2 : STANDARDIZE VALUES & CONVERT BLANKS TO NULL
standardized AS (
    SELECT
        listing_id,

        CASE
            WHEN LOWER(TRIM(property_type))='apt' THEN 'apartment'
            ELSE NULLIF(LOWER(TRIM(property_type)), '')
        END AS property_type,

        NULLIF(INITCAP(TRIM(country)), '') AS country,
        NULLIF(INITCAP(TRIM(city)), '') AS city,
        NULLIF(INITCAP(TRIM(neighborhood)), '') AS neighborhood,

        surface_m2,
        num_rooms,
        num_bathrooms,
        floor,
        year_built,
        price,
        listing_date,

        NULLIF(LOWER(TRIM(condition)), '') AS condition,
        NULLIF(LOWER(TRIM(heating_type)), '') AS heating_type,

        CASE
            WHEN LOWER(TRIM(parking)) IN ('yes','true','1') THEN 'YES'
            WHEN LOWER(TRIM(parking)) IN ('no','false','0') THEN 'NO'
            ELSE NULL
        END AS parking,

        NULLIF(UPPER(TRIM(energy_rating)), '') AS energy_rating,
        
        ingestion_timestamp
    FROM ranked
    WHERE rn = 1
),

-- STEP 3 : CONVERT TYPES (TRY_CAST automatically turns invalid/blank strings to true NULLs)
converted AS (
    SELECT
        listing_id,
        property_type,
        country,
        city,
        neighborhood,

        TRY_CAST(surface_m2 as FLOAT) AS surface_m2,
        TRY_CAST(num_rooms as INT) AS num_rooms,
        TRY_CAST(num_bathrooms as INT) AS num_bathrooms,
        TRY_CAST(floor as INT) AS floor,
        TRY_CAST(year_built as INT) AS year_built,

        TRY_CAST(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(TRIM(price), '[A-Z]', ''),
                    ' ',
                    ''
                ),
                ',',
                ''
            ) as FLOAT
        ) AS price,
        
        COALESCE(
             TRY_CAST(TRIM(listing_date) as DATE),
             TRY_CAST(TRIM(listing_date) as TIMESTAMP)::DATE
        ) AS listing_date,

        condition,
        heating_type,
        parking,
        energy_rating,
        
        ingestion_timestamp
    FROM standardized
),

-- STEP 4 : CALCULATE MEDIANS
stats AS (
    SELECT
        MEDIAN(surface_m2) AS median_surface,
        MEDIAN(num_rooms) AS median_rooms,
        MEDIAN(num_bathrooms) AS median_bathrooms,
        MEDIAN(floor) AS median_floor,
        MEDIAN(year_built) AS median_year,
        MEDIAN(price) AS median_price
    FROM converted
),

-- STEP 5 : HANDLE MISSING VALUES (Smart hierarchical imputation using city groups)
cleaned AS (
    SELECT
        listing_id,

        COALESCE(
            property_type, 
            MODE(property_type) OVER (PARTITION BY city), 
            MODE(property_type) OVER (), 
            'unknown'
        ) AS property_type,
        
        COALESCE(
            city, 
            MODE(city) OVER (), 
            'UNKNOWN'
        ) AS city,

        COALESCE(
            country,
            MODE(country) OVER (PARTITION BY city),
            MODE(country) OVER (),
            'UNKNOWN'
        ) AS country,

        COALESCE(
            neighborhood,
            MODE(neighborhood) OVER (PARTITION BY city),
            'UNKNOWN'
        ) AS neighborhood,

        COALESCE(surface_m2, median_surface) AS surface_m2,
        COALESCE(num_rooms, median_rooms) AS num_rooms,
        COALESCE(num_bathrooms, median_bathrooms) AS num_bathrooms,
        COALESCE(floor, median_floor, 0) AS floor,
        COALESCE(year_built, median_year, 2000) AS year_built,
        COALESCE(price, median_price, 100000) AS price,
        COALESCE(listing_date, CURRENT_DATE()) AS listing_date,

        COALESCE(
            condition, 
            MODE(condition) OVER (PARTITION BY city), 
            MODE(condition) OVER (), 
            'unknown'
        ) AS condition,
        
        COALESCE(
            heating_type, 
            MODE(heating_type) OVER (PARTITION BY city), 
            MODE(heating_type) OVER (), 
            'unknown'
        ) AS heating_type,
        
        COALESCE(parking, 'NO') AS parking,
        
        COALESCE(
            energy_rating, 
            MODE(energy_rating) OVER (PARTITION BY city), 
            MODE(energy_rating) OVER (), 
            'UNKNOWN'
        ) AS energy_rating,
        
        ingestion_timestamp
    FROM converted c1
    CROSS JOIN stats
),

-- STEP 6 : REMOVE OUTLIERS
silver AS (
    SELECT
        listing_id,
        property_type,
        country,
        city,
        neighborhood,
        CAST(surface_m2 as INT) as surface_m2,
        CAST(num_rooms as INT) as num_rooms,
        CAST(num_bathrooms as INT) as num_bathrooms,
        CAST(floor as INT) as floor,
        CAST(year_built as INT) as year_built,
        CAST(price as FLOAT) as price,
        listing_date,
        condition,
        heating_type,
        parking,
        energy_rating,
        YEAR(listing_date) as listing_year,
        MONTH(listing_date) as listing_month,
        QUARTER(listing_date) as listing_quarter,
        ROUND(price / NULLIF(surface_m2, 0), 2) as price_per_m2,
        YEAR(CURRENT_DATE()) - year_built as property_age,
        CURRENT_DATE() - listing_date as days_on_market,
        ingestion_timestamp,
        CURRENT_TIMESTAMP() as processed_at
    FROM cleaned
    WHERE
        price > 0
        AND surface_m2 BETWEEN 20 AND 1000
        AND num_rooms BETWEEN 1 AND 10
        AND num_bathrooms BETWEEN 1 AND 5
        AND floor BETWEEN 0 AND 30
        AND year_built BETWEEN 1850 AND YEAR(CURRENT_DATE())
        AND listing_date <= CURRENT_DATE()
)

-- FINAL RESULT
SELECT * FROM silver