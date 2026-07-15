#!/bin/bash
# =============================================================
# entrypoint.sh
# Inicializa PostgreSQL con toda la configuración del laboratorio
# de seguridad: roles, esquemas, datos, pgAudit, SSL y RLS.
#
# FLUJO:
#   1. Generar SSL
#   2. initdb (solo primera vez)
#   3. Aplicar configuración
#   4. Arrancar PostgreSQL temporal (solo primera vez)
#   5. Ejecutar init SQL
#   6. Detener postgres temporal (solo primera vez)
#   7. exec postgres → proceso principal en foreground
# =============================================================
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PG_BIN="/usr/lib/postgresql/16/bin"
LOG_DIR="/var/log/postgresql"
SSL_DIR="/etc/postgresql/ssl"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SETUP] $1"; }

mkdir -p "$LOG_DIR" "$SSL_DIR"

# ── 1. Generar certificados SSL si no existen ─────────────────
if [ ! -f "$SSL_DIR/server.crt" ]; then
    log "Generando certificados SSL autofirmados..."

    # CA
    openssl genrsa -out "$SSL_DIR/ca.key" 2048 2>/dev/null
    openssl req -new -x509 -days 3650 -key "$SSL_DIR/ca.key" \
        -out "$SSL_DIR/ca.crt" \
        -subj "/CN=PG-Security-Lab-CA/O=Lab/C=ES" 2>/dev/null

    # Certificado del servidor
    openssl genrsa -out "$SSL_DIR/server.key" 2048 2>/dev/null
    chmod 600 "$SSL_DIR/server.key"

    openssl req -new -key "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.csr" \
        -subj "/CN=pg-security/O=Lab/C=ES" 2>/dev/null

    cat > /tmp/server.ext << 'EXTEOF'
[v3_req]
subjectAltName = DNS:pg-security,DNS:localhost,IP:127.0.0.1
EXTEOF

    openssl x509 -req -days 365 \
        -in "$SSL_DIR/server.csr" \
        -CA "$SSL_DIR/ca.crt" \
        -CAkey "$SSL_DIR/ca.key" \
        -CAcreateserial \
        -out "$SSL_DIR/server.crt" \
        -extfile /tmp/server.ext \
        -extensions v3_req 2>/dev/null

    # Certificado cliente para dba_ana
    openssl genrsa -out "$SSL_DIR/client_dba.key" 2048 2>/dev/null
    openssl req -new -key "$SSL_DIR/client_dba.key" \
        -out "$SSL_DIR/client_dba.csr" \
        -subj "/CN=dba_ana/O=Lab/C=ES" 2>/dev/null
    openssl x509 -req -days 365 \
        -in "$SSL_DIR/client_dba.csr" \
        -CA "$SSL_DIR/ca.crt" \
        -CAkey "$SSL_DIR/ca.key" \
        -CAcreateserial \
        -out "$SSL_DIR/client_dba.crt" 2>/dev/null

    chmod 600 "$SSL_DIR"/*.key
    log "Certificados SSL generados OK"
fi

# ── 2. Inicializar PGDATA si está vacío ───────────────────────
FIRST_RUN=false
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    log "Inicializando PGDATA..."
    "$PG_BIN/initdb" \
        --pgdata="$PGDATA" \
        --username=postgres \
        --encoding=UTF8 \
        --locale=en_US.UTF-8 \
        --data-checksums \
        --auth-local=trust \
        --auth-host=scram-sha-256 \
        --pwfile=<(echo "${POSTGRES_PASSWORD:-postgres_lab}") 2>&1
    log "PGDATA inicializado"
    FIRST_RUN=true
fi

# ── 3. Copiar configuración ───────────────────────────────────
log "Aplicando configuración..."
cp /etc/postgresql/postgresql.conf "$PGDATA/postgresql.conf"
cp /etc/postgresql/pg_hba.conf     "$PGDATA/pg_hba.conf"

# ── 4 & 5 & 6: Solo en primera ejecución ─────────────────────
if [ "$FIRST_RUN" = "true" ]; then
    log "Arrancando PostgreSQL (temporal para inicialización)..."
    "$PG_BIN/pg_ctl" start \
        -D "$PGDATA" \
        -o "-c config_file=$PGDATA/postgresql.conf" \
        -l "$LOG_DIR/startup.log" \
        -w -t 60
    log "PostgreSQL arrancado"

    # ── 5. Inicializar el esquema del laboratorio ─────────────
    log "Creando estructura del laboratorio..."
    psql -U postgres -f /scripts/init_lab.sql 2>&1 | \
        grep -v "^$" | grep -v "^CREATE\|^ALTER\|^GRANT\|^REVOKE\|^INSERT\|^DO" || true

    log "═══════════════════════════════════════════════"
    log "Laboratorio de Seguridad listo"
    log "  Puerto: 5432"
    log "  BD principal: dwh"
    log "  Conectar: psql -h localhost -U postgres -d dwh"
    log "═══════════════════════════════════════════════"

    # ── 6. Detener el postgres temporal limpiamente ───────────
    log "Deteniendo instancia temporal..."
    "$PG_BIN/pg_ctl" stop -D "$PGDATA" -m fast -w
fi

# ── 7. Arrancar postgres como proceso principal (foreground) ──
log "Arrancando PostgreSQL como proceso principal..."
exec "$PG_BIN/postgres" \
    -D "$PGDATA" \
    -c config_file="$PGDATA/postgresql.conf"
