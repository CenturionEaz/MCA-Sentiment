# ============================================================
# deploy-k8s.ps1 — Windows PowerShell Kubernetes Deploy Script
# ============================================================
# Usage:
#   .\deploy-k8s.ps1              → Deploy everything
#   .\deploy-k8s.ps1 -Teardown    → Delete all resources
#   .\deploy-k8s.ps1 -Status      → Check current status
# ============================================================

param(
    [switch]$Teardown,
    [switch]$Status
)

$NAMESPACE = "mca-econsultation"

function Write-Step {
    param([string]$msg)
    Write-Host ""
    Write-Host "===> $msg" -ForegroundColor Cyan
}

function Check-Command {
    param([string]$cmd)
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$cmd' is not installed or not in PATH" -ForegroundColor Red
        exit 1
    }
}

# ── Check prerequisites ──────────────────────────────────
Check-Command "kubectl"
Check-Command "minikube"

# ── Teardown mode ────────────────────────────────────────
if ($Teardown) {
    Write-Step "Tearing down all Kubernetes resources..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    Write-Host "Done. Namespace '$NAMESPACE' and all resources deleted." -ForegroundColor Green
    exit 0
}

# ── Status mode ──────────────────────────────────────────
if ($Status) {
    Write-Step "Current status of $NAMESPACE namespace"
    kubectl get all -n $NAMESPACE
    Write-Host ""
    Write-Step "PersistentVolumes"
    kubectl get pv
    Write-Host ""
    Write-Step "PersistentVolumeClaims"
    kubectl get pvc -n $NAMESPACE
    Write-Host ""
    Write-Step "HPA"
    kubectl get hpa -n $NAMESPACE
    Write-Host ""
    Write-Step "Ingress"
    kubectl get ingress -n $NAMESPACE
    exit 0
}

# ── Full Deploy ───────────────────────────────────────────
Write-Step "Checking Minikube status..."
$status = minikube status --format='{{.Host}}' 2>$null
if ($status -ne "Running") {
    Write-Host "Minikube is not running. Starting it..." -ForegroundColor Yellow
    minikube start --driver=docker --memory=6144 --cpus=4
}

Write-Step "Enabling required addons..."
minikube addons enable ingress 2>$null
minikube addons enable metrics-server 2>$null
minikube addons enable storage-provisioner 2>$null

Write-Step "Step 1/8 — Creating namespace..."
kubectl apply -f k8s/namespace.yaml

Write-Step "Step 2/8 — Applying storage (PV + PVC)..."
kubectl apply -f k8s/storage/pv.yaml
kubectl apply -f k8s/storage/pvc.yaml

Write-Host "Waiting for PVCs to bind..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
kubectl get pvc -n $NAMESPACE

Write-Step "Step 3/8 — Applying ConfigMaps and Secrets..."
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

Write-Step "Step 4/8 — Deploying PostgreSQL..."
kubectl apply -f k8s/backend/postgres.yaml
Write-Host "Waiting for PostgreSQL rollout..." -ForegroundColor Yellow
kubectl rollout status deployment/mca-postgres -n $NAMESPACE --timeout=120s

Write-Step "Step 5/8 — Deploying AI Service..."
kubectl apply -f k8s/ai-service/deployment.yaml
kubectl apply -f k8s/ai-service/service.yaml
Write-Host "Waiting for AI Service rollout (model loading takes ~90s)..." -ForegroundColor Yellow
kubectl rollout status deployment/mca-ai-service -n $NAMESPACE --timeout=180s

Write-Step "Step 6/8 — Deploying Backend..."
kubectl apply -f k8s/backend/deployment.yaml
kubectl apply -f k8s/backend/service.yaml
Write-Host "Waiting for Backend rollout..." -ForegroundColor Yellow
kubectl rollout status deployment/mca-backend -n $NAMESPACE --timeout=180s

Write-Step "Step 7/8 — Applying HPA rules..."
kubectl apply -f k8s/backend/hpa.yaml
kubectl apply -f k8s/ai-service/hpa.yaml

Write-Step "Step 8/8 — Applying Ingress..."
kubectl apply -f k8s/ingress/ingress.yaml

# ── Summary ───────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

$minikubeIp = minikube ip
Write-Host "Minikube IP: $minikubeIp" -ForegroundColor Yellow
Write-Host ""
Write-Host "ACTION REQUIRED — Add to hosts file (as Administrator):" -ForegroundColor Red
Write-Host "  $minikubeIp   mca-econsultation.local" -ForegroundColor White
Write-Host ""
Write-Host "Then run in a separate terminal:" -ForegroundColor Yellow
Write-Host "  minikube tunnel" -ForegroundColor White
Write-Host ""
Write-Host "Then open:  http://mca-econsultation.local" -ForegroundColor Green
Write-Host ""

kubectl get all -n $NAMESPACE
