#!/bin/bash
# =============================================================
# generar_certs.sh
# Genera todos los certificados SSL necesarios para el lab:
#   - CA autofirmada
#   - Certificado del servidor (PostgreSQL)
#   - Certificado del cliente (pguser)
#
# Uso: ./generar_certs.sh [--clean]
# =============================================================
set -euo pipefail

CERTS_DIR="./certs"
SERVER_CN="localhost"       # CN del servidor — debe coincidir con --host del script
CLIENT_CN="pguser"          # CN del cliente — debe coincidir con el usuario PostgreSQL
DAYS_CA=3650
DAYS_SERVER=825
DAYS_CLIENT=365

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${YELLOW}▸${NC} $1"; }

if [ "${1:-}" = "--clean" ]; then
    rm -rf "$CERTS_DIR"
    ok "Directorio $CERTS_DIR eliminado"
fi

mkdir -p "$CERTS_DIR"/{ca,server,client}

echo -e "\n${BOLD}════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Generación de certificados SSL — PostgreSQL Lab${NC}"
echo -e "${BOLD}════════════════════════════════════════════════${NC}\n"

# ── 1. CA ─────────────────────────────────────────────────────
info "1/3 Generando CA autofirmada..."

openssl genrsa -out "$CERTS_DIR/ca/ca.key" 4096 2>/dev/null
openssl req -new -x509 \
    -days $DAYS_CA \
    -key  "$CERTS_DIR/ca/ca.key" \
    -out  "$CERTS_DIR/ca/ca.crt" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=Lab/OU=DBA/CN=PostgreSQL-Lab-CA" \
    2>/dev/null

chmod 400 "$CERTS_DIR/ca/ca.key"
chmod 444 "$CERTS_DIR/ca/ca.crt"
ok "CA generada → $CERTS_DIR/ca/ca.crt"

# ── 2. Certificado del servidor ────────────────────────────────
info "2/3 Generando certificado del servidor (CN=$SERVER_CN)..."

openssl genrsa -out "$CERTS_DIR/server/server.key" 4096 2>/dev/null

openssl req -new \
    -key "$CERTS_DIR/server/server.key" \
    -out "$CERTS_DIR/server/server.csr" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=Lab/OU=DBA/CN=$SERVER_CN" \
    2>/dev/null

# SAN: necesario para verify-full con IP/hostname
cat > "$CERTS_DIR/server/server_ext.cnf" << EXTEOF
[req]
req_extensions = v3_req
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = postgres-ssl
IP.1  = 127.0.0.1
EXTEOF

openssl x509 -req \
    -days $DAYS_SERVER \
    -in    "$CERTS_DIR/server/server.csr" \
    -CA    "$CERTS_DIR/ca/ca.crt" \
    -CAkey "$CERTS_DIR/ca/ca.key" \
    -CAcreateserial \
    -out   "$CERTS_DIR/server/server.crt" \
    -extensions v3_req \
    -extfile "$CERTS_DIR/server/server_ext.cnf" \
    2>/dev/null

openssl verify -CAfile "$CERTS_DIR/ca/ca.crt" "$CERTS_DIR/server/server.crt" > /dev/null
# PostgreSQL exige 600 en la clave y que el propietario sea el proceso postgres
chmod 600 "$CERTS_DIR/server/server.key"
chmod 644 "$CERTS_DIR/server/server.crt"
ok "Certificado servidor → $CERTS_DIR/server/server.crt"

# ── 3. Certificado del cliente ────────────────────────────────
info "3/3 Generando certificado del cliente (CN=$CLIENT_CN)..."

openssl genrsa -out "$CERTS_DIR/client/client.key" 4096 2>/dev/null

openssl req -new \
    -key "$CERTS_DIR/client/client.key" \
    -out "$CERTS_DIR/client/client.csr" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=Lab/OU=App/CN=$CLIENT_CN" \
    2>/dev/null

openssl x509 -req \
    -days $DAYS_CLIENT \
    -in    "$CERTS_DIR/client/client.csr" \
    -CA    "$CERTS_DIR/ca/ca.crt" \
    -CAkey "$CERTS_DIR/ca/ca.key" \
    -CAcreateserial \
    -out   "$CERTS_DIR/client/client.crt" \
    2>/dev/null

openssl verify -CAfile "$CERTS_DIR/ca/ca.crt" "$CERTS_DIR/client/client.crt" > /dev/null
chmod 600 "$CERTS_DIR/client/client.key"
chmod 644 "$CERTS_DIR/client/client.crt"
ok "Certificado cliente → $CERTS_DIR/client/client.crt"

echo ""
echo -e "${BOLD}Estructura generada:${NC}"
find "$CERTS_DIR" -type f | sort | sed 's/^/  /'

echo ""
echo -e "${BOLD}Verificación de cadena de confianza:${NC}"
echo -n "  Servidor: "; openssl verify -CAfile "$CERTS_DIR/ca/ca.crt" "$CERTS_DIR/server/server.crt" 2>/dev/null
echo -n "  Cliente:  "; openssl verify -CAfile "$CERTS_DIR/ca/ca.crt" "$CERTS_DIR/client/client.crt" 2>/dev/null

echo ""
ok "Certificados listos. Ahora ejecuta: docker compose up -d"
