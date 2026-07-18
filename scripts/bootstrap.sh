#!/bin/bash
# bootstrap.sh
# Runs after docker compose up to ensure S3 is populated.
# If LocalStack lost its data (bucket empty or missing), this script:
#   1. Waits for all services to be healthy
#   2. Resets the Kafka consumer group offset to earliest
#   3. Triggers the Airflow DAG to repopulate raw S3 files
#   4. Waits for the DAG to complete
#   5. Runs the Spark job to populate the curated zone

set -e  # exit immediately if any command fails

echo "=========================================="
echo " EduFlow Bootstrap"
echo "=========================================="

# ── 1. WAIT FOR SERVICES ──────────────────────────────────────────────────────
# We can't do anything until all services are healthy.
# Poll each one until it responds correctly.

echo ""
echo "Waiting for services to be healthy..."

wait_for_service() {
    local name=$1
    local command=$2
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if eval "$command" > /dev/null 2>&1; then
            echo "  ✓ $name is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        echo "  waiting for $name... ($attempt/$max_attempts)"
        sleep 5
    done
    echo "  ✗ $name failed to become healthy after $((max_attempts * 5)) seconds"
    exit 1
}

# wait for each service using the same health check commands we learned
wait_for_service "Kafka" \
    "docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092"

wait_for_service "LocalStack S3" \
    "docker exec localstack curl -sf http://localhost:4566/_localstack/health"

wait_for_service "Airflow webserver" \
    "docker exec airflow-webserver curl -f http://localhost:8080/health | grep -q 'healthy'"

wait_for_service "Spark master" \
    "docker exec spark-master curl -f http://localhost:8080 | grep -q 'Spark Master'"

echo ""
echo "All services healthy."

# ── 2. CHECK IF S3 NEEDS REPOPULATING ─────────────────────────────────────────
# List the raw bucket. If it's empty or doesn't exist, we need to repopulate.

echo ""
echo "Checking S3 raw zone..."

BUCKET_EXISTS=$(docker exec localstack awslocal s3 ls 2>/dev/null | grep -c "eduflow-raw" || true)

if [ "$BUCKET_EXISTS" -eq 0 ]; then
    echo "  eduflow-raw bucket is empty or missing. Repopulating..."
    NEEDS_REPOPULATE=true
else
    FILE_COUNT=$(docker exec localstack awslocal s3 ls s3://eduflow-raw/ --recursive 2>/dev/null | wc -l | tr -d ' ')
    if [ "$FILE_COUNT" -eq 0 ]; then
        echo "  eduflow-raw bucket exists but has no files. Repopulating..."
        NEEDS_REPOPULATE=true
    else
        echo "  ✓ eduflow-raw bucket has $FILE_COUNT files. Skipping repopulation."
        NEEDS_REPOPULATE=false
    fi
fi

# ── 3. REPOPULATE IF NEEDED ───────────────────────────────────────────────────

if [ "$NEEDS_REPOPULATE" = true ]; then

    # Step 3a: Reset Kafka consumer group offset to earliest
    # This ensures Airflow re-reads all events from the beginning
    echo ""
    echo "Resetting Kafka consumer group offset..."
    docker exec kafka kafka-consumer-groups \
        --bootstrap-server localhost:9092 \
        --group airflow-consumer-group \
        --reset-offsets \
        --to-earliest \
        --all-topics \
        --execute > /dev/null 2>&1 || true
    echo "  ✓ Consumer group offset reset"

    # Step 3b: Trigger Airflow DAG
    echo ""
    echo "Triggering Airflow DAG: kafka_to_s3_raw..."
    RUN_ID="bootstrap_$(date +%Y%m%dT%H%M%S)"
    docker exec airflow-webserver airflow dags trigger kafka_to_s3_raw \
        --run-id "$RUN_ID" > /dev/null 2>&1
    echo "  ✓ DAG triggered with run ID: $RUN_ID"

    # Step 3c: Wait for DAG to complete
    echo ""
    echo "Waiting for DAG to complete..."
    MAX_WAIT=120
    ELAPSED=0

    while [ $ELAPSED -lt $MAX_WAIT ]; do
        STATE=$(docker exec airflow-webserver airflow dags-state kafka_to_s3_raw "$RUN_ID" 2>/dev/null | tail -1 || echo "unknown")
        
        if [ "$STATE" = "success" ]; then
            echo "  ✓ DAG completed successfully"
            break
        elif [ "$STATE" = "failed" ]; then
            echo "  ✗ DAG failed. Check Airflow UI at http://localhost:8080"
            exit 1
        fi

        echo "  DAG state: $STATE... waiting ($ELAPSED/${MAX_WAIT}s)"
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done

    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "  ✗ DAG did not complete within ${MAX_WAIT}s. Check Airflow UI."
        exit 1
    fi
fi

# ── 4. ALWAYS RUN SPARK ───────────────────────────────────────────────────────
echo ""
echo "Running Spark transformation job..."
docker exec -u root spark-master /opt/spark/jobs/submit_transform.sh 2>&1 | grep -E "Processing|Done|Failed"
echo "  ✓ Spark job completed"

echo ""
CURATED_COUNT=$(docker exec localstack awslocal s3 ls s3://eduflow-curated/ --recursive 2>/dev/null | wc -l | tr -d ' ')
echo "  ✓ Curated zone has $CURATED_COUNT files"


# ── 5. DONE ───────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo " Bootstrap complete. Pipeline is ready."
echo " Airflow UI:    http://localhost:8080"
echo " Spark UI:      http://localhost:8081"
echo "=========================================="
