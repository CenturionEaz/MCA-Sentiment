# MCA eConsultation — COMPLETE PROJECT SETUP GUIDE
## The Master Reference Document — Start Here

---

> **How to use this guide:**
> Read Phase by Phase. Each phase builds on the previous one.
> You can stop at any phase depending on what you need to demonstrate.

---

# PHASE 1 — Normal Project Execution (No Docker)

## What You Need
- Java 17 JDK
- Maven 3.9+
- Python 3.10
- PostgreSQL 15

## Step 1.1 — Start PostgreSQL
```bash
# Windows: Start PostgreSQL service
net start postgresql-x64-15

# Linux/Mac:
brew services start postgresql@15   # Mac with Homebrew
sudo service postgresql start       # Ubuntu/Debian
```

## Step 1.2 — Create the Database
```bash
psql -U postgres -c "CREATE DATABASE mca_db;"
```

## Step 1.3 — Start Python AI Service
```bash
cd python-ai-service

# Create virtual environment
python -m venv .venv

# Activate (Windows PowerShell)
.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Start Flask server
python ai_server.py
```

**Expected output:**
```
 * Running on http://0.0.0.0:5001
INFO: Model loaded. Ready for inference.
```

**Verify in a new terminal:**
```bash
curl http://localhost:5001/health
# {"status": "ok"}
```

## Step 1.4 — Start Spring Boot Backend
```bash
# Back to project root
cd ..

# Windows PowerShell — set environment variables
$env:SPRING_DATASOURCE_PASSWORD="1234"
$env:AI_SERVICE_URL="http://localhost:5001"

# Build and run
mvn spring-boot:run
```

**Expected output:**
```
Started EconsultationApplication in 15.3 seconds
Tomcat started on port(s): 8080
```

## Step 1.5 — Access the Application
```
Browser: http://localhost:8080
```

### Verification Checklist
- [ ] Dashboard loads
- [ ] Login with Google OAuth works
- [ ] CSV upload works
- [ ] Sentiment analysis results appear
- [ ] Word cloud appears
- [ ] PDF report downloads

---

# PHASE 2 — Docker Setup (Containerize Each Service)

## Step 2.1 — Install Docker Desktop
Download from: https://www.docker.com/products/docker-desktop/

```bash
docker --version        # Verify: Docker version 24.x.x
```

## Step 2.2 — Build Backend Image

```bash
# In project ROOT (where Dockerfile lives)
docker build -t mca-backend:latest .

# Watch the build — it runs mvn inside the container
# Stage 1: maven:3.9 compiles Java (~3-5 min)
# Stage 2: eclipse-temurin:17-jre copies the JAR
```

**Verify:**
```bash
docker images mca-backend
# REPOSITORY     TAG       IMAGE ID       SIZE
# mca-backend    latest    abc123def456   350MB
```

## Step 2.3 — Build AI Service Image

```bash
docker build -t mca-ai-service:latest ./python-ai-service

# This installs PyTorch + Transformers inside the container
# Takes 5-10 minutes (PyTorch is ~2GB)
```

## Step 2.4 — Test Each Container Individually

```bash
# Test AI service standalone
docker run -d -p 5001:5001 --name test-ai mca-ai-service:latest
sleep 90    # Wait for model to load
curl http://localhost:5001/health
docker rm -f test-ai
```

---

# PHASE 3 — Docker Compose (Run Everything Together)

## Step 3.1 — Create .env File
```bash
cp .env.example .env
```

Edit `.env` with real values:
```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=SecurePass123!
```

## Step 3.2 — Start All Services

```bash
docker compose up --build
```

**What happens (watch the logs):**
```
[postgres]     database system is ready to accept connections
[ai-service]   Model loaded. Ready for inference.
[app]          Tomcat started on port(s): 8080
```

## Step 3.3 — Verify Running Services

```bash
docker compose ps
```

