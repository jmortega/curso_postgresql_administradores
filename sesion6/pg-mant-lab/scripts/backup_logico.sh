#!/bin/bash
# =============================================================
# backup_logico.sh
# Backup lógico de una base de datos PostgreSQL con pg_dump.
#
# Uso:
#   ./backup_logico.sh
#   PG_DB=mi_bd ./backup_logico.sh
#
# Variables de entorno (con valores por defecto):
#   PG_HOST         → localhost
#   PG_PORT         → 5432
#   PG_USER         → postgres
#   PG_DB           → dwh
#   BACKUP_DIR      → /backup/logico
#   RETENTION_DAYS  → 30
# =============================================================
set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-dwh}"
BACKUP_DIR="${BACKUP_DIR:-/backup/logico}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
LOG="${BACKUP_LOG:-/var/log/pg_lab/backup.log}"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DATE_TAG=$(date '+%Y%m%d_%H%M%S')
DEST="$BACKUP_DIR/${PG_DB}_${DATE_TAG}.dump"

log() { echo "[$DATE] $1" | tee -a "$LOG" 2>/dev/null || echo "[$DATE] $1"; }

mkdir -p "$BACKUP_DIR" "$(dirname "$LOG")" 2>/dev/null || true

log "INICIO: backup lógico — base='$PG_DB' host='$PG_HOST:$PG_PORT'"

# ── Ejecutar pg_dump ──────────────────────────────────────────────
pg_dump \
    --host="$PG_HOST" \
    --port="$PG_PORT" \
    --username="$PG_USER" \
    --dbname="$PG_DB" \
    --format=custom \
    --compress=9 \
    --no-password \
    --file="$DEST" 2>> "$LOG"

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    log "FAIL: pg_dump terminó con código $EXIT_CODE"
    exit 1
fi

# ── Generar checksum ──────────────────────────────────────────────
sha256sum "$DEST" > "${DEST}.sha256"
SIZE=$(du -sh "$DEST" | cut -f1)
log "OK: backup creado — $DEST ($SIZE)"

# ── Verificar el dump es restaurable (cabecera) ───────────────────
if pg_restore --list "$DEST" &>/dev/null; then
    log "OK: estructura del dump verificada"
else
    log "WARN: no se pudo verificar la estructura del dump"
fi

# ── Limpiar backups antiguos ──────────────────────────────────────
ELIMINADOS=$(find "$BACKUP_DIR" -name "*.dump" -mtime +"$RETENTION_DAYS" | wc -l)
find "$BACKUP_DIR" -name "*.dump"   -mtime +"$RETENTION_DAYS" -delete
find "$BACKUP_DIR" -name "*.sha256" -mtime +"$RETENTION_DAYS" -delete
log "INFO: $ELIMINADOS backup(s) eliminados (retención: ${RETENTION_DAYS} días)"

log "FIN: backup lógico completado exitosamente"
exit 0
