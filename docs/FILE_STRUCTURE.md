# MCA eConsultation — Complete File Structure

## Project Root

```
mca-econsultation/                        ← Project root
│
├── .env                                  ← Your local secrets (GITIGNORED — never commit!)
├── .env.example                          ← Template for .env (safe to commit)
├── .gitignore                            ← Files/folders git ignores
├── .gitattributes                        ← Git line-ending settings
│
├── Dockerfile                            ← Builds the Spring Boot backend Docker image
├── docker-compose.yml                    ← Runs ALL services locally (postgres + ai + backend)
├── pom.xml                               ← Maven build config (Java dependencies)
├── sample_data.csv                       ← Example CSV for testing uploads
│
├── README.md                             ← Project overview and quick-start
│
├── src/                                  ← Spring Boot Java source code
│   └── main/
│       ├── java/com/mca/econsult/        ← Main Java package
│       │   ├── MCAApplication.java       ← Spring Boot entry point (@SpringBootApplication)
│       │   ├── config/                   ← Spring Security, OAuth2, Web config
│       │   ├── controller/               ← HTTP request handlers (MVC controllers)
│       │   │   ├── AnalysisController.java  ← CSV upload, sentiment, report endpoints
│       │   │   ├── AuthController.java      ← Login/logout/OAuth2 endpoints
│       │   │   └── HistoryController.java   ← Analysis history endpoints
│       │   ├── model/                    ← JPA entities (DB table mappings)
│       │   ├── repository/               ← Spring Data JPA repositories (DB queries)
│       │   └── service/                  ← Business logic layer
│       │       ├── SummaryService.java   ← Orchestrates analysis pipeline
│       │       └── WordCloudService.java ← Calls AI service for word cloud
│       └── resources/
│           ├── application.properties    ← Spring configuration (DB URL, ports, paths)
│           ├── static/                   ← Static assets (CSS, JS, images, generated PDFs)
│           └── templates/               ← Thymeleaf HTML templates (UI pages)
│
├── python-ai-service/                    ← Python Flask ML microservice
│   ├── Dockerfile                        ← Builds the AI service Docker image
│   ├── requirements.txt                  ← Python package dependencies
│   ├── ai_server.py                      ← Flask app entry point (/predict, /health endpoints)
│   ├── config.py                         ← Configuration (ports, model paths, bias settings)
│   ├── preprocessing.py                  ← Text cleaning and tokenisation
│   ├── evaluation.py                     ← Model evaluation utilities
│   ├── explainability.py                 ← SHAP/LIME explanations (if used)
│   ├── static/                           ← Word cloud images output here (shared with backend)
│   └── logs/                             ← Flask application logs
│
├── uploads/                              ← Uploaded CSV files stored here (gitignored)
│
├── k8s/                                  ← ALL Kubernetes manifests
│   ├── namespace.yaml                    ← Creates 'mca-econsultation' namespace
│   ├── configmap.yaml                    ← Non-sensitive config (URLs, ports, paths)
│   ├── secret.yaml                       ← Sensitive config (passwords, OAuth keys)
│   │
│   ├── storage/                          ← Storage manifests
│   │   ├── pv.yaml                       ← PersistentVolumes (physical disk allocations)
│   │   └── pvc.yaml                      ← PersistentVolumeClaims (Pod storage requests)
│   │
│   ├── backend/                          ← Spring Boot backend manifests
│   │   ├── deployment.yaml               ← Backend Deployment (Pod blueprint + replicas)
│   │   ├── service.yaml                  ← Backend Service (ClusterIP, stable DNS)
│   │   ├── hpa.yaml                      ← Auto-scales backend 2–8 replicas
│   │   └── postgres.yaml                 ← PostgreSQL Deployment + Service (combined)
│   │
│   ├── ai-service/                       ← Python AI service manifests
│   │   ├── deployment.yaml               ← AI Deployment (1 replica default)
│   │   ├── service.yaml                  ← AI Service (ClusterIP, internal only)
│   │   └── hpa.yaml                      ← Auto-scales AI 1–4 replicas
│   │
│   ├── frontend/                         ← Frontend manifests
│   │   └── deployment.yaml               ← Note: UI is Thymeleaf (template for future React)
│   │
│   └── ingress/
│       └── ingress.yaml                  ← nginx Ingress (single external entry point)
│
└── docs/                                 ← All project documentation
    ├── PROJECT_ARCHITECTURE.md           ← System design, diagrams, tech stack
    ├── FILE_STRUCTURE.md                 ← This file — explains every file/folder
    ├── LOCAL_SETUP.md                    ← Run project without Docker
    ├── DOCKER_SETUP.md                   ← Build and run with Docker + Docker Compose
    ├── KUBERNETES_SETUP.md               ← Deploy with Minikube + kubectl
    ├── DEPLOYMENT_FLOW.md                ← Step-by-step deployment sequence
    └── COMPLETE_PROJECT_SETUP_GUIDE.md   ← THE master guide (start here!)
```

