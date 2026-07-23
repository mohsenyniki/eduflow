from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator
from datetime import datetime
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator


@dag(
    schedule=None,
    start_date=datetime(2026, 7, 11),
    catchup=False,
    tags=["spark", "curated"]
)
def s3_raw_to_s3_curated():

    transform = SparkSubmitOperator(
        task_id="run_spark_transformation",
        conn_id="spark_default",
        application="/opt/spark/jobs/transform_raw_to_curated.py",
        packages="org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262",
        conf={
            "spark.hadoop.fs.s3a.endpoint": "http://localstack:4566",
            "spark.hadoop.fs.s3a.access.key": "test",
            "spark.hadoop.fs.s3a.secret.key": "test",
            "spark.hadoop.fs.s3a.path.style.access": "true",
            "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
            "spark.hadoop.fs.s3a.aws.credentials.provider": "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider"
        }
    )

    trigger_warehouse = TriggerDagRunOperator(
            task_id="trigger_warehouse_load",
            trigger_dag_id="s3_curated_to_warehouse",
            wait_for_completion=False
    )

    transform >> trigger_warehouse

s3_raw_to_s3_curated_dag = s3_raw_to_s3_curated()