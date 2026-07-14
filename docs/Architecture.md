
# Architecture

## What is Medallion Architecture?

Three-layer approach to organize data:

```
GOLD LAYER (Analytics)
    ↑
SILVER LAYER (Cleaned)
    ↑
BRONZE LAYER (Raw)
```

**Each layer serves a purpose:**

- **BRONZE** - Raw data, exactly as received. Deduplicated. Immutable.
- **SILVER** - Cleaned data. Fixes missing values, converts types, removes errors.
- **GOLD** - Organized for analytics. Star schema with dimensions and facts.

---

## Why Three Layers?

| Layer  | Why                                              |
| ------ | ------------------------------------------------ |
| Bronze | Keep raw copy for debugging and traceability     |
| Silver | One place for all cleaning logic, no duplication |
| Gold   | Organized for analytics tools and dashboards     |

**Benefits:**

- Easy to debug (go back to raw data)
- Changes isolated to each layer
- Reusable (Silver feeds multiple uses)
- Testable at each stage

---

## Bronze → Silver → Gold

### Bronze Layer

**Table:** `ODS_REALESTATE`

Raw CSV loaded directly:

- No changes to data
- Deduplicates (removes exact copies)
- Adds timestamp

### Silver Layer

**Table:** `STG_LISTINGS`

Cleans the data:

1. **Null Handling** - Fill empty values with median (numbers) or most common value (text)
2. **Type Conversion** - Convert price text to numbers, dates to date format
3. **Text Cleaning** - Fix casing, remove extra spaces, standardize values
4. **Outlier Detection** - Flag unrealistic values (price = 0, surface = negative)
5. **Derived Columns:**
   - `price_per_m2` = price / surface
   - `property_age` = current year - year_built
   - `days_on_market` = days since listing

### Gold Layer

**Tables:** Organized into Star Schema

- **Dimensions** (Lookups):

  - `DIM_PROPERTY` - What is the property? (type, condition, features)
  - `DIM_LOCATION` - Where is it? (country, city, neighborhood)
  - `DIM_TIME` - When? (date, year, month)
- **Fact Table** (Measurements):

  - `FACT_LISTINGS` - The actual listings with metrics (price, surface, etc.)

**Why Star Schema?**

- Simple joins for analysts
- Fast for dashboards (Power BI, Tableau)
- Clear structure (facts + dimensions)

---

## Data Quality Handling

### Problem → Solution

| Problem                    | Solution                             |
| -------------------------- | ------------------------------------ |
| Missing surface_m2         | Use median surface of all properties |
| Missing heating_type       | Use most common type                 |
| Price has currency symbol  | Remove "$", convert to number        |
| Dates in different formats | Convert all to YYYY-MM-DD            |
| Duplicates by listing_id   | Keep first, remove copies            |
| Property age = negative    | Flag and investigate                 |

---

## Technology Choices

### Snowflake (Data Warehouse)

- Stores all three layers
- SQL queries
- Scales easily

### dbt (Transformations)

- Silver model cleans Bronze data
- Gold models organize Silver data
- SQL-based, version controlled
- Built-in testing

### Airflow (Orchestration)

- Runs pipeline in order
- Handles errors and retries
- Monitors execution
- Logs everything

---

## Pipeline Flow

```
1. CSV File
   ↓
2. Airflow starts
   ↓
3. Bronze: Load CSV to Snowflake
   ↓
4. Silver: Clean data (dbt)
   ↓
5. Gold: Create analytics tables (dbt)
   ↓
6. Tests: Validate data quality (dbt)
   ↓
7. Done: Ready for Power BI
```

Each step waits for previous to finish.

---

## Key Design Decisions

### Star Schema

- Separate dimension and fact tables
- Why? BI tools love this structure, fast queries, easy to understand
- Alternative: Snowflake schema (more normalized but slower)

### MODE + MEDIAN for Nulls

- Numbers → use MEDIAN (middle value)
- Text → use MODE (most frequent value)
- Why? Keeps data distribution realistic, not arbitrary

---

## Data Lineage

Track where each column comes from:

```
CSV.price → BRONZE.price → SILVER.price → GOLD.FACT_LISTINGS.price
                                              ├── Used in: price_per_m2
                                              └── Used in: aggregations
```

If analyst questions a number, trace it back to source.

---

## Performance Notes

- Bronze load: ~2 minutes for 1000+ rows
- Silver cleaning: ~1 minute
- Gold schema: ~1 minute
- Total: ~5 minutes

For larger data, use:

- Incremental models (only new data)
- Clustering on fact tables
- Larger Snowflake warehouse

---

## Testing Strategy

dbt runs tests after each layer:

1. **Uniqueness** - listing_id appears once
2. **Not Null** - Important columns filled
3. **Relationships** - Foreign keys exist
4. **Custom** - Price > 0, surface > 0

If tests fail, pipeline stops. Prevents bad data reaching analysts.

---

## Monitoring & Debugging

**Check Airflow UI:**

- See which task failed
- View logs for error message
- Retry with fix

**Check dbt logs:**

```bash
cd dbt_project
dbt run --debug
```

**Query directly:**

```sql
SELECT * FROM BRONZE.ODS_REALESTATE LIMIT 10;
SELECT * FROM SILVER.STG_LISTINGS LIMIT 10;
```

---

## Security & Governance

- Snowflake credentials in `.env` (not in Git)
- Each layer has clear ownership
- dbt tracks all transformations (version control)
- Tests prevent bad data from reaching users

---

## Future Improvements

1. **Incremental loads** - Only process new data daily
2. **More dimensions** - Add postal codes, geo coordinates
3. **SCD handling** - Track how properties change over time
4. **Data catalog** - Document all columns
5. **Alerts** - Notify on quality issues

---

**Last Updated:** July 2026
**Owner:** ACMN Data Team
