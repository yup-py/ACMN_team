FROM apache/airflow:2.9.2-python3.11

COPY requirements.txt /requirements.txt

USER root
RUN mkdir -p /opt/airflow/logs && chmod -R 777 /opt/airflow/logs

USER airflow
RUN pip install --no-cache-dir -r /requirements.txt

RUN python -m venv /home/airflow/dbt_venv && \
    /home/airflow/dbt_venv/bin/pip install --no-cache-dir --upgrade pip && \
    /home/airflow/dbt_venv/bin/pip install --no-cache-dir dbt-snowflake==1.8.3
