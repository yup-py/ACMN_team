import os
import csv
import snowflake.connector
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, '.env'))

def validate_env():
    required = [
        'SNOWFLAKE_ACCOUNT', 'SNOWFLAKE_ADMIN_USER', 'SNOWFLAKE_ADMIN_PASSWORD',
        'SNOWFLAKE_USER', 'SNOWFLAKE_PASSWORD', 'SNOWFLAKE_WAREHOUSE',
        'SNOWFLAKE_DATABASE', 'SNOWFLAKE_SCHEMA_BRONZE'
    ]
    missing = [var for var in required if not os.getenv(var)]
    if missing:
        raise ValueError(f"Missing env vars: {missing}")
    print("✅ Environment validated")

def setup_snowflake():
    sql_file = os.path.join(BASE_DIR, 'snowflake', 'init_snowflake.sql')
    with open(sql_file, 'r') as f:
        sql = f.read()
    
    conn = snowflake.connector.connect(
        account=os.getenv('SNOWFLAKE_ACCOUNT'),
        user=os.getenv('SNOWFLAKE_ADMIN_USER'),
        password=os.getenv('SNOWFLAKE_ADMIN_PASSWORD'),
        role='ACCOUNTADMIN'
    )
    conn.execute_string(sql)
    conn.close()
    print("✅ Snowflake infrastructure ready")

def ingest_bronze():
    csv_file = os.path.join(BASE_DIR, 'data', 'real_estate_raw.csv')
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        headers = next(reader)
        rows = list(reader)
    
    print(f"📊 CSV: {len(headers)} columns, {len(rows)} rows")
    
    conn = snowflake.connector.connect(
        account=os.getenv('SNOWFLAKE_ACCOUNT'),
        user=os.getenv('SNOWFLAKE_USER'),
        password=os.getenv('SNOWFLAKE_PASSWORD'),
        warehouse=os.getenv('SNOWFLAKE_WAREHOUSE'),
        database=os.getenv('SNOWFLAKE_DATABASE'),
        schema=os.getenv('SNOWFLAKE_SCHEMA_BRONZE')
    )
    cursor = conn.cursor()
    
    clean_headers = [f'"{h.strip().upper()}" VARCHAR' for h in headers]
    clean_headers.append('"INGESTION_TIMESTAMP" TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()')
    create_sql = f'CREATE TABLE IF NOT EXISTS ODS_REALESTATE ({", ".join(clean_headers)})'
    
    cursor.execute(create_sql)
    cursor.execute('TRUNCATE TABLE ODS_REALESTATE')
    
    col_names = ", ".join([f'"{h.strip().upper()}"' for h in headers])
    placeholders = ", ".join(["%s" for _ in headers])
    insert_sql = f"INSERT INTO ODS_REALESTATE ({col_names}) VALUES ({placeholders})"
    
    sanitized_rows = []
    expected_count = len(headers)
    
    for row in rows:
        if not row:
            continue
        if len(row) > expected_count:
            sanitized_rows.append(tuple(row[:expected_count]))
        elif len(row) < expected_count:
            sanitized_rows.append(tuple(row + [None] * (expected_count - len(row))))
        else:
            sanitized_rows.append(tuple(row))
            
    if sanitized_rows:
        cursor.executemany(insert_sql, sanitized_rows)
        conn.commit()
    
    cursor.execute("SELECT COUNT(*) FROM ODS_REALESTATE")
    count = cursor.fetchone()[0]
    
    cursor.close()
    conn.close()
    
    print(f"✅ Ingested {count} rows to Bronze")

if __name__ == "__main__":
    try:
        validate_env()
        setup_snowflake()
        ingest_bronze()
        print("✅ Bronze complete")
    except Exception as e:
        print(f"❌ Error: {e}")
        raise