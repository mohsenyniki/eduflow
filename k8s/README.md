# Kubernetes Deployment

## Prerequisites
- kubectl configured against a Kubernetes cluster (EKS, GKE, or local minikube)
- All Docker images built and pushed to a container registry

## Deploy

### 1. Create the namespace
```bash
kubectl apply -f k8s/namespace/namespace.yaml
```

### 2. Deploy infrastructure services
```bash
kubectl apply -f k8s/postgres/
kubectl apply -f k8s/redis/
```

### 3. Deploy Airflow
```bash
kubectl apply -f k8s/airflow/
```

### 4. Deploy the API
```bash
kubectl apply -f k8s/api/
```

### 5. Check everything is running
```bash
kubectl get pods -n eduflow
kubectl get services -n eduflow
```

### 6. Get the public URLs
```bash
kubectl get service airflow-webserver -n eduflow
kubectl get service eduflow-api -n eduflow
```

The `EXTERNAL-IP` column shows the public IP assigned by the cloud provider's load balancer.

## Scaling the API
```bash
kubectl scale deployment eduflow-api --replicas=3 -n eduflow
```

## Viewing logs
```bash
kubectl logs -f deployment/airflow-webserver -n eduflow
kubectl logs -f deployment/eduflow-api -n eduflow
```