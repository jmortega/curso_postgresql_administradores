#!/bin/bash
# =============================================================
# maintenance_vacuum.sh
# Ejecuta VACUUM ANALYZE en tablas con alto bloat y registra
# el resultado. Diseñado para lanzarse desde cron o pg_cron.
#
# Uso:
#   ./maintenance_vacuum.sh
#   PG_SCHEMA=raw PG_BLOAT_UMBRAL=10 ./maintenance_vacuum.sh
#
# Variables de entorno:
#   PG_HOST          → localhost
#   PG_PORT          → 5432
#   PG_USER          → postgres
#   PG_DB            → dwh
#   PG_SCHEMA        → public   (schema a mantener)
#   PG_BLOAT_UMBRAL  → 20       (% de filas muertas para actuar)
# =============================================================
set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-dwh}"
PG_SCHEMA="${PG_SCHEMA:-public}"
PG_BLOAT_UMBRAL="${PG_BLOAT_UMBRAL:-20}"
LOG="${MAINTENANCE_LOG:-/var/log/pg_lab/maintenance.log}"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$DATE] $1" | tee -a "$LOG" 2>/dev/null || echo "[$DATE] $1"; }

mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

log "========================================================"
log "INICIO: mantenimiento vacuum — schema='$PG_SCHEMA' umbral=${PG_BLOAT_UMBRAL}%"

# ── Obtener tablas candidatas a vacuum ────────────────────────────
TABLAS=$(psql \
    -h "$PG_HOST" -p "$PG_PORT" \
    -U "$PG_USER" -d "$PG_DB" \
    -t -A -F'|' \
    -c "
    SELECT schemaname, relname,
           n_dead_tup,
           ROUND(n_dead_tup * 100.0
               / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS pct_bloat
    FROM pg_stat_user_tables
    WHERE schemaname = '$PG_SCHEMA'
      AND n_dead_tup > 100
      AND ROUND(n_dead_tup * 100.0
          / NULLIF(n_live_tup + n_dead_tup, 0), 1) >= $PG_BLOAT_UMBRAL
    ORDER BY n_dead_tup DESC;" 2>/dev/null)

if [ -z "$TABLAS" ]; then
    log "INFO: ninguna tabla supera el umbral del ${PG_BLOAT_UMBRAL}% — sin acción necesaria"
    log "FIN: mantenimiento completado"
    exit 0
fi

PROCESADAS=0
FALLIDAS=0

# ── Ejecutar VACUUM ANALYZE en cada tabla candidata ──────────────
while IFS='|' read -r SCHEMA TABLA FILAS_MUERTAS PCT_BLOAT; do
    [ -z "$TABLA" ] && continue
    INICIO=$(date +%s%N)
    log "INFO: VACUUM ANALYZE ${SCHEMA}.${TABLA} (${FILAS_MUERTAS} filas muertas, ${PCT_BLOAT}% bloat)"

    if psql \
        -h "$PG_HOST" -p "$PG_PORT" \
        -U "$PG_USER" -d "$PG_DB" \
        -c "VACUUM ANALYZE ${SCHEMA}.${TABLA}" >> "$LOG" 2>&1; then
        FIN=$(date +%s%N)
        MS=$(( (FIN - INICIO) / 1000000 ))
        log "OK: VACUUM ANALYZE ${SCHEMA}.${TABLA} completado en ${MS}ms"
        PROCESADAS=$((PROCESADAS + 1))
    else
        log "FAIL: VACUUM ANALYZE ${SCHEMA}.${TABLA} falló"
        FALLIDAS=$((FALLIDAS + 1))
    fi
done <<< "$TABLAS"

# ── Revisar riesgo de Transaction ID Wraparound ───────────────────
log "INFO: comprobando riesgo de XID wraparound"
psql \
    -h "$PG_HOST" -p "$PG_PORT" \
    -U "$PG_USER" -d "$PG_DB" \
    -c "
    SELECT datname,
           age(datfrozenxid)                         AS xid_age,
           2100000000 - age(datfrozenxid)            AS xids_restantes,
           ROUND(age(datfrozenxid) * 100.0 / 2100000000, 2) AS pct_riesgo
    FROM pg_database
    ORDER BY xid_age DESC;" >> "$LOG" 2>/dev/null || true

log "========================================================"
log "RESUMEN: $PROCESADAS tabla(s) procesadas, $FALLIDAS fallo(s)"
log "FIN: mantenimiento vacuum completado"
log "========================================================"

[ "$FALLIDAS" -eq 0 ] && exit 0 || exit 1
