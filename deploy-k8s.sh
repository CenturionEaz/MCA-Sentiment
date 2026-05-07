#!/usr/bin/env bash
# ============================================================
# deploy-k8s.sh — Linux/Mac Kubernetes Deploy Script
# ============================================================
# Usage:
#   chmod +x deploy-k8s.sh
#   ./deploy-k8s.sh             → Deploy everything
#   ./deploy-k8s.sh teardown    → Delete all resources
#   ./deploy-k8s.sh status      → Check current status
# ============================================================

set -e   # Exit on any error

NAMESPACE="mca-econsultation"
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

step() { echo -e "\n${CYAN}===> $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
err()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

# Check prerequisites
for cmd in kubectl minikube; do
  command -v "$cmd" >/dev/null 2>&1 || err "'$cmd' not found. Please install it first."
done

# ── Teardown ─────────────────────────────────────────────
if [ "$1" = "teardown" ]; then
  step "Tearing down all resources in namespace '$NAMESPACE'..."
  kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
  ok "Namespace '$NAMESPACE' deleted. All project resources removed."
  exit 0
fi

# ── Status ───────────────────────────────────────────────
if [ "$1" = "status" ]; then
  step "All resources in $NAMESPACE"
  kubectl get all -n "$NAMESPACE"
  step "PersistentVolumes"
  kubectl get pv
  step "PersistentVolumeClaims"
  kubectl get pvc -n "$NAMESPACE"
  step "HPA"
  kubectl get hpa -n "$NAMESPACE"
  step "Ingress"
  kubectl get ingress -n "$NAMESPACE"
  exit 0
fi

# ── Full Deploy ───────────────────────────────────────────
step "Checking Minikube..."
if ! minikube status | grep -q "Running"; then
  warn "Minikube not running. Starting..."
  minikube start --driver=docker --memory=6144 --cpus=4
fi
ok "Minikube is running."

step "Enabling addons..."
minikube addons enable ingress        2>/dev/null || true
minikube addons enable metrics-server 2>/dev/null || true
minikube addons enable storage-provisioner 2>/dev/null || true

step "1/8 — Creating namespace..."
kubectl apply -f k8s/namespace.yaml
ok "Namespace created."

step "2/8 — Applying storage..."
kubectl apply -f k8s/storage/pv.yaml
kubectl apply -f k8s/storage/pvc.yaml
echo "Waiting for PVCs to bind..."
sleep 5
kubectl get pvc -n "$NAMESPACE"

step "3/8 — Applying ConfigMaps and Secrets..."
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
ok "ConfigMaps and Secrets applied."

step "4/8 — Deploying PostgreSQL..."
kubectl apply -f k8s/backend/postgres.yaml
kubectl rollout status deployment/mca-postgres -n "$NAMESPACE" --timeout=120s
ok "PostgreSQL ready."

step "5/8 — Deploying AI Service..."
kubectl apply -f k8s/ai-service/deployment.yaml
kubectl apply -f k8s/ai-service/service.yaml
warn "AI Service model loading takes ~90 seconds..."
kubectl rollout status deployment/mca-ai-service -n "$NAMESPACE" --timeout=180s
ok "AI Service ready."

step "6/8 — Deploying Backend..."
kubectl apply -f k8s/backend/deployment.yaml
kubectl apply -f k8s/backend/service.yaml
kubectl rollout status deployment/mca-backend -n "$NAMESPACE" --timeout=180s
ok "Backend ready."

step "7/8 — Applying HPA..."
kubectl apply -f k8s/backend/hpa.yaml
kubectl apply -f k8s/ai-service/hpa.yaml
ok "HPA rules applied."

step "8/8 — Applying Ingress..."
kubectl apply -f k8s/ingress/ingress.yaml
ok "Ingress applied."

MINIKUBE_IP=$(minikube ip)

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Minikube IP: ${MINIKUBE_IP}${NC}"
echo ""
echo -e "${RED}ACTION REQUIRED — Add to /etc/hosts:${NC}"
echo -e "  sudo sh -c 'echo \"${MINIKUBE_IP}   mca-econsultation.local\" >> /etc/hosts'"
echo ""
echo -e "${YELLOW}Run in a separate terminal:${NC}"
echo -e "  minikube tunnel"
echo ""
echo -e "${GREEN}Then open:  http://mca-econsultation.local${NC}"
echo ""
kubectl get all -n "$NAMESPACE"
