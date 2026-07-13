#!/bin/bash
# =============================================================
# liveness_probe.sh
# Sonda de disponibilidad: ¿Está PostgreSQL vivo y respondiendo?
#
# Uso: ./liveness_probe.sh [host] [puerto] [usuario] [base_de_datos]
# Retorna: 0 = vivo | 1 = no responde
#
# Ejemplos:
#   ./liveness_probe.sh
#   ./liveness_probe.sh localhost 5432 postgres dwh
#   ./liveness_probe.sh localhost 5432 dwh_user dwh
# =============================================================
set -euo pipefail

PG_HOST="${1:-localhost}"
PG_PORT="${2:-5432}"
PG_USER="${3:-postgres}"
PG_DB="${4:-postgres}"
TIMEOUT=5
LOG="${PG_PROBE_LOG:-/var/log/pg_lab/probes.log}"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$DATE] LIVENESS $1" | tee -a "$LOG" 2>/dev/null || echo "[$DATE] LIVENESS $1"; }

# ── Comprobación 1: pg_isready (TCP + aceptación de conexiones) ──
if ! pg_isready \
        -h "$PG_HOST" \
        -p "$PG_PORT" \
        -U "$PG_USER" \
        -d "$PG_DB" \
        --timeout="$TIMEOUT" \
        -q 2>/dev/null; then
    log "FAIL: pg_isready no respondió en ${TIMEOUT}s en $PG_HOST:$PG_PORT"
    exit 1
fi

# ── Comprobación 2: SELECT 1 (verifica que SQL funciona) ─────────
RESULT=$(psql \
    -h "$PG_HOST" \
    -p "$PG_PORT" \
    -U "$PG_USER" \
    -d "$PG_DB" \
    -t -A \
    -c "SELECT 1" 2>/dev/null | tr -d ' \n') || RESULT=""

if [ "$RESULT" != "1" ]; then
    log "FAIL: SELECT 1 devolvió resultado inesperado ('$RESULT') en $PG_HOST:$PG_PORT"
    exit 1
fi

log "OK: $PG_HOST:$PG_PORT responde correctamente"
exit 0