Expected:
```
NAME              STATUS             PORTS
mca-postgres      Up (healthy)       0.0.0.0:5432->5432/tcp
mca-ai-service    Up (healthy)       0.0.0.0:5001->5001/tcp
mca-backend       Up                 0.0.0.0:8080->8080/tcp
```

## Step 3.4 — Test the Full Flow

```bash
# Test AI service through Docker network
curl http://localhost:5001/health

# Access UI
start http://localhost:8080    # Windows
open http://localhost:8080     # Mac
```

## Step 3.5 — Useful Compose Commands

```bash
# View logs of specific service
docker compose logs -f app

# Restart only backend (after code change)
docker compose restart app

# Stop everything (keep DB data)
docker compose down

# Stop everything AND wipe all data
docker compose down -v
```

---

# PHASE 4 — Push Images to DockerHub

## Step 4.1 — Create DockerHub Account
Go to https://hub.docker.com/ → Sign Up → Choose free plan

## Step 4.2 — Login via Terminal

```bash
docker login
# Username: your_dockerhub_username
# Password: your_dockerhub_password
# Login Succeeded
```

## Step 4.3 — Tag Images with Your Username

```bash
# Replace YOUR_USERNAME with your actual DockerHub username
docker tag mca-backend:latest umbramortis/mca-backend:latest
docker tag mca-ai-service:latest umbramortis/mca-ai-service:latest
```

## Step 4.4 — Push to DockerHub

```bash
docker push umbramortis/mca-backend:latest
# Output: Pushing layers... digest: sha256:...

docker push umbramortis/mca-ai-service:latest
# Output: Pushing layers... digest: sha256:...
```

## Step 4.5 — Verify on DockerHub
Visit:
```
https://hub.docker.com/r/YOUR_USERNAME/mca-backend
https://hub.docker.com/r/YOUR_USERNAME/mca-ai-service
```

## Step 4.6 — Update Kubernetes Manifests

In `k8s/backend/deployment.yaml`:
```yaml
image: YOUR_USERNAME/mca-backend:latest    # Update this line
```

In `k8s/ai-service/deployment.yaml`:
```yaml
image: YOUR_USERNAME/mca-ai-service:latest  # Update this line
```

---

# PHASE 5 — Minikube Installation

## Step 5.1 — Install Minikube (Windows)

```powershell
winget install Kubernetes.minikube
# OR download installer from: https://minikube.sigs.k8s.io/docs/start/
```

## Step 5.2 — Install kubectl (Windows)

```powershell
winget install Kubernetes.kubectl
```

## Step 5.3 — Start Minikube Cluster

```bash
minikube start --driver=docker --memory=6144 --cpus=4
```

**Expected output:**
```
* minikube v1.32.0
* Using the docker driver based on user configuration
* Starting control plane node minikube in cluster minikube
* Preparing Kubernetes v1.28.3 on Docker 24.0.7 ...
* Done! kubectl is now configured to use "minikube" cluster
```

## Step 5.4 — Enable Required Addons

```bash
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Verify all enabled
minikube addons list
```

## Step 5.5 — Verify Cluster is Working

```bash
kubectl cluster-info
# Kubernetes control plane is running at https://192.168.49.2:8443

kubectl get nodes
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   2m    v1.28.3
```

---

# PHASE 6 — Kubernetes Deployment

## Step 6.1 — Prepare Secrets

Encode your password:
```powershell
# Windows PowerShell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("SecurePass123!"))
# Output: U2VjdXJlUGFzczEyMyE=
```

Edit `k8s/secret.yaml`:
```yaml
POSTGRES_PASSWORD: U2VjdXJlUGFzczEyMyE=      # Your encoded password
SPRING_DATASOURCE_PASSWORD: U2VjdXJlUGFzczEyMyE=  # Same value
```

## Step 6.2 — Apply All Manifests IN ORDER

