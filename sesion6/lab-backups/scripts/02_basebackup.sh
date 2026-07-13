#!/bin/bash
# =============================================================
# Script: 02_basebackup.sh
# Descripción: Backup físico con pg_basebackup
# Uso: ./02_basebackup.sh [plain|tar] [--compress 0-9]
#      La compresión solo se aplica si el formato es "tar"
# =============================================================
set -euo pipefail

BACKUP_ROOT="/backup/basebackup"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
FORMAT="${1:-plain}"
COMPRESS="${2:-9}"
LOG="/var/log/pg_scripts/backup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DATE_TAG=$(date '+%Y%m%d_%H%M%S')
DEST="$BACKUP_ROOT/$DATE_TAG"

log() { echo "[$DATE] $1" | tee -a "$LOG"; }

mkdir -p "$BACKUP_ROOT" "$(dirname "$LOG")"

log "INICIO: pg_basebackup --- formato=$FORMAT compress=$COMPRESS destino=$DEST"

PGBASEBACKUP_ARGS=(
  --host=localhost
  --port=5432
  --username=replicator
  --pgdata="$DEST"
  --format="$FORMAT"
  --wal-method=stream
  --checkpoint=fast
  --progress
  --verbose
)

# --compress solo es válido en formato tar
if [ "$FORMAT" = "tar" ]; then
  PGBASEBACKUP_ARGS+=(--compress="$COMPRESS")
fi

set +e
pg_basebackup "${PGBASEBACKUP_ARGS[@]}" 2>> "$LOG"
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  # Generar checksums
  find "$DEST" -type f | xargs sha256sum > "$DEST/checksums.sha256"
  SIZE=$(du -sh "$DEST" | cut -f1)
  log "PASS: backup completado --- tamaño=$SIZE ruta=$DEST"
else
  log "FAIL: pg_basebackup terminó con código $EXIT_CODE"
  exit 1
fi

# Eliminar backups más antiguos que RETENTION_DAYS
log "INFO: limpiando backups con más de $RETENTION_DAYS días"
find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d \
  -mtime +"$RETENTION_DAYS" \
  -exec rm -rf {} \; \
  -exec log "INFO: eliminado backup antiguo: {}" \;

log "FIN: proceso de backup finalizado"
