import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from pyspark.sql.types import MapType, StringType
from pyspark.sql.functions import col, from_json, schema_of_json
from pyspark.sql.types import StructType, StructField, StringType, TimestampType
import json

def create_spark_session():
    return (
        SparkSession.builder
        .appName("EduFlow: Raw to Curated")
        .master("spark://spark-master:7077")
        .config("spark.hadoop.fs.s3a.endpoint", "http://localstack:4566")
        .config("spark.hadoop.fs.s3a.access.key", "test")
        .config("spark.hadoop.fs.s3a.secret.key", "test")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .getOrCreate()
    )

def transform_event_type(spark, event_type, raw_path, curated_path):
    
    input_path = f"s3a://eduflow-raw/{event_type}/"
    output_path = f"s3a://eduflow-curated/{event_type}/"
    
    # read raw parquet files
    df = spark.read.parquet(input_path)
    
    # deduplicate by event_id
    df = df.dropDuplicates(["event_id"])
    
    # cast event_timestamp from string to real timestamp
    df = df.withColumn(
        "event_timestamp",
        col("event_timestamp").cast(TimestampType())
    )
    
    # unpack payload column into separate columns
    # get the first payload value as a string
    # payload is already a struct/map, just expand its fields
    # payload is already a struct with named fields, just expand them
    payload_fields = df.select("payload.*").columns
    for field in payload_fields:
        df = df.withColumn(f"payload_{field}", col(f"payload.{field}"))
    df = df.drop("payload")
    
    # write to curated zone
    (
        df.write
        .mode("overwrite")
        .partitionBy("event_type")
        .parquet(output_path)
    )
    
    print(f"Done: {event_type} — {df.count()} records written to curated zone")

EVENT_TYPES = [
    "application_submitted",
    "document_submitted",
    "visa_status_change",
    "enrollment_confirmed",
    "term_registration",
    "opt_cpt_request",
    "status_change",
    "graduation",
]

def main():
    spark = create_spark_session()
    
    # create the curated bucket if it doesn't exist
    import boto3
    s3 = boto3.client(
        "s3",
        endpoint_url="http://localstack:4566",
        aws_access_key_id="test",
        aws_secret_access_key="test",
        region_name="us-east-1"
    )
    try:
        s3.head_bucket(Bucket="eduflow-curated")
    except Exception:
        s3.create_bucket(Bucket="eduflow-curated")
        print("Created eduflow-curated bucket")
    
    for event_type in EVENT_TYPES:
        try:
            print(f"Processing {event_type}...")
            transform_event_type(
                spark=spark,
                event_type=event_type,
                raw_path=f"s3a://eduflow-raw/{event_type}/",
                curated_path=f"s3a://eduflow-curated/{event_type}/"
            )
        except Exception as e:
            print(f"Failed processing {event_type}: {e}")
            continue
    
    spark.stop()
    print("All event types processed.")

if __name__ == "__main__":
    main()