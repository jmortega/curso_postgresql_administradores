#!/usr/bin/env bash
# =============================================================================
# deploy-k8s.sh — Despliega el laboratorio PostgreSQL en Minikube
# Ejecutar desde cualquier directorio: ./postgres-lab/deploy-k8s.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/k8s"
NS="postgres-lab"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Comprobaciones ──────────────────────────────────────────
for cmd in minikube kubectl; do
  command -v "$cmd" >/dev/null 2>&1 \
    || error "$cmd no está instalado. Ejecuta primero: sudo ./install-prerequisites.sh"
done

info "Usando manifiestos desde: $K8S_DIR"

# ── Estado de Minikube ──────────────────────────────────────
if ! minikube status --format='{{.Host}}' 2>/dev/null | grep -q Running; then
  info "Iniciando Minikube (driver=docker, 4 CPUs, 4 GB RAM)..."
  minikube start \
    --driver=docker \
    --cpus=4 \
    --memory=4096 \
    --disk-size=20g \
    --kubernetes-version=stable
else
  info "Minikube ya está en ejecución. $(minikube status --format='Host: {{.Host}}')"
fi

# ── Habilitar addons ─────────────────────────────────────────
info "Habilitando addons de Minikube..."
minikube addons enable metrics-server    2>/dev/null || true
minikube addons enable ingress           2>/dev/null || true
minikube addons enable storage-provisioner 2>/dev/null || true

# ── Despliegue en orden ──────────────────────────────────────
info "Aplicando manifiestos de Kubernetes..."

apply() {
  local file="$1"
  info "  kubectl apply -f ${file#$SCRIPT_DIR/}"
  kubectl apply -f "$file"
}

apply "$K8S_DIR/00-namespace.yaml"
apply "$K8S_DIR/01-secrets.yaml"
apply "$K8S_DIR/postgres/postgres.yaml"
apply "$K8S_DIR/exporters/postgres-exporter.yaml"
apply "$K8S_DIR/exporters/node-exporter.yaml"
apply "$K8S_DIR/prometheus/prometheus.yaml"
apply "$K8S_DIR/grafana/grafana.yaml"
apply "$K8S_DIR/pgadmin/pgadmin.yaml"

# ── Esperar rollouts ─────────────────────────────────────────
info "Esperando que PostgreSQL esté listo (StatefulSet)..."
kubectl rollout status statefulset/postgres  -n "$NS" --timeout=180s

info "Esperando que postgres-exporter esté listo..."
kubectl rollout status deployment/postgres-exporter -n "$NS" --timeout=90s

info "Esperando que Prometheus esté listo..."
kubectl rollout status deployment/prometheus -n "$NS" --timeout=120s

info "Esperando que Grafana esté listo..."
kubectl rollout status deployment/grafana    -n "$NS" --timeout=120s

# ── IPs y URLs ───────────────────────────────────────────────
MINIKUBE_IP=$(minikube ip)
echo ""
echo "══════════════════════════════════════════════════════════"
echo " 🐘  PostgreSQL   →  ${MINIKUBE_IP}:30432  (pgadmin / pgadmin123)"
echo " 🔥  Prometheus   →  http://${MINIKUBE_IP}:30090"
echo " 📊  Grafana      →  http://${MINIKUBE_IP}:30300  (admin / admin123)"
echo " 🖥️   pgAdmin      →  http://${MINIKUBE_IP}:30050  (admin@lab.com / admin123)"
echo "══════════════════════════════════════════════════════════"
echo ""
info "Abrir servicios en el navegador automáticamente:"
echo "  minikube service grafana    -n $NS"
echo "  minikube service prometheus -n $NS"
echo ""
info "Port-forward alternativo (útil si NodePort no es accesible):"
echo "  kubectl port-forward svc/grafana    3000:3000 -n $NS &"
echo "  kubectl port-forward svc/prometheus 9090:9090 -n $NS &"
echo "  kubectl port-forward svc/pgadmin    5050:80   -n $NS &"
echo "  kubectl port-forward svc/postgres   5432:5432 -n $NS &"
echo ""
info "Ver estado del namespace:  kubectl get all -n $NS"
info "Destruir el entorno:       kubectl delete namespace $NS"
info "Detener Minikube:          minikube stop"
