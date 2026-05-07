# MCA eConsultation — Kubernetes Deployment Guide

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Docker Desktop | 24+ | Build images |
| Minikube | 1.32+ | Local Kubernetes cluster |
| kubectl | 1.28+ | Kubernetes CLI |

### Install Minikube (Windows)

```powershell
# Option 1: Using winget
winget install Kubernetes.minikube

# Option 2: Direct download
# Visit: https://minikube.sigs.k8s.io/docs/start/
# Download minikube-installer.exe and run it
```

### Install kubectl (Windows)

```powershell
# Option 1: winget
winget install Kubernetes.kubectl

# Option 2: With chocolatey
choco install kubernetes-cli

# Option 3: curl
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
# Move kubectl.exe to C:\Windows\System32\ or add to PATH
```

### Verify installations
```bash
minikube version    # minikube version: v1.32.x
kubectl version     # Client Version: v1.28.x
```

---

## Step 1 — Start Minikube

```bash
# Start with Docker driver (recommended for Windows/Mac)
minikube start --driver=docker --memory=6144 --cpus=4
# 6GB RAM and 4 CPUs recommended because:
#   - PyTorch model needs ~2GB RAM
#   - 2 backend Pods need ~1GB each
#   - Kubernetes overhead ~512MB

# Verify cluster is running
minikube status
```

**Expected output:**
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

---

## Step 2 — Enable Required Addons

```bash
# Enable nginx Ingress controller (REQUIRED for routing)
minikube addons enable ingress

# Enable metrics-server (REQUIRED for HPA)
minikube addons enable metrics-server

# Enable storage provisioner (for PV/PVC)
minikube addons enable storage-provisioner

# Verify addons
minikube addons list | grep -E "ingress|metrics|storage"
```

**Expected:**
```
| ingress                     | minikube | enabled ✅ |
| metrics-server              | minikube | enabled ✅ |
| storage-provisioner         | minikube | enabled ✅ |
```

---

## Step 3 — Push Images to DockerHub

> Minikube needs to pull images from a registry (DockerHub).
> Images only on your local machine won't work in Kubernetes.

```bash
# Build images
docker build -t YOUR_USERNAME/mca-backend:latest .
docker build -t YOUR_USERNAME/mca-ai-service:latest ./python-ai-service

# Login and push
docker login
docker push YOUR_USERNAME/mca-backend:latest
docker push YOUR_USERNAME/mca-ai-service:latest
```

> **Alternative for local testing only:** Use Minikube's Docker daemon:
```bash
eval $(minikube docker-env)        # Linux/Mac
minikube docker-env | Invoke-Expression   # Windows PowerShell

# Now build directly into Minikube's Docker
docker build -t mca-backend:latest .
docker build -t mca-ai-service:latest ./python-ai-service

# Set imagePullPolicy: Never in deployment.yaml to use local images
```

---

## Step 4 — Update Image Names in Manifests

Before applying, replace `YOUR_DOCKERHUB_USERNAME` in:
- `k8s/backend/deployment.yaml`
- `k8s/ai-service/deployment.yaml`

```yaml
# Example (k8s/backend/deployment.yaml):
image: akash123/mca-backend:latest    # Replace akash123 with your username
```

---

## Step 5 — Update Secrets

Encode your actual passwords:

```bash
# Windows PowerShell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("YourPassword123"))

# Linux/Mac
echo -n "YourPassword123" | base64
```

Edit `k8s/secret.yaml` and replace the base64 values.

---

## Step 6 — Deploy in Order

### 6a. Create namespace (FIRST — everything else goes inside it)
```bash
kubectl apply -f k8s/namespace.yaml

# Verify
kubectl get namespaces | grep mca
```

### 6b. Apply storage (PV must exist before PVC can bind)
```bash
kubectl apply -f k8s/storage/pv.yaml
kubectl apply -f k8s/storage/pvc.yaml

# Verify PVCs are Bound (not Pending)
kubectl get pv
kubectl get pvc -n mca-econsultation
```

**Expected PVC status:**
```
NAME                 STATUS   VOLUME              CAPACITY
mca-postgres-pvc     Bound    mca-postgres-pv     2Gi
mca-uploads-pvc      Bound    mca-uploads-pv      1Gi
mca-ai-static-pvc    Bound    mca-ai-static-pv    500Mi
```

### 6c. Apply ConfigMaps and Secrets
```bash
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# Verify
kubectl get configmaps -n mca-econsultation
kubectl get secrets -n mca-econsultation
```

### 6d. Deploy PostgreSQL (backend depends on it)
```bash
kubectl apply -f k8s/backend/postgres.yaml

# Wait for Postgres to be ready
kubectl rollout status deployment/mca-postgres -n mca-econsultation
kubectl get pods -n mca-econsultation | grep postgres
```

### 6e. Deploy AI Service
```bash
kubectl apply -f k8s/ai-service/deployment.yaml
kubectl apply -f k8s/ai-service/service.yaml

# Wait for AI service (model loading takes ~90s)
kubectl rollout status deployment/mca-ai-service -n mca-econsultation

# Check logs
kubectl logs -l app=mca-ai-service -n mca-econsultation
```

### 6f. Deploy Backend
```bash
kubectl apply -f k8s/backend/deployment.yaml
kubectl apply -f k8s/backend/service.yaml

# Wait for backend to be ready
kubectl rollout status deployment/mca-backend -n mca-econsultation
```

### 6g. Apply HPA
```bash
kubectl apply -f k8s/backend/hpa.yaml
kubectl apply -f k8s/ai-service/hpa.yaml

# Verify HPA
kubectl get hpa -n mca-econsultation
```

### 6h. Apply Ingress
```bash
kubectl apply -f k8s/ingress/ingress.yaml

# Verify Ingress
kubectl get ingress -n mca-econsultation
```

---

## Step 7 — Configure Hosts File

Get the Minikube IP:
```bash
minikube ip
# Example output: 192.168.49.2
```

Add entry to hosts file:

**Windows** (run Notepad as Administrator, open `C:\Windows\System32\drivers\etc\hosts`):
```
192.168.49.2   mca-econsultation.local
```

**Linux/Mac:**
```bash
echo "$(minikube ip) mca-econsultation.local" | sudo tee -a /etc/hosts
```

---

## Step 8 — Start Minikube Tunnel (for Ingress)

In a **separate terminal** (keep it running):
```bash
minikube tunnel
```

This gives Ingress a reachable external IP.

---

## Step 9 — Access Application

```
http://mca-econsultation.local
```

---

## Verification Commands

```bash
# See all resources in namespace
kubectl get all -n mca-econsultation

# See Pod status
kubectl get pods -n mca-econsultation

# See detailed Pod info (events, restarts, IPs)
kubectl describe pod <pod-name> -n mca-econsultation

# See Pod logs
kubectl logs <pod-name> -n mca-econsultation
kubectl logs -l app=mca-backend -n mca-econsultation   # By label

# See Services
kubectl get services -n mca-econsultation

# See HPA status (shows current/target CPU)
kubectl get hpa -n mca-econsultation -w    # -w = watch (live updates)

# See PVC binding status
kubectl get pvc -n mca-econsultation

# See ConfigMaps
kubectl describe configmap mca-backend-config -n mca-econsultation

# Get decoded secret value (for debugging)
kubectl get secret mca-secrets -n mca-econsultation -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode
```

---

## Teardown

```bash
# Delete all project resources (keeps Minikube running)
kubectl delete namespace mca-econsultation
# This deletes ALL resources inside the namespace

# Stop Minikube (saves state)
minikube stop

# Delete Minikube entirely (fresh start)
minikube delete
```
