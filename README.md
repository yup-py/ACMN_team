
# Real Estate Data Pipeline

Data pipeline for real estate analytics using Snowflake, dbt, and Apache Airflow.

---

## 🎯 What Does This Do?

Takes raw real estate CSV data, cleans it, organizes it into a data warehouse, and makes it ready for analysis.

**Flow:** Raw Data → Bronze (Raw) → Silver (Cleaned) → Gold (Organized) → Ready for Power BI

---

## 🚀 Quick Start

### 1. Setup Environment

Create `.env` file in project root:

```
POSTGRES_USER=airflow
POSTGRES_PASSWORD=airflow
POSTGRES_DB=airflow

AIRFLOW_USER=airflow
AIRFLOW_PASSWORD=airflow
AIRFLOW__CORE__FERNET_KEY=FB1tb4ub9_43uA7_909K60A5N0_8b1=

SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_DATABASE=REALESTATE_DB
SNOWFLAKE_SCHEMA=BRONZE
```

### 2. Start Docker

```bash
docker-compose down -v
docker-compose up -d
```

Wait 60-90 seconds.

### 3. Open Airflow

Visit: `http://localhost:8080`

Login: `airflow / airflow`

### 4. Run Pipeline

- Find "real_estate_master_pipeline"
- Click play button
- Wait for all tasks to turn green

### 5. Check Data in Snowflake

```sql
SELECT COUNT(*) FROM REALESTATE_DB.BRONZE.ODS_REALESTATE;
SELECT COUNT(*) FROM REALESTATE_DB.SILVER.STG_LISTINGS;
SELECT COUNT(*) FROM REALESTATE_DB.GOLD.FACT_LISTINGS;
```

---

## 📁 Project Structure

```
real-estate-pipeline/
├── dags/                          # Airflow workflows
│   └── real_estate_master_dag.py
├── bronze/                        # Raw data loading
│   └── load_csv_to_snowflake.py
├── dbt_project/                   # Data transformations
│   ├── models/
│   │   ├── silver/                # Cleaning layer
│   │   └── gold/                  # Analytics layer
│   └── profiles.yml               # Snowflake connection
├── data/                          # CSV files
│   └── real_estate_raw.csv
├── docker-compose.yml             # Docker setup
├── .env                           # Credentials (local only)
└── README.md
```

---

## 📊 How It Works

### Bronze Layer

- Raw CSV data loaded as-is
- Removes exact duplicates
- Adds timestamp when loaded

### Silver Layer

- Cleans data (fixes typos, formats)
- Fills missing values smartly (average, most common value)
- Converts data types (text → numbers, etc.)
- Removes outliers
- Creates derived columns (price per m², property age)

### Gold Layer

- Organizes into star schema (fact + dimensions)
- Optimized for analytics and dashboards
- Ready for Power BI

---

## 🔄 Pipeline Tasks (in Airflow)

1. **start_pipeline** - Initialize
2. **bronze_ingestion** - Load CSV
3. **run_dbt_silver** - Clean data
4. **run_dbt_gold** - Create analytics tables
5. **run_dbt_tests** - Validate data quality
6. **pipeline_complete** - Mark done

Tasks run in order. Each waits for previous to complete.

---

## 🛠️ Common Commands

### Run dbt Transformations

```bash
cd dbt_project

# Clean data (silver)
dbt run --select silver

# Create analytics tables (gold)
dbt run --select gold

# Run data quality tests
dbt test
```

### Monitor Pipeline

```bash
# View logs
docker-compose logs airflow-scheduler

# Restart scheduler if stuck
docker-compose restart airflow-scheduler
```

### Stop Everything

```bash
docker-compose down
```

---

## ❌ Troubleshooting

**DAG not showing in Airflow?**

- Restart scheduler: `docker-compose restart airflow-scheduler`
- Wait 30 seconds, refresh browser

**Snowflake connection failed?**

- Check `.env` has correct credentials
- Verify account format (not full URL)

**No data in tables?**

- Check Bronze ingestion task logs in Airflow UI
- Verify CSV file exists in `data/` folder

**dbt tests failing?**

- Check what was cleaned in Silver layer
- Review dbt logs: `cd dbt_project && dbt test --debug`

---

## 📝 File Locations

| What               | Where                          |
| ------------------ | ------------------------------ |
| Credentials        | `.env` (never commit)        |
| Workflows          | `dags/`                      |
| Data cleanup logic | `dbt_project/models/silver/` |
| Analytics tables   | `dbt_project/models/gold/`   |
| Raw data           | `data/`                      |
| Logs               | `logs/`                      |

---

## 🔒 Security Note

The `.env` file contains passwords and is excluded from Git (in `.gitignore`). Each team member keeps their own local `.env` copy.

Never commit `.env` to version control.

---

## 📊 Sample Queries

After pipeline completes:

```sql
-- Count listings by country
SELECT country, COUNT(*) 
FROM REALESTATE_DB.GOLD.FACT_LISTINGS
GROUP BY country
ORDER BY COUNT(*) DESC;

-- Average price by property type
SELECT property_type, AVG(price)
FROM REALESTATE_DB.GOLD.FACT_LISTINGS
GROUP BY property_type;
```

---

## 👥 Team Roles

- **Bronze**: CSV loading, Snowflake setup
- **Silver**: Data cleaning, dbt models
- **Gold**: Analytics tables, schema design
- **Airflow**: Orchestration, DAG management

---

## 📞 Support

Check troubleshooting section above. If issue persists, check:

1. Airflow logs in UI
2. dbt logs in terminal
3. Snowflake query editor for table existence

---

**Version:** 1.0
**Status:** Production Ready
**Last Updated:** July 2026