```bash
# 1. Namespace (MUST be first)
kubectl apply -f k8s/namespace.yaml
kubectl get namespaces | grep mca
# mca-econsultation   Active   10s

# 2. Storage
kubectl apply -f k8s/storage/pv.yaml
kubectl apply -f k8s/storage/pvc.yaml

# Verify PVCs bound (may take 30 seconds)
kubectl get pvc -n mca-econsultation
# NAME                STATUS   VOLUME              CAPACITY
# mca-postgres-pvc    Bound    mca-postgres-pv     2Gi
# mca-uploads-pvc     Bound    mca-uploads-pv      1Gi
# mca-ai-static-pvc   Bound    mca-ai-static-pv    500Mi

# 3. Config and Secrets
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# Verify
kubectl get configmaps -n mca-econsultation
kubectl get secrets -n mca-econsultation

# 4. PostgreSQL
kubectl apply -f k8s/backend/postgres.yaml
kubectl rollout status deployment/mca-postgres -n mca-econsultation
# Waiting for deployment... deployment "mca-postgres" successfully rolled out

# 5. AI Service
kubectl apply -f k8s/ai-service/deployment.yaml
kubectl apply -f k8s/ai-service/service.yaml
kubectl rollout status deployment/mca-ai-service -n mca-econsultation
# Note: Takes 90+ seconds for model loading

# 6. Backend
kubectl apply -f k8s/backend/deployment.yaml
kubectl apply -f k8s/backend/service.yaml
kubectl rollout status deployment/mca-backend -n mca-econsultation

# 7. HPAs
kubectl apply -f k8s/backend/hpa.yaml
kubectl apply -f k8s/ai-service/hpa.yaml

# 8. Ingress (last)
kubectl apply -f k8s/ingress/ingress.yaml
```

## Step 6.3 — Verify Everything Is Running

```bash
kubectl get all -n mca-econsultation
```

Expected output:
```
NAME                                   READY   STATUS    RESTARTS
pod/mca-backend-7d9c8f-xk2p            1/1     Running   0
pod/mca-backend-7d9c8f-zt9q            1/1     Running   0
pod/mca-ai-service-5c6d7b-mn4r         1/1     Running   0
pod/mca-postgres-6b7f8c-pq2w           1/1     Running   0

NAME                          TYPE        CLUSTER-IP      PORT(S)
service/mca-backend-service   ClusterIP   10.96.100.5     80/TCP
service/mca-ai-service        ClusterIP   10.96.100.6     5001/TCP
service/mca-postgres-service  ClusterIP   10.96.100.7     5432/TCP

NAME                            READY   UP-TO-DATE   AVAILABLE
deployment.apps/mca-backend     2/2     2            2
deployment.apps/mca-ai-service  1/1     1            1
deployment.apps/mca-postgres    1/1     1            1
```

---

# PHASE 7 — Ingress Setup

## Step 7.1 — Start Minikube Tunnel

In a **NEW terminal** (keep it running the whole time):
```bash
minikube tunnel
# You may be prompted for admin password
# Keep this terminal open — don't close it!
```

## Step 7.2 — Get Minikube IP

```bash
minikube ip
# 192.168.49.2
```

## Step 7.3 — Add Hosts File Entry

**Windows** (Run Notepad as Administrator):
```
File: C:\Windows\System32\drivers\etc\hosts
Add this line: 192.168.49.2   mca-econsultation.local
```

**Quick PowerShell (Run as Administrator):**
```powershell
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "$(minikube ip)   mca-econsultation.local"
```

## Step 7.4 — Verify Ingress

```bash
kubectl get ingress -n mca-econsultation
# NAME          CLASS   HOSTS                        ADDRESS         PORTS
# mca-ingress   nginx   mca-econsultation.local      192.168.49.2    80
```

## Step 7.5 — Access Application

```
http://mca-econsultation.local
```

