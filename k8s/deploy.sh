#!/bin/bash
# deploy.sh
# Deploys the full EduFlow stack to a Kubernetes cluster.
# Prerequisites: kubectl configured against a running cluster.
#
# Usage:
#   ./k8s/deploy.sh           # deploy everything
#   ./k8s/deploy.sh --delete  # tear everything down

set -e

ACTION=${1:-apply}

if [ "$ACTION" = "--delete" ]; then
    echo "Tearing down EduFlow..."
    kubectl delete namespace eduflow --ignore-not-found
    echo "Done."
    exit 0
fi

echo "=========================================="
echo " EduFlow Kubernetes Deployment"
echo "=========================================="

# ── 1. NAMESPACE ──────────────────────────────
echo ""
echo "Creating namespace..."
kubectl apply -f k8s/namespace/namespace.yaml
echo "  ✓ Namespace eduflow ready"

# ── 2. INFRASTRUCTURE ─────────────────────────
echo ""
echo "Deploying infrastructure..."
kubectl apply -f k8s/postgres/
kubectl apply -f k8s/redis/
echo "  ✓ PostgreSQL and Redis deployed"

# ── 3. WAIT FOR INFRASTRUCTURE ────────────────
echo ""
echo "Waiting for infrastructure to be ready..."
kubectl wait --for=condition=ready pod \
    -l app=postgres \
    -n eduflow \
    --timeout=120s
kubectl wait --for=condition=ready pod \
    -l app=redis \
    -n eduflow \
    --timeout=60s
echo "  ✓ Infrastructure ready"

# ── 4. AIRFLOW ────────────────────────────────
echo ""
echo "Deploying Airflow..."
kubectl apply -f k8s/airflow/
echo "  ✓ Airflow deployed"

# ── 5. WAIT FOR AIRFLOW ───────────────────────
echo ""
echo "Waiting for Airflow webserver..."
kubectl wait --for=condition=ready pod \
    -l app=airflow-webserver \
    -n eduflow \
    --timeout=180s
echo "  ✓ Airflow ready"

# ── 6. API ────────────────────────────────────
echo ""
echo "Deploying EduFlow API..."
kubectl apply -f k8s/api/
echo "  ✓ API deployed"

# ── 7. STATUS ─────────────────────────────────
echo ""
echo "=========================================="
echo " Deployment complete. Current status:"
echo "=========================================="
kubectl get pods -n eduflow
echo ""
kubectl get services -n eduflow
echo ""
echo "To get public URLs:"
echo "  kubectl get service airflow-webserver -n eduflow"
echo "  kubectl get service eduflow-api -n eduflow"
echo "=========================================="