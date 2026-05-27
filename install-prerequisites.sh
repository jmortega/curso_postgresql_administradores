#!/usr/bin/env bash
# =============================================================================
# install-prerequisites.sh
# Instala Docker, Docker Compose, kubectl y Minikube en Debian/Ubuntu/Mint
# Uso: sudo ./install-prerequisites.sh
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31f'; NC='\033[0m'
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && error "Ejecuta este script como root: sudo $0"

ARCH=$(dpkg --print-architecture)

# ── Detectar distro base ─────────────────────────────────────
# Linux Mint reporta ID=linuxmint pero necesita los repos de Ubuntu (ID_LIKE=ubuntu)
# Usamos ID_LIKE si existe, si no usamos ID
OS_ID=$(. /etc/os-release && echo "${ID_LIKE:-$ID}" | awk '{print $1}')
# Para el codename usamos UBUNTU_CODENAME si existe (Mint lo define), si no VERSION_CODENAME
OS_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")
[[ -z "$OS_CODENAME" ]] && OS_CODENAME=$(lsb_release -cs)

info "Distro base: $OS_ID  |  Codename: $OS_CODENAME  |  Arch: $ARCH"

# ── apt-get update ignorando errores de repos de terceros ────
# Se usa -o APT::Update::Error-Mode=any para que repos rotos (ej: Cursor sin GPG)
# no aborten la instalación. El warning sigue apareciendo pero no bloquea.
apt_update() {
  info "Actualizando lista de paquetes (errores de repos de terceros son ignorados)..."
  apt-get update -o APT::Update::Error-Mode=any 2>&1 \
    | grep -v "^W:\|^N:" || true
}

apt_update

apt-get install -y -qq \
  curl wget gnupg2 ca-certificates lsb-release \
  apt-transport-https software-properties-common \
  git jq bash-completion

# ══════════════════════════════════════════════════════════════
# 1. Docker Engine
# ══════════════════════════════════════════════════════════════
if command -v docker &>/dev/null; then
  info "Docker ya instalado: $(docker --version)"
else
  info "Instalando Docker Engine..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${OS_ID} ${OS_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt_update
  apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  systemctl enable --now docker
  info "Docker instalado: $(docker --version)"
fi

# Añadir usuario invocante al grupo docker
REAL_USER="${SUDO_USER:-$USER}"
if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
  usermod -aG docker "$REAL_USER"
  info "Usuario '$REAL_USER' añadido al grupo docker."
fi

# ══════════════════════════════════════════════════════════════
# 2. kubectl
# ══════════════════════════════════════════════════════════════
if command -v kubectl &>/dev/null; then
  info "kubectl ya instalado: $(kubectl version --client --short 2>/dev/null | head -1)"
else
  info "Instalando kubectl..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list

  apt_update
  apt-get install -y kubectl
  kubectl completion bash > /etc/bash_completion.d/kubectl
  info "kubectl instalado: $(kubectl version --client --short 2>/dev/null | head -1)"
fi

# ══════════════════════════════════════════════════════════════
# 3. Minikube
# ══════════════════════════════════════════════════════════════
if command -v minikube &>/dev/null; then
  info "Minikube ya instalado: $(minikube version --short)"
else
  info "Instalando Minikube..."
  curl -fsSL "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}" \
    -o /usr/local/bin/minikube
  chmod +x /usr/local/bin/minikube
  minikube completion bash > /etc/bash_completion.d/minikube
  info "Minikube instalado: $(minikube version --short)"
fi

# ══════════════════════════════════════════════════════════════
# 4. Cliente psql (PostgreSQL 17)
# ══════════════════════════════════════════════════════════════
if command -v psql &>/dev/null; then
  info "psql ya instalado: $(psql --version)"
else
  info "Instalando cliente PostgreSQL 17..."
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg
  echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] \
https://apt.postgresql.org/pub/repos/apt ${OS_CODENAME}-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
  apt_update
  apt-get install -y postgresql-client-17
  info "psql instalado: $(psql --version)"
fi

# ── Resumen ──────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════"
echo " ✅  Instalación completada"
echo "──────────────────────────────────────────────────────────"
printf " %-12s %s\n" "Docker:"   "$(docker --version 2>/dev/null || echo 'n/a')"
printf " %-12s %s\n" "kubectl:"  "$(kubectl version --client --short 2>/dev/null | head -1 || echo 'n/a')"
printf " %-12s %s\n" "Minikube:" "$(minikube version --short 2>/dev/null || echo 'n/a')"
printf " %-12s %s\n" "psql:"     "$(psql --version 2>/dev/null || echo 'n/a')"
echo "══════════════════════════════════════════════════════════"
echo ""
warning "Cierra y vuelve a abrir la sesión (o ejecuta 'newgrp docker') para activar el grupo docker."
echo ""
info "Para reparar el repo de Cursor (opcional, no afecta al laboratorio):"
echo "  sudo rm /etc/apt/sources.list.d/cursor*.list"
echo "  # Luego reinstala Cursor desde https://cursor.com"
