#!/usr/bin/env bash
# =============================================================================
# start-lab.sh — Levanta el entorno Docker Compose del laboratorio PostgreSQL
# Ejecutar desde cualquier directorio: ./postgres-lab/start-lab.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Comprobaciones previas ──────────────────────────────────
command -v docker >/dev/null 2>&1 || error "Docker no está instalado. Ejecuta primero: sudo ./install-prerequisites.sh"

# Docker Compose v2 (plugin) o v1 (binario independiente)
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  error "Docker Compose no encontrado. Ejecuta primero: sudo ./install-prerequisites.sh"
fi

# ── Fichero .env ────────────────────────────────────────────
if [[ ! -f "$DOCKER_DIR/.env" ]]; then
  warning ".env no encontrado — copiando .env.example"
  cp "$DOCKER_DIR/.env.example" "$DOCKER_DIR/.env"
  info "Puedes editar $DOCKER_DIR/.env para cambiar contraseñas antes de continuar."
fi

# ── Crear directorio de dashboards si no existe ─────────────
mkdir -p "$SCRIPT_DIR/config/grafana/dashboards"

# ── Levantar servicios ──────────────────────────────────────
info "Levantando servicios con Docker Compose..."
cd "$DOCKER_DIR"
$COMPOSE up -d

# ── Esperar a que PostgreSQL esté listo ─────────────────────
info "Esperando a que PostgreSQL responda..."
for i in $(seq 1 30); do
  if $COMPOSE exec -T postgres pg_isready -U pgadmin -d labdb &>/dev/null; then
    info "PostgreSQL listo ✅"
    break
  fi
  if [[ $i -eq 30 ]]; then
    error "PostgreSQL no respondió en 60 s. Revisa los logs: cd docker && $COMPOSE logs postgres"
  fi
  sleep 2
done

# ── Estado de los contenedores ──────────────────────────────
echo ""
$COMPOSE ps
echo ""

# ── Resumen de URLs ──────────────────────────────────────────
echo "══════════════════════════════════════════════════════════"
echo " 🐘  PostgreSQL   →  localhost:5432  (pgadmin / pgadmin123)"
echo " 📊  Grafana      →  http://localhost:3000  (admin / admin123)"
echo " 🔥  Prometheus   →  http://localhost:9090"
echo " 🖥️   pgAdmin      →  http://localhost:5050  (admin@lab.local / pgadmin123)"
echo " 📈  pg_exporter  →  http://localhost:9187/metrics"
echo " 📈  node_export  →  http://localhost:9100/metrics"
echo "══════════════════════════════════════════════════════════"
echo ""
info "Para detener:             cd docker && $COMPOSE down"
info "Para detener + borrar datos: cd docker && $COMPOSE down -v"
info "Para ver logs:            cd docker && $COMPOSE logs -f [servicio]"
