# MCA eConsultation — Project Architecture

## System Overview

The MCA eConsultation platform is a **three-tier microservice application** that performs sentiment analysis on policy consultation data submitted via CSV files.

```
┌─────────────────────────────────────────────────────────────────┐
│                      USER (Browser)                             │
│              http://mca-econsultation.local                     │
└───────────────────────────┬─────────────────────────────────────┘
                            │ HTTP
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   INGRESS (nginx)                               │
│         Layer 7 Load Balancer / Reverse Proxy                   │
│         Routes all traffic → mca-backend-service                │
└───────────────────────────┬─────────────────────────────────────┘
                            │ HTTP :80
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              BACKEND SERVICE (ClusterIP)                        │
│              mca-backend-service:80                             │
│         Load balances across backend Pod replicas               │
└──────────────┬────────────────────────────────────────────────--┘
               │
       ┌───────┴───────┐
       ▼               ▼
┌─────────────┐  ┌─────────────┐   ← HPA scales 2–8 replicas
│  Backend    │  │  Backend    │
│  Pod  #1    │  │  Pod  #2    │
│ Spring Boot │  │ Spring Boot │
│   :8080     │  │   :8080     │
└──────┬──────┘  └──────┬──────┘
       │                │
       │  HTTP :5001/predict
       ▼
┌─────────────────────────────────────────────────────────────────┐
│              AI SERVICE (ClusterIP)                             │
│              mca-ai-service:5001                                │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                    ┌───────┴────────┐
                    ▼                ▼
             ┌──────────┐    ┌──────────┐  ← HPA scales 1–4 replicas
             │ AI Pod#1 │    │ AI Pod#2 │
             │ Flask    │    │ Flask    │
             │ PyTorch  │    │ PyTorch  │
             │  :5001   │    │  :5001   │
             └──────────┘    └──────────┘
                    │
       ┌────────────────────┐
       ▼                    ▼
┌─────────────┐   ┌──────────────────┐
│  Postgres   │   │  PVC / PV        │
│  Service    │   │  (Static output) │
│   :5432     │   │  Word clouds,    │
└──────┬──────┘   │  charts, reports │
       │          └──────────────────┘
       ▼
┌─────────────┐
│  Postgres   │
│    Pod      │
│  pg 15      │
│   :5432     │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  PV/PVC     │
│  postgres   │
│  data files │
│  2Gi disk   │
└─────────────┘
```

---

## Service Communication Map

| From | To | Protocol | Port | Purpose |
|------|----|----------|------|---------|
| Browser | Ingress | HTTP | 80 | User accesses UI |
| Ingress | Backend Service | HTTP | 80 | Forwards all requests |
| Backend Service | Backend Pods | HTTP | 8080 | Load balanced |
| Backend Pod | AI Service | HTTP | 5001 | Sentiment prediction |
| Backend Pod | Postgres Service | TCP | 5432 | Database queries |
| AI Service | PVC | Filesystem | — | Write word cloud images |
| Backend Pod | PVC (uploads) | Filesystem | — | Write CSV uploads |

---

## Technology Stack

### Backend — Spring Boot 3.2 (Java 17)
| Layer | Technology | Purpose |
|-------|-----------|---------|
| Web Framework | Spring Boot 3.2 | REST API + MVC |
| Template Engine | Thymeleaf | Server-side HTML rendering |
| Security | Spring Security + OAuth2 | Google login |
| Database ORM | Spring Data JPA + Hibernate | DB access layer |
| Database Driver | PostgreSQL JDBC | Connects to Postgres |
| CSV Parsing | OpenCSV 5.9 | Reads uploaded CSV files |
| PDF Generation | iText 7.2.5 | Generates analysis reports |
| JSON | Jackson | REST request/response serialisation |
| Build Tool | Maven 3.9 | Dependency management + build |
| Container | eclipse-temurin:17-jre | Java runtime |

### AI Service — Python 3.10 + Flask
| Layer | Technology | Purpose |
|-------|-----------|---------|
| Web Framework | Flask 3.0.3 | HTTP API |
| ML Framework | Transformers 4.41.2 | HuggingFace models |
| Deep Learning | PyTorch 2.3.1 | Model inference |
| NLP | NLTK 3.9.1 | Text preprocessing |
| Visualisation | WordCloud + Matplotlib | Word cloud generation |
| ML Utilities | scikit-learn 1.5.2 | Feature engineering |
| Image Processing | Pillow 10.3.0 | Image output |

