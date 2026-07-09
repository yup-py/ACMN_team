from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'ACMN',
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

with DAG(
    'real_estate_master_pipeline',
    default_args=default_args,
    description='ACMN Real Estate Pipeline',
    schedule_interval=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=['acmn', 'real-estate'],
) as dag:
    start = BashOperator(
        task_id='start_pipeline',
        bash_command='echo "Pipeline started"',
    )
    bronze = BashOperator(
        task_id='bronze_ingestion',
        bash_command='python /opt/airflow/bronze/load_csv_to_snowflake.py',
    )
    silver = BashOperator(
        task_id='run_dbt_silver',
        bash_command='cd /opt/airflow/dbt_project && dbt run --select silver --profiles-dir .',
    )
    gold = BashOperator(
        task_id='run_dbt_gold',
        bash_command='cd /opt/airflow/dbt_project && dbt run --select gold --profiles-dir .',
    )
    tests = BashOperator(
        task_id='run_dbt_tests',
        bash_command='cd /opt/airflow/dbt_project && dbt test --profiles-dir . || true',
    )
    end = BashOperator(
        task_id='pipeline_complete',
        bash_command='echo "Pipeline complete"',
    )
    start >> bronze >> silver >> gold >> tests >> end