**How Ingress works here:**
```
Browser → mca-econsultation.local → (hosts file) → 192.168.49.2
→ nginx Ingress Controller → mca-backend-service:80 → backend Pod :8080
```

---

# PHASE 8 — HPA Verification

## Step 8.1 — Check HPA Status

```bash
kubectl get hpa -n mca-econsultation
```

Expected:
```
NAME                  REFERENCE                TARGETS        MINPODS   MAXPODS   REPLICAS
mca-backend-hpa       Deployment/mca-backend   15%/70%        2         8         2
mca-ai-service-hpa    Deployment/mca-ai-svc    8%/75%         1         4         1
```

The `TARGETS` column shows: `currentCPU%/targetCPU%`

## Step 8.2 — Watch HPA in Real-Time

```bash
kubectl get hpa -n mca-econsultation -w
# Updates every few seconds
```

## Step 8.3 — Simulate Load to Trigger HPA (Optional)

```bash
# Open a test Pod with wget
kubectl run load-test --image=busybox:1.36 -n mca-econsultation --rm -it -- sh

# Inside the Pod, hammer the backend
while true; do
  wget -q -O- http://mca-backend-service/dashboard > /dev/null 2>&1
done

# In another terminal — watch replicas scale up
kubectl get hpa mca-backend-hpa -n mca-econsultation -w
```

## Why HPA Needs metrics-server

```bash
# If HPA shows "unable to get metrics":
kubectl get apiservice v1beta1.metrics.k8s.io
minikube addons enable metrics-server

# Wait 60 seconds and try again
kubectl top pods -n mca-econsultation
# NAME                    CPU(cores)   MEMORY(bytes)
# mca-backend-xxx         45m          512Mi
```

---

# PHASE 9 — PV/PVC Verification

## Step 9.1 — Check PVs (Cluster-Wide)

```bash
kubectl get pv
```

Expected:
```
NAME               CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
mca-postgres-pv    2Gi        RWO            Retain           Bound    mca-econsultation/mca-postgres-pvc
mca-uploads-pv     1Gi        RWX            Retain           Bound    mca-econsultation/mca-uploads-pvc
mca-ai-static-pv   500Mi      RWX            Retain           Bound    mca-econsultation/mca-ai-static-pvc
```

STATUS must be `Bound` (not `Pending` or `Available`)

## Step 9.2 — Check PVCs (Namespace-Scoped)

```bash
kubectl get pvc -n mca-econsultation
```

All must show STATUS = `Bound`

## Step 9.3 — Verify Data Persistence

```bash
# Check that the Postgres Pod is using the PVC
kubectl describe pod -l app=mca-postgres -n mca-econsultation | grep -A5 Volumes

# Expected:
# Volumes:
#   postgres-storage:
#     Type: PersistentVolumeClaim
#     ClaimName: mca-postgres-pvc
```

## Step 9.4 — Verify Data Survives Pod Restart

```bash
# 1. Upload a CSV through the UI (creates DB records)
# 2. Kill the Postgres Pod
kubectl delete pod -l app=mca-postgres -n mca-econsultation

# 3. Kubernetes automatically restarts it (Deployment ensures this)
kubectl get pods -n mca-econsultation -w

# 4. Once running again, check your data is still there
# Access the UI — your history should still show the uploaded analysis
```

---

# PHASE 10 — Debugging Commands

## Pod Debugging

```bash
# See all Pods and their status
kubectl get pods -n mca-econsultation

# Describe a Pod (shows events, errors, restart reasons)
kubectl describe pod <pod-name> -n mca-econsultation

# Get logs from a Pod
kubectl logs <pod-name> -n mca-econsultation

# Get last 50 lines
kubectl logs <pod-name> -n mca-econsultation --tail=50

# Follow logs in real-time
kubectl logs -f <pod-name> -n mca-econsultation

# Get logs by label (all backend pods)
kubectl logs -l app=mca-backend -n mca-econsultation --prefix=true

# Previous container logs (if Pod restarted)
kubectl logs <pod-name> -n mca-econsultation --previous
```

