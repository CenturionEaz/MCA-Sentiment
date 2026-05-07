# MCA eConsultation — Deployment Flow

## Overview

This document explains the EXACT ORDER in which components must be
started/deployed, and WHY that order matters.

---

## Local Execution Order (Without Docker)

```
1. PostgreSQL server        (must be running FIRST — backend connects on startup)
       ↓
2. Python AI service        (must be running — backend calls it during analysis)
       ↓
3. Spring Boot backend      (starts last — depends on both above)
```

**Why this order?**
- Spring Boot tries to connect to PostgreSQL at startup via Hibernate.
  If Postgres isn't running → `Connection refused` → app fails to start.
- Spring Boot doesn't call AI service at startup, but it's good practice
  to have it running so the first analysis request succeeds immediately.

---

## Docker Compose Startup Order

```
docker compose up --build

    postgres (healthcheck: pg_isready)
         ↓  [wait until HEALTHY]
    ai-service (healthcheck: curl /health)
         ↓  [wait until HEALTHY]
    app (Spring Boot)
```

**Controlled by `depends_on` with `condition: service_healthy`.**

This is better than just `depends_on` (which only waits for the
container to START, not for the service inside to be READY).

---

## Kubernetes Deployment Order

```
STEP 1:  namespace.yaml           ← Creates isolated environment
              ↓
STEP 2:  storage/pv.yaml          ← Allocates disk space on the node
              ↓
STEP 3:  storage/pvc.yaml         ← Claims that disk space
              ↓
STEP 4:  configmap.yaml           ← Makes config available
         secret.yaml              ← Makes secrets available
              ↓
STEP 5:  backend/postgres.yaml    ← Database deployment + service
              ↓  [wait for rollout]
STEP 6:  ai-service/deployment.yaml   ← AI service deployment
         ai-service/service.yaml      ← AI service network endpoint
              ↓  [wait for rollout - model loading takes ~90s]
STEP 7:  backend/deployment.yaml  ← Spring Boot (initContainers wait for above)
         backend/service.yaml     ← Backend network endpoint
              ↓
STEP 8:  backend/hpa.yaml         ← Auto-scaling rules
         ai-service/hpa.yaml      ← AI auto-scaling rules
              ↓
STEP 9:  ingress/ingress.yaml     ← External routing (apply last)
```

**Why namespace first?**
All other YAML files specify `namespace: mca-econsultation`.
If the namespace doesn't exist, `kubectl apply` will fail with
`namespaces "mca-econsultation" not found`.

**Why PV before PVC?**
Kubernetes matches PVCs to PVs by storageClassName and capacity.
If the PV doesn't exist yet, the PVC stays in `Pending` state
and any Pod trying to mount it will also stay `Pending`.

**Why ConfigMap/Secret before Deployment?**
Deployments reference ConfigMaps and Secrets by name.
If they don't exist when the Pod starts, the Pod fails with:
`Error: configmap "mca-backend-config" not found`.

---

## How Services Communicate

### 1. Browser → Ingress

```
User types: http://mca-econsultation.local/dashboard
    ↓
DNS resolves to Minikube IP (from /etc/hosts)
    ↓
nginx Ingress Controller receives request
    ↓
Reads Ingress rules: path / → mca-backend-service:80
    ↓
Forwards to mca-backend-service
```

### 2. Ingress → Backend Service → Backend Pod

```
mca-backend-service (ClusterIP)
    ↓
kube-proxy does iptables round-robin
    ↓
Selects one of the backend Pods (e.g., mca-backend-pod-xyz)
    ↓
Pod receives HTTP request on port 8080
```

### 3. Backend Pod → AI Service

```
Spring Boot code calls:
  RestTemplate.postForObject("http://mca-ai-service:5001/predict", ...)
    ↓
Kubernetes DNS resolves "mca-ai-service" to the ClusterIP
    ↓
mca-ai-service (ClusterIP) load-balances to AI Pod
    ↓
Flask processes the text and returns JSON prediction
    ↓
Spring Boot receives prediction and saves to PostgreSQL
```

### 4. Backend Pod → PostgreSQL

```
JDBC URL: jdbc:postgresql://mca-postgres-service:5432/mca_db
    ↓
Kubernetes DNS resolves "mca-postgres-service" to ClusterIP
    ↓
ClusterIP forwards to the single Postgres Pod
    ↓
Postgres executes SQL, returns result sets
```

---

## Internal DNS Resolution

Kubernetes gives every Service a DNS name:

```
<service-name>.<namespace>.svc.cluster.local
```

Within the same namespace, you can use just `<service-name>`:

| What You Type | What It Resolves To |
|---------------|---------------------|
| `mca-postgres-service` | `mca-postgres-service.mca-econsultation.svc.cluster.local` |
| `mca-ai-service` | `mca-ai-service.mca-econsultation.svc.cluster.local` |
| `mca-backend-service` | `mca-backend-service.mca-econsultation.svc.cluster.local` |

---

## Rolling Update Flow (Zero-Downtime Deploy)

When you update the backend image and re-apply:

```
Current state: 2 backend Pods running (v1.0)

kubectl apply -f k8s/backend/deployment.yaml
                    ↓
Kubernetes creates 1 new Pod (v1.1)  [maxSurge: 1 → temporarily 3 Pods]
                    ↓
New Pod passes readinessProbe
                    ↓
Kubernetes terminates 1 old Pod (v1.0)  [back to 2 Pods]
                    ↓
Process repeats for remaining old Pods
                    ↓
Final state: 2 backend Pods running (v1.1)
             0 downtime for users
```

---

## HPA Scaling Flow

```
Metrics Server collects CPU every 15s

Backend average CPU > 70%?
    YES:
        HPA calculates desired = ceil(current * actual/target)
        E.g.: ceil(2 * 140%/70%) = 4 Pods
        HPA updates Deployment: replicas = 4
        Kubernetes creates 2 new Pods
        Wait 60s stabilization window before scaling again

Backend average CPU < 70% for 5+ minutes?
    YES:
        HPA decreases replicas by 1
        Kubernetes gracefully terminates 1 Pod
        Wait 2 min before removing another Pod
```

---

## Data Flow for CSV Analysis

```
1. User uploads CSV via browser form
        ↓
2. POST /upload → AnalysisController (Spring Boot)
        ↓
3. Controller saves file to /app/uploads/ (PVC)
        ↓
4. Controller reads CSV rows using OpenCSV
        ↓
5. For each row with text:
   POST http://mca-ai-service:5001/predict  {"text": "..."}
        ↓
6. Flask AI service:
   a. Preprocesses text (preprocessing.py)
   b. Runs HuggingFace model inference
   c. Applies sentiment bias (config.py)
   d. Returns {"label": "POSITIVE", "score": 0.92}
        ↓
7. Spring Boot receives predictions
        ↓
8. Saves results to PostgreSQL (analysis_results table)
        ↓
9. Triggers word cloud generation:
   POST http://mca-ai-service:5001/wordcloud  {texts: [...]}
        ↓
10. AI service generates wordcloud image → saves to /app/static/
         ↓
11. Backend generates PDF report (iText 7) → saves to /app/static/
         ↓
12. Redirects user to dashboard with charts and download links
```
