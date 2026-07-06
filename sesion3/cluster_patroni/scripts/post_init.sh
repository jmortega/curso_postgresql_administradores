#!/bin/bash
# post_init.sh — ejecutado por Patroni tras el bootstrap inicial
# Crea la base de datos appdb y permisos necesarios
set -euo pipefail

PGPASSWORD="${PATRONI_SUPERUSER_PASSWORD:-postgres_lab}"
export PGPASSWORD

log() { echo "[$(date '+%H:%M:%S')] [post_init] $*"; }

log "Creando base de datos appdb..."
psql -U postgres -c "CREATE DATABASE appdb OWNER appuser;" 2>/dev/null || \
    log "appdb ya existe"

psql -U postgres -d appdb -c "
    GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;
    GRANT ALL ON SCHEMA public TO appuser;
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
" 2>/dev/null || true

log "post_init completado"
