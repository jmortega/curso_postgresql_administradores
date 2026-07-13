#!/bin/bash
# =============================================================
# readiness_probe.sh
# Sonda de preparación: ¿Es seguro enviar tráfico de producción?
#
# Comprueba:
#   1. Liveness básica (pg_isready + SELECT 1)
#   2. Lag de réplica aceptable (si es standby)
#   3. % de conexiones activas bajo el umbral
#   4. Sin locks bloqueantes de larga duración
#   5. Autovacuum no saturado
#
# Uso: ./readiness_probe.sh [host] [puerto] [usuario] [base_de_datos]
# Retorna: 0 = listo | 1 = no listo
# =============================================================
set -euo pipefail

PG_HOST="${1:-localhost}"
PG_PORT="${2:-5432}"
PG_USER="${3:-postgres}"
PG_DB="${4:-postgres}"

MAX_LAG_SEGUNDOS="${PG_MAX_LAG:-30}"
MAX_CONEXIONES_PCT="${PG_MAX_CONN_PCT:-85}"
MAX_LOCK_WAIT_SEGUNDOS="${PG_MAX_LOCK_WAIT:-30}"

LOG="${PG_PROBE_LOG:-/var/log/pg_lab/probes.log}"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
FALLO=0

log()  { echo "[$DATE] READINESS $1" | tee -a "$LOG" 2>/dev/null || echo "[$DATE] READINESS $1"; }
warn() { log "WARN: $1"; }
fail() { log "FAIL: $1"; FALLO=1; }
ok()   { log "OK: $1"; }

# Helper: ejecutar una query y devolver el resultado (una sola celda)
psql_q() {
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" \
         -t -A -c "$1" 2>/dev/null || echo ""
}

# ── Comprobación 1: Liveness básica ──────────────────────────────
if ! pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -q 2>/dev/null; then
    log "FAIL: servidor no responde — abortando readiness check"
    exit 1
fi

RESULT=$(psql_q "SELECT 1" | tr -d ' \n')
if [ "$RESULT" != "1" ]; then
    fail "SELECT 1 devolvió resultado inesperado"
    exit 1
fi
ok "liveness básica superada"

# ── Comprobación 2: Recovery y lag de réplica ─────────────────────
IN_RECOVERY=$(psql_q "SELECT pg_is_in_recovery()")
if [ "$IN_RECOVERY" = "t" ]; then
    LAG=$(psql_q "
        SELECT COALESCE(
            EXTRACT(epoch FROM (now() - pg_last_xact_replay_timestamp()))::INT,
            0
        )")
    if [ -z "$LAG" ]; then LAG=0; fi

    if [ "$LAG" -gt "$MAX_LAG_SEGUNDOS" ]; then
        fail "réplica con lag de ${LAG}s (máximo permitido: ${MAX_LAG_SEGUNDOS}s)"
    else
        ok "réplica en recovery, lag=${LAG}s — dentro del límite de ${MAX_LAG_SEGUNDOS}s"
    fi
else
    ok "nodo primario (no en recovery)"
fi

# ── Comprobación 3: Uso de conexiones ────────────────────────────
CONEXIONES=$(psql_q "SELECT count(*) FROM pg_stat_activity WHERE state != 'idle'")
MAX_CONN=$(psql_q "SELECT current_setting('max_connections')::INT")
if [ -z "$CONEXIONES" ] || [ -z "$MAX_CONN" ] || [ "$MAX_CONN" -eq 0 ]; then
    warn "no se pudo obtener el conteo de conexiones"
else
    PCT=$(awk "BEGIN {printf \"%.0f\", $CONEXIONES * 100 / $MAX_CONN}")
    if [ "$PCT" -ge "$MAX_CONEXIONES_PCT" ]; then
        fail "conexiones al ${PCT}% del límite (${CONEXIONES}/${MAX_CONN})"
    else
        ok "conexiones ${CONEXIONES}/${MAX_CONN} (${PCT}%)"
    fi
fi

# ── Comprobación 4: Locks bloqueantes de larga duración ──────────
LOCKS_LARGOS=$(psql_q "
    SELECT count(*)
    FROM pg_locks l
    JOIN pg_stat_activity a ON a.pid = l.pid
    WHERE NOT l.granted
      AND a.query_start IS NOT NULL
      AND now() - a.query_start > INTERVAL '${MAX_LOCK_WAIT_SEGUNDOS} seconds'")

if [ -z "$LOCKS_LARGOS" ]; then LOCKS_LARGOS=0; fi

if [ "$LOCKS_LARGOS" -gt 0 ]; then
    warn "$LOCKS_LARGOS lock(s) en espera por más de ${MAX_LOCK_WAIT_SEGUNDOS}s"
else
    ok "sin locks bloqueantes de larga duración"
fi

# ── Comprobación 5: Saturación de autovacuum ─────────────────────
WORKERS_VACUUM=$(psql_q "
    SELECT count(*) FROM pg_stat_activity
    WHERE query LIKE 'autovacuum:%'")
MAX_WORKERS=$(psql_q "SELECT current_setting('autovacuum_max_workers')::INT")

if [ -n "$WORKERS_VACUUM" ] && [ -n "$MAX_WORKERS" ] && [ "$MAX_WORKERS" -gt 0 ]; then
    if [ "$WORKERS_VACUUM" -ge "$MAX_WORKERS" ]; then
        warn "autovacuum al límite (${WORKERS_VACUUM}/${MAX_WORKERS} workers activos)"
    else
        ok "autovacuum ${WORKERS_VACUUM}/${MAX_WORKERS} workers"
    fi
fi

# ── Resultado final ───────────────────────────────────────────────
if [ "$FALLO" -eq 0 ]; then
    log "RESULT: $PG_HOST:$PG_PORT LISTO para tráfico de producción"
    exit 0
else
    log "RESULT: $PG_HOST:$PG_PORT NO LISTO — ver detalles en $LOG"
    exit 1
fi
