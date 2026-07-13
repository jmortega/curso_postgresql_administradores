#!/bin/bash
# =============================================================
# backup_fisico.sh
# Backup físico (base backup) con pg_basebackup para PITR.
#
# Uso:
#   ./backup_fisico.sh
#   RETENTION_DAYS=14 ./backup_fisico.sh
#
# Variables de entorno (con valores por defecto):
#   PG_HOST         → localhost
#   PG_PORT         → 5432
#   PG_USER         → replicator
#   BACKUP_DIR      → /backup/fisico
#   WAL_DIR         → /backup/wal_archive
#   RETENTION_DAYS  → 7
# =============================================================
set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-replicator}"
BACKUP_DIR="${BACKUP_DIR:-/backup/fisico}"
WAL_DIR="${WAL_DIR:-/backup/wal_archive}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
LOG="${BACKUP_LOG:-/var/log/pg_lab/backup.log}"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DATE_TAG=$(date '+%Y%m%d_%H%M%S')
DEST="$BACKUP_DIR/$DATE_TAG"

log() { echo "[$DATE] $1" | tee -a "$LOG" 2>/dev/null || echo "[$DATE] $1"; }

mkdir -p "$BACKUP_DIR" "$WAL_DIR" "$(dirname "$LOG")" 2>/dev/null || true

log "INICIO: pg_basebackup — host='$PG_HOST:$PG_PORT' destino='$DEST'"

# ── Ejecutar pg_basebackup ────────────────────────────────────────
pg_basebackup \
    --host="$PG_HOST" \
    --port="$PG_PORT" \
    --username="$PG_USER" \
    --pgdata="$DEST" \
    --wal-method=stream \
    --checkpoint=fast \
    --compress=9 \
    --progress \
    --verbose 2>> "$LOG"

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    log "FAIL: pg_basebackup terminó con código $EXIT_CODE"
    rm -rf "$DEST"
    exit 1
fi

# ── Verificar backup_label ────────────────────────────────────────
if [ -f "$DEST/backup_label" ]; then
    log "OK: backup_label presente"
    grep "START WAL LOCATION\|START TIME\|BACKUP FROM" "$DEST/backup_label" | \
        while IFS= read -r line; do log "INFO: $line"; done
else
    log "WARN: backup_label no encontrado — el backup puede ser incompleto"
fi

# ── Generar checksums de todos los ficheros ───────────────────────
find "$DEST" -type f | xargs sha256sum > "$DEST/checksums.sha256"
SIZE=$(du -sh "$DEST" | cut -f1)
log "OK: backup completado — $DEST ($SIZE)"

# ── Limpiar backups antiguos ──────────────────────────────────────
ELIMINADOS=$(find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d \
    -mtime +"$RETENTION_DAYS" | wc -l)
find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d \
    -mtime +"$RETENTION_DAYS" \
    -exec rm -rf {} \;
log "INFO: $ELIMINADOS backup(s) físicos eliminados (retención: ${RETENTION_DAYS} días)"

log "FIN: pg_basebackup completado exitosamente"
exit 0
