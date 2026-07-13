#!/bin/bash
# =============================================================
# entrypoint.sh
# Inicializa PostgreSQL con pg_cron, usuario replicator y
# datos de prueba para el laboratorio de mantenimiento.
#
# FLUJO CORRECTO:
#   1. initdb (solo primera vez)
#   2. Aplicar configuración
#   3. Arrancar PostgreSQL en background con pg_ctl
#   4. Ejecutar init SQL (roles, extensiones, datos)
#   5. Detener el postgres temporal
#   6. exec postgres → proceso principal en foreground
# =============================================================
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PG_BIN="/usr/lib/postgresql/16/bin"
LOG_DIR="/var/log/pg_lab"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SETUP] $1"; }

mkdir -p "$LOG_DIR" /backup/logico /backup/fisico /backup/wal_archive

# ── 1. Inicializar PGDATA ─────────────────────────────────────
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

# ── 2. Aplicar configuración ──────────────────────────────────
log "Aplicando configuración..."
cp /etc/postgresql/postgresql.conf "$PGDATA/postgresql.conf"
cp /etc/postgresql/pg_hba.conf     "$PGDATA/pg_hba.conf"

# ── 3 & 4: Solo en primera ejecución, arrancar temporalmente
#    para aplicar el SQL de inicialización, luego parar.
if [ "$FIRST_RUN" = "true" ]; then
    log "Arrancando PostgreSQL (temporal para inicialización)..."
    "$PG_BIN/pg_ctl" start \
        -D "$PGDATA" \
        -o "-c config_file=$PGDATA/postgresql.conf" \
        -l "$LOG_DIR/startup.log" \
        -w -t 60
    log "PostgreSQL arrancado"

    # ── 4a. Crear usuario replicator ─────────────────────────
    psql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='replicator'" \
        | grep -q 1 || \
    psql -U postgres -c "
        CREATE ROLE replicator
            WITH REPLICATION LOGIN
            PASSWORD 'repl_lab_2025'
            CONNECTION LIMIT 5;"

    # ── 4b. Inicializar laboratorio (pg_cron + datos) ─────────
    log "Inicializando laboratorio..."
    psql -U postgres -f /scripts/init_lab.sql 2>&1 | \
        grep -E "NOTICE|ERROR|WARNING" || true

    log "═══════════════════════════════════════════════════════"
    log "Laboratorio listo │ Puerto: 5432 │ BD: dwh"
    log "  psql: docker exec -it pg-maint psql -U postgres -d dwh"
    log "═══════════════════════════════════════════════════════"

    # ── 5. Detener el postgres temporal limpiamente ───────────
    log "Deteniendo instancia temporal..."
    "$PG_BIN/pg_ctl" stop -D "$PGDATA" -m fast -w
fi

# ── 6. Arrancar postgres como proceso principal (foreground) ──
log "Arrancando PostgreSQL como proceso principal..."
exec "$PG_BIN/postgres" \
    -D "$PGDATA" \
    -c config_file="$PGDATA/postgresql.conf"