## Shell into a Running Pod

```bash
# Get a bash shell inside the backend Pod
kubectl exec -it <backend-pod-name> -n mca-econsultation -- bash

# Get a shell inside the AI service Pod
kubectl exec -it <ai-pod-name> -n mca-econsultation -- bash

# Connect to the Postgres Pod and run SQL
kubectl exec -it <postgres-pod-name> -n mca-econsultation -- psql -U postgres -d mca_db
```

## Service Debugging

```bash
# List all services
kubectl get services -n mca-econsultation

# Test internal DNS from inside a Pod
kubectl run dns-test --image=busybox:1.36 -n mca-econsultation --rm -it -- sh
nslookup mca-postgres-service
nslookup mca-ai-service
wget -q -O- http://mca-ai-service:5001/health

# Check endpoints (which Pods a Service routes to)
kubectl get endpoints -n mca-econsultation
```

## Ingress Debugging

```bash
# Check Ingress status
kubectl describe ingress mca-ingress -n mca-econsultation

# Check nginx Ingress Controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100

# Test from inside the cluster
kubectl run curl-test --image=curlimages/curl -n mca-econsultation --rm -it -- sh
curl http://mca-backend-service/actuator/health
```

## ConfigMap and Secret Debugging

```bash
# View ConfigMap values
kubectl describe configmap mca-backend-config -n mca-econsultation

# View Secret keys (not values — they are hidden)
kubectl describe secret mca-secrets -n mca-econsultation

# Decode a specific Secret value
kubectl get secret mca-secrets -n mca-econsultation \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode
```

## Resource Monitoring

```bash
# CPU and Memory of all Pods
kubectl top pods -n mca-econsultation

# CPU and Memory of all Nodes
kubectl top nodes

# HPA details (current metrics, desired replicas)
kubectl describe hpa mca-backend-hpa -n mca-econsultation
```

## Common Error → Fix

| Error | Cause | Fix |
|-------|-------|-----|
| `ImagePullBackOff` | Wrong image name or not pushed to DockerHub | Check `docker push` completed; verify username in deployment.yaml |
| `CrashLoopBackOff` | Container crashes on startup | Check `kubectl logs <pod>` for the error |
| `Pending` Pod | PVC not bound OR not enough resources | Check `kubectl get pvc`; increase Minikube memory |
| `Connection refused` AI service | Model still loading | Wait 90s; check `kubectl logs -l app=mca-ai-service` |
| HPA shows `<unknown>/70%` | metrics-server not running | `minikube addons enable metrics-server` |
| Ingress not routing | Minikube tunnel not running | Run `minikube tunnel` in separate terminal |
| `hosts` file not working | Need admin permission | Run editor as Administrator |
| Secret `not found` | Applied to wrong namespace | Add `-n mca-econsultation` to apply command |

---

# Quick Reference Card

## One-Line Start Commands

```bash
# Local (Phase 1)
python python-ai-service/ai_server.py &  &&  mvn spring-boot:run

# Docker Compose (Phase 3)
docker compose up --build

# Kubernetes — apply everything
kubectl apply -f k8s/namespace.yaml && \
kubectl apply -f k8s/storage/ && \
kubectl apply -f k8s/configmap.yaml && \
kubectl apply -f k8s/secret.yaml && \
kubectl apply -f k8s/backend/postgres.yaml && \
kubectl apply -f k8s/ai-service/ && \
kubectl apply -f k8s/backend/ && \
kubectl apply -f k8s/ingress/
```

## Service URLs

| Mode | URL |
|------|-----|
| Local | http://localhost:8080 |
| Docker Compose | http://localhost:8080 |
| Kubernetes | http://mca-econsultation.local |
| AI Service (local) | http://localhost:5001/health |
| AI Service (K8s internal) | http://mca-ai-service:5001/health |