---

## What Each Kubernetes File Does

### `namespace.yaml`
Creates the `mca-econsultation` namespace. Think of it as a virtual cluster within your cluster — all project resources live here, isolated from everything else.

### `configmap.yaml`
Stores environment variables that are NOT secret:
- Database URL (`jdbc:postgresql://mca-postgres-service:5432/mca_db`)
- AI service URL (`http://mca-ai-service:5001`)
- Port numbers, log levels, file paths

### `secret.yaml`
Stores sensitive data as base64-encoded strings:
- `POSTGRES_PASSWORD` — database password
- `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` — OAuth2 credentials
- Never commits these real values to Git

### `storage/pv.yaml`
Defines 3 PersistentVolumes (physical disk space on the host):
1. `mca-postgres-pv` — 2Gi for PostgreSQL data
2. `mca-uploads-pv` — 1Gi for uploaded CSV files
3. `mca-ai-static-pv` — 500Mi for word cloud and chart outputs

### `storage/pvc.yaml`
Defines 3 PersistentVolumeClaims (requests that bind to the PVs):
1. `mca-postgres-pvc` — used by the Postgres Pod
2. `mca-uploads-pvc` — used by backend Pod
3. `mca-ai-static-pvc` — used by both AI and backend Pods

### `backend/deployment.yaml`
Blueprint for running the Spring Boot app:
- `replicas: 2` — 2 Pods always running
- `initContainers` — waits for Postgres and AI service before starting
- `livenessProbe` — restarts Pod if `/actuator/health` fails
- `readinessProbe` — removes Pod from Service until healthy
- Mounts uploads and AI static PVCs

### `backend/service.yaml`
ClusterIP Service for the backend:
- DNS: `mca-backend-service.mca-econsultation.svc.cluster.local`
- Port 80 → container port 8080
- Ingress uses this service name to route traffic

### `backend/hpa.yaml`
Auto-scaling for backend:
- Scale UP when CPU > 70% or Memory > 80%
- Scale DOWN after 5 minutes of low usage
- Min: 2 Pods, Max: 8 Pods

### `backend/postgres.yaml`
PostgreSQL Deployment + Service in one file:
- `strategy: Recreate` (not RollingUpdate) — database can't have 2 writers
- Uses `mca-postgres-pvc` for data persistence
- Service name `mca-postgres-service` is used in backend's JDBC URL

### `ai-service/deployment.yaml`
Blueprint for the Flask AI service:
- `replicas: 1` (HPA manages scaling)
- 90s `initialDelaySeconds` — PyTorch model loading takes time
- 1Gi memory request, 3Gi limit (Transformers are memory-heavy)

### `ai-service/service.yaml`
ClusterIP Service for AI:
- DNS: `mca-ai-service` (within namespace)
- Port 5001 → container port 5001
- Backend calls `http://mca-ai-service:5001/predict`

### `ai-service/hpa.yaml`
Conservative scaling for AI:
- Scale UP at 75% CPU (inference is CPU-intensive)
- Min: 1 Pod, Max: 4 Pods
- Long cooldown (10 min) before scaling down

### `ingress/ingress.yaml`
Single external entry point:
- Host: `mca-econsultation.local`
- All paths (`/`) → `mca-backend-service:80`
- Annotations: 5-min timeout (for large CSV + ML inference), 20MB upload size

---

## What Each Docker File Does

### Root `Dockerfile` (Spring Boot Backend)
```
Stage 1 (build):  maven:3.9-eclipse-temurin-17
  - Copies pom.xml + src
  - Runs: mvn clean package -DskipTests
  - Produces: target/econsultation-1.0.0.jar

Stage 2 (run):    eclipse-temurin:17-jre
  - Copies only the .jar (not source code or Maven)
  - Creates uploads/ and static/ directories
  - EXPOSE 8080
  - CMD: java -jar app.jar
```

### `python-ai-service/Dockerfile`
```
Base:   python:3.10-slim
  - Installs gcc, curl (for healthcheck)
  - pip install -r requirements.txt
  - COPY all Python files
  - Creates /app/static/
  - HEALTHCHECK: curl /health
  - CMD: python ai_server.py
```
