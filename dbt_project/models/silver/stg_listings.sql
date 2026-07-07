{{ config(
    materialized='table',
    schema='silver',
    tags=['silver', 'cleaned']
) }}

with source as (
    select * from {{ source('bronze', 'ODS_REALESTATE') }}
),

text_clean as (
    select
        try_cast(listing_id as int) as listing_id,
        
        -- standardization idea: map 'apt' to 'apartment' and ensure lowercase
        case 
            when lower(trim(property_type)) = 'apt' then 'apartment'
            else lower(nullif(trim(property_type), ''))
        end as property_type,
        
        lower(nullif(trim(country), '')) as country,
        lower(nullif(trim(city), '')) as city,
        lower(nullif(trim(neighborhood), '')) as neighborhood,
        
        try_cast(surface_m2 as float) as surface_m2,
        try_cast(num_rooms as int) as num_rooms,
        try_cast(num_bathrooms as int) as num_bathrooms,
        try_cast(floor as int) as floor,
        try_cast(year_built as int) as year_built,
        
        -- conversion idea: clear currencies/spaces/commas before casting
        try_cast(regexp_replace(replace(replace(replace(lower(trim(price)), 'eur', ''), ' ', ''), ',', ''), '[^0-9.]', '') as float) as price,
        
        -- date parse idea: look through multiple string date formats safely
        coalesce(
            try_to_date(trim(listing_date), 'yyyy-mm-dd'),
            try_to_date(trim(listing_date), 'dd/mm/yyyy'),
            try_to_date(trim(listing_date), 'mm/dd/yyyy'),
            try_to_date(trim(listing_date), 'yyyy/mm/dd'),
            try_to_date(trim(listing_date), 'dd-mm-yyyy'),
            try_to_date(trim(listing_date), 'mm-dd-yyyy')
        ) as listing_date,
        
        case when lower(trim(condition)) in ('true', '1', 'yes') then 1 else 0 end as condition,
        lower(nullif(trim(heating_type), '')) as heating_type,
        case when lower(trim(parking)) in ('true', '1', 'yes') then 1 else 0 end as parking,
        lower(nullif(trim(energy_rating), '')) as energy_rating,
        ingestion_timestamp,
        row_number() over (partition by listing_id order by ingestion_timestamp desc) as rn
    from source
),

deduplicated as (
    select * from text_clean where rn = 1
),

-- calculating country mode via separate window partitions to bypass snowflake limits
city_country_mode as (
    select 
        city,
        country,
        row_number() over (partition by city order by count(*) desc) as rn
    from deduplicated
    where country is not null
    group by city, country
),

-- calculating neighborhood mode via separate window partitions to bypass snowflake limits
city_neighborhood_mode as (
    select 
        city,
        neighborhood,
        row_number() over (partition by city order by count(*) desc) as rn
    from deduplicated
    where neighborhood is not null
    group by city, neighborhood
),

-- calculating floor mode via separate window partitions to bypass snowflake limits
prop_floor_mode as (
    select 
        property_type,
        neighborhood,
        floor,
        row_number() over (partition by property_type, neighborhood order by count(*) desc) as rn
    from deduplicated
    where floor is not null
    group by property_type, neighborhood, floor
),

fill_nulls as (
    select
        d.listing_id,
        coalesce(d.property_type, 'unknown') as property_type,
        coalesce(d.country, cc.country, 'unknown') as country,
        coalesce(d.city, 'unknown') as city,
        coalesce(d.neighborhood, cn.neighborhood, 'unknown') as neighborhood,
        coalesce(d.surface_m2, median(d.surface_m2) over (partition by d.property_type, d.neighborhood), 100.0) as surface_m2,
        coalesce(d.num_rooms, median(d.num_rooms) over (partition by d.property_type, d.neighborhood), 2) as num_rooms,
        coalesce(d.num_bathrooms, median(d.num_bathrooms) over (partition by d.property_type, d.neighborhood), 1) as num_bathrooms,
        coalesce(d.floor, pf.floor, 0) as floor,
        coalesce(d.year_built, median(d.year_built) over (partition by d.neighborhood), 2000) as year_built,
        coalesce(d.price, median(d.price) over (partition by d.property_type, d.city), 0) as price,
        coalesce(d.listing_date, current_date()) as listing_date,
        coalesce(d.condition, 0) as condition,
        coalesce(d.heating_type, 'unknown') as heating_type,
        coalesce(d.parking, 0) as parking,
        coalesce(d.energy_rating, 'unknown') as energy_rating,
        
        -- derived metrics and calendar groupings
        year(d.listing_date) as listing_year,
        month(d.listing_date) as listing_month,
        quarter(d.listing_date) as listing_quarter,
        round(d.price / nullif(d.surface_m2, 0), 2) as price_per_m2,
        year(current_date()) - d.year_built as property_age,
        current_date() - d.listing_date as days_on_market,
        d.ingestion_timestamp,
        current_timestamp() as processed_at
    from deduplicated d
    left join city_country_mode cc on d.city = cc.city and cc.rn = 1
    left join city_neighborhood_mode cn on d.city = cn.city and cn.rn = 1
    left join prop_floor_mode pf on d.property_type = pf.property_type and d.neighborhood = pf.neighborhood and pf.rn = 1
),

-- outlier removal idea: filter logical real estate thresholds
remove_outliers as (
    select *
    from fill_nulls
    where
        price > 0
        and surface_m2 between 20 and 608
        and num_rooms between 1 and 8
        and num_bathrooms between 1 and 4
        and floor between 0 and 20
        and year_built between 1950 and year(current_date())
        and listing_date <= current_date()
)

select * from remove_outliers