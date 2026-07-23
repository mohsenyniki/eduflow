# this dag loads curated parquet files from s3 into postgresql staging tables
# then runs dbt to build the star schema warehouse tables
# triggered by s3_raw_to_s3_curated after spark transformation completes

from airflow.decorators import dag, task
from datetime import datetime

@dag(
    # no schedule — triggered by s3_raw_to_s3_curated after spark completes
    schedule=None,
    start_date=datetime(2026, 7, 11),
    catchup=False,
    tags=["dbt", "warehouse"]
)
def s3_curated_to_warehouse():

    @task
    def load_staging():
        """
        reads curated parquet files from localstack s3 and loads them
        into postgresql staging tables (stg_application_submitted, etc.)
        runs the load_curated_to_postgres.py script mounted at /opt/airflow/scripts
        """
        import subprocess

        result = subprocess.run(
            ["python3", "/opt/airflow/scripts/load_curated_to_postgres.py"],
            capture_output=True,
            text=True
        )

        print(result.stdout)

        if result.returncode != 0:
            raise Exception(f"Staging load failed: {result.stderr}")

    @task
    def run_dbt():
        """
        runs dbt models to build the star schema tables in postgresql:
        - dim_students      (one row per student with biographical info)
        - dim_programs      (one row per unique program)
        - dim_time          (one row per unique date with academic term info)
        - fact_student_events (all events from all 8 event types combined)
        """
        import subprocess

        result = subprocess.run(
            [
                "dbt", "run",
                "--project-dir", "/opt/airflow/dbt",
                "--profiles-dir", "/opt/airflow/dbt"
            ],
            capture_output=True,
            text=True
        )

        print(result.stdout)

        if result.returncode != 0:
            raise Exception(f"dbt run failed: {result.stderr}")

    # load staging first, then build the star schema from it
    load_staging() >> run_dbt()

s3_curated_to_warehouse_dag = s3_curated_to_warehouse()