import boto3
import pandas as pd
from sqlalchemy import create_engine
import os
from io import BytesIO

# S3 connection (LocalStack)
s3 = boto3.client(
    "s3",
    endpoint_url="http://localhost:4566",
    aws_access_key_id="test",
    aws_secret_access_key="test",
    region_name="us-east-1"
)

# PostgreSQL connection
engine = create_engine(
    "postgresql://airflow:airflow@localhost:5432/eduflow_warehouse"
)

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

def load_event_type(event_type):
    print(f"Loading {event_type}...")
    
    # list all parquet files for this event type
    response = s3.list_objects_v2(
        Bucket="eduflow-curated",
        Prefix=f"{event_type}/"
    )
    
    if "Contents" not in response:
        print(f"  Skipping {event_type}: no files found")
        return
    
    # read all parquet files into one dataframe
    dfs = []
    for obj in response["Contents"]:
        key = obj["Key"]
        if not key.endswith(".parquet"):
            continue
        
        response_obj = s3.get_object(Bucket="eduflow-curated", Key=key)
        buffer = BytesIO(response_obj["Body"].read())
        df = pd.read_parquet(buffer)
        dfs.append(df)

    if not dfs:
        print(f"  Skipping {event_type}: no parquet files")
        return
    
    combined = pd.concat(dfs, ignore_index=True)
    
    # write to postgres as staging table
    table_name = f"stg_{event_type}"
    combined.to_sql(
        table_name,
        engine,
        schema="public",
        if_exists="replace",
        index=False
    )
    
    print(f"  Done: {len(combined)} rows loaded into {table_name}")

if __name__ == "__main__":
    for event_type in EVENT_TYPES:
        try:
            load_event_type(event_type)
        except Exception as e:
            print(f"  Failed {event_type}: {e}")
    
    print("\nAll event types loaded.")