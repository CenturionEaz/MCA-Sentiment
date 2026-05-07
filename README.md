# MCA eConsultation — Sentiment Analysis Platform

> A production-ready microservice application for policy consultation sentiment analysis,
> deployed with Docker and Kubernetes.

---

## Quick Start

### Option 1 — Docker Compose (Recommended for local demo)

```bash
cp .env.example .env        # Add your passwords
docker compose up --build   # Builds and starts all 3 services
```

Open: **http://localhost:8080**

### Option 2 — Kubernetes (Full Production Setup)

```bash
minikube start --driver=docker --memory=6144 --cpus=4
minikube addons enable ingress metrics-server

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/storage/
kubectl apply -f k8s/configmap.yaml k8s/secret.yaml
kubectl apply -f k8s/backend/postgres.yaml
kubectl apply -f k8s/ai-service/
kubectl apply -f k8s/backend/
kubectl apply -f k8s/ingress/

minikube tunnel   # In a separate terminal
```

Add `$(minikube ip)   mca-econsultation.local` to your hosts file.

Open: **http://mca-econsultation.local**

---

## Project Architecture

```
Browser → Ingress (nginx) → Backend (Spring Boot :8080)
                                   ↓           ↓
                            PostgreSQL     AI Service
                             (pg 15)     (Flask :5001)
                                            (PyTorch)
```

**3 Microservices:**

| Service | Technology | Port | Purpose |
|---------|-----------|------|---------|
| Backend | Spring Boot 3.2 + Java 17 | 8080 | Web UI + REST API + PDF reports |
| AI Service | Python 3.10 + Flask + PyTorch | 5001 | Sentiment analysis + Word clouds |
| Database | PostgreSQL 15 | 5432 | Persistent data storage |

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/COMPLETE_PROJECT_SETUP_GUIDE.md](docs/COMPLETE_PROJECT_SETUP_GUIDE.md) | **START HERE** — Full 10-phase guide |
| [docs/PROJECT_ARCHITECTURE.md](docs/PROJECT_ARCHITECTURE.md) | System diagrams, tech stack, viva Q&A |
| [docs/FILE_STRUCTURE.md](docs/FILE_STRUCTURE.md) | What every file/folder does |
| [docs/LOCAL_SETUP.md](docs/LOCAL_SETUP.md) | Run without Docker |
| [docs/DOCKER_SETUP.md](docs/DOCKER_SETUP.md) | Docker build, Compose, DockerHub push |
| [docs/KUBERNETES_SETUP.md](docs/KUBERNETES_SETUP.md) | Full Minikube + kubectl deployment |
| [docs/DEPLOYMENT_FLOW.md](docs/DEPLOYMENT_FLOW.md) | Service communication, startup order |

---

## Kubernetes Manifests Overview

```
k8s/
├── namespace.yaml           Isolated namespace: mca-econsultation
├── configmap.yaml           Non-sensitive config (URLs, ports)
├── secret.yaml              Sensitive config (passwords, OAuth keys)
├── storage/
│   ├── pv.yaml              PersistentVolumes (disk allocations)
│   └── pvc.yaml             PersistentVolumeClaims (Pod storage requests)
├── backend/
│   ├── deployment.yaml      Spring Boot (2 replicas, rolling update)
│   ├── service.yaml         ClusterIP Service
│   ├── hpa.yaml             Auto-scales 2–8 replicas on CPU/Memory
│   └── postgres.yaml        PostgreSQL Deployment + Service
├── ai-service/
│   ├── deployment.yaml      Flask AI (1 replica, 90s startup)
│   ├── service.yaml         ClusterIP Service (internal only)
│   └── hpa.yaml             Auto-scales 1–4 replicas
└── ingress/
    └── ingress.yaml         nginx Ingress (single external entry point)
```

---

## Features

- **CSV Upload** — Upload policy consultation CSV files
- **Sentiment Analysis** — HuggingFace Transformer model classifies each response
- **Word Cloud** — Visual representation of most frequent terms
- **PDF Report** — Downloadable analysis report (iText 7)
- **History** — View all past analyses
- **Google OAuth2** — Secure login via Google accounts
- **Auto-Scaling** — Kubernetes HPA scales backend 2–8x on load

---

## Technology Stack

**Backend:** Spring Boot 3.2 · Java 17 · Thymeleaf · Spring Security · PostgreSQL · iText 7 · OpenCSV · Maven

**AI Service:** Python 3.10 · Flask 3.0 · PyTorch 2.3 · HuggingFace Transformers 4.41 · WordCloud · NLTK · scikit-learn

**DevOps:** Docker · Docker Compose · Kubernetes · nginx Ingress · HPA · PV/PVC · ConfigMap · Secrets · Minikube

---

## Environment Variables

Copy `.env.example` to `.env` and fill in:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_strong_password
```

For Kubernetes secrets, see `k8s/secret.yaml` and [docs/KUBERNETES_SETUP.md](docs/KUBERNETES_SETUP.md).

---

## Development

### Prerequisites
- Java 17 JDK
- Maven 3.9+
- Python 3.10
- PostgreSQL 15
- Docker Desktop

### Build Backend
```bash
mvn clean package -DskipTests
java -jar target/econsultation-1.0.0.jar
```

### Build AI Service
```bash
cd python-ai-service
pip install -r requirements.txt
python ai_server.py
```

---

## Capstone / Viva Notes

This project demonstrates:

1. **Microservice Architecture** — 3 independent services with clear boundaries
2. **Containerization** — Each service packaged as a Docker image
3. **Container Orchestration** — Kubernetes manages lifecycle, scaling, networking
4. **Infrastructure as Code** — All K8s manifests are version-controlled YAML
5. **Config Management** — ConfigMaps and Secrets separate config from code
6. **Auto-scaling** — HPA responds to real traffic load automatically
7. **Persistent Storage** — PV/PVC ensures data survives Pod restarts
8. **Zero-Downtime Deploys** — Rolling update strategy
9. **Health Management** — Liveness and readiness probes
10. **Service Discovery** — Kubernetes internal DNS for inter-service communication

See [docs/PROJECT_ARCHITECTURE.md](docs/PROJECT_ARCHITECTURE.md) for interview Q&A.

---

## License

MCA Capstone Project — Academic Use