### Database
| Layer | Technology | Purpose |
|-------|-----------|---------|
| RDBMS | PostgreSQL 15 | Primary data store |
| Schema Management | Hibernate DDL | Auto-creates tables |

### DevOps
| Layer | Technology | Purpose |
|-------|-----------|---------|
| Containerisation | Docker | Package services into images |
| Local Orchestration | Docker Compose | Run all services locally |
| Production Orchestration | Kubernetes 1.28+ | Deploy at scale |
| Ingress Controller | nginx | External traffic routing |
| Auto-scaling | HPA (autoscaling/v2) | Scale on CPU/Memory |
| Storage | PV + PVC | Persistent data |
| Config | ConfigMap + Secret | Environment management |

---

## Why Microservices?

### Interview Answer:
> "We chose microservices because each component — the web backend, the ML inference engine, and the database — has completely different resource requirements and scaling needs. The AI service needs more memory (PyTorch models are ~500MB+), while the backend scales with HTTP request volume. Separating them means we can scale each independently, update them independently, and if the AI model crashes, the rest of the application continues running."

### Benefits in This Project:
1. **Independent scaling** — Backend handles 100 users, AI handles 10 concurrent predictions
2. **Independent deployment** — Update the ML model without redeploying the web UI
3. **Fault isolation** — Postgres crash ≠ AI service crash
4. **Technology fit** — Java for web, Python for ML (use the best tool per job)
5. **Team separation** — Backend team and ML team work independently

---

## Why Docker?

### Interview Answer:
> "Docker solves the 'it works on my machine' problem. Every developer and every deployment server runs the exact same container image — same OS, same libraries, same Python version. Without Docker, deploying a PyTorch application means installing CUDA drivers, matching Python versions, and setting up venvs on every machine."

### Benefits in This Project:
- `python-ai-service` needs PyTorch 2.3.1 + CUDA — Docker bundles all of this
- Spring Boot needs Java 17 — Docker provides it without installing JDK on servers
- All 3 services run identically on Windows/Linux/Mac

---

## Why Kubernetes?

### Interview Answer:
> "Docker Compose is great for local development, but it runs on a single machine. If that machine fails, everything goes down. Kubernetes runs across multiple machines and automatically restarts failed containers, reschedules them to healthy nodes, and scales them up when traffic increases — all without human intervention."

### Benefits in This Project:
- **Self-healing**: Kubernetes restarts crashed Pods automatically
- **HPA**: Scales backend 2→8 replicas during peak CSV upload hours
- **Zero-downtime deploys**: Rolling updates replace Pods one-by-one
- **Resource management**: Prevents AI service from consuming all RAM

---

## Why HPA?

### Interview Answer:
> "HPA (Horizontal Pod Autoscaler) allows the system to handle unpredictable traffic without over-provisioning resources. When multiple users upload large CSV files simultaneously, backend CPU spikes — HPA automatically launches more backend Pods to distribute load. When traffic drops, HPA removes extra Pods, saving compute costs."

---

## Why PV/PVC?

### Interview Answer:
> "Containers are ephemeral — if a container is deleted, all data inside it is lost. Our application writes uploaded CSV files to disk and the AI service writes word cloud images. These files must survive Pod restarts. PersistentVolumes are like external hard drives attached to Pods — the Pod can die, but the data lives on."

---

## Docker vs Kubernetes — Key Differences

| Aspect | Docker Compose | Kubernetes |
|--------|----------------|------------|
| Scale | Single machine | Multiple machines (cluster) |
| Self-healing | No | Yes (restarts failed Pods) |
| Load balancing | Basic (round-robin) | Advanced (Service, Ingress) |
| Scaling | Manual (`scale` command) | Automatic (HPA) |
| Rolling updates | Manual | Automatic |
| Storage | Named volumes | PV/PVC (pluggable) |
| Config | env files | ConfigMap + Secret |
| Use case | Local dev, testing | Production, staging |

---

## Container vs VM — Key Differences

| Aspect | Container (Docker) | Virtual Machine |
|--------|-------------------|-----------------|
| OS | Shares host kernel | Full OS per VM |
| Startup | Seconds | Minutes |
| Size | MBs | GBs |
| Isolation | Process-level | Hardware-level |
| Overhead | Very low | High |
| Portability | Very high | Moderate |
| Use case | Microservices | Legacy apps, full isolation |
