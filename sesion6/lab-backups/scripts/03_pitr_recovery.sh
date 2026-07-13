#!/bin/bash
# =============================================================
# Script: 03_pitr_recovery.sh
# Descripción: Recuperación PITR a un punto en el tiempo dado
# Uso: ./03_pitr_recovery.sh "2025-09-01 11:44:59"
# =============================================================
set -euo pipefail

TARGET_TIME="${1:?Uso: $0 \"YYYY-MM-DD HH:MM:SS\"}"
BACKUP_ROOT="/backup/basebackup"
PGDATA="/data/patroni"
WAL_ARCHIVE="/mnt/wal_archive"
LOG="/var/log/pg_scripts/backup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$DATE] $1" | tee -a "$LOG"; }

# Obtener el backup más reciente
LATEST_BACKUP=$(ls -td "$BACKUP_ROOT"/*/ 2>/dev/null | head -1)
if [ -z "$LATEST_BACKUP" ]; then
  log "FAIL: no se encontró ningún base backup en $BACKUP_ROOT"
  exit 1
fi

log "INICIO: recuperación PITR hasta '$TARGET_TIME'"
log "INFO: usando backup $LATEST_BACKUP"

# Detener PostgreSQL si está activo (Patroni lo gestiona vía REST)
if pg_isready -h localhost -U postgres 2>/dev/null; then
  log "INFO: deteniendo PostgreSQL via pg_ctl"
  pg_ctl -D "$PGDATA" stop -m fast || true
fi

# Renombrar datos actuales como respaldo
if [ -d "$PGDATA" ]; then
  BACKUP_OLD="${PGDATA}_pre_recovery_$(date +%Y%m%d_%H%M%S)"
  log "INFO: renombrando PGDATA actual a $BACKUP_OLD"
  mv "$PGDATA" "$BACKUP_OLD"
fi

# Restaurar base backup
log "INFO: restaurando base backup..."
mkdir -p "$PGDATA"
rsync -a --info=progress2 "$LATEST_BACKUP"/ "$PGDATA"/
chown -R postgres:postgres "$PGDATA"

# Crear señal de recuperación (PostgreSQL 12+)
touch "$PGDATA/recovery.signal"

# Configurar restore_command y recovery_target_time
cat >> "$PGDATA/postgresql.auto.conf" << EOF

# === PITR Recovery Configuration ===
restore_command = 'cp $WAL_ARCHIVE/%f %p'
recovery_target_time = '$TARGET_TIME'
recovery_target_action = 'promote'
recovery_target_inclusive = true
EOF

log "INFO: configuración PITR escrita en postgresql.auto.conf"
log "INFO: iniciando PostgreSQL en modo recuperación..."

pg_ctl -D "$PGDATA" -l /var/log/pg_scripts/recovery.log start

log "INFO: monitorizando recuperación (máx. 5 min)..."
for i in $(seq 1 30); do
  sleep 10
  if pg_isready -h localhost -U postgres 2>/dev/null; then
    log "PASS: PostgreSQL disponible tras recuperación PITR"
    log "INFO: verificando datos recuperados..."
    psql -h localhost -U postgres -c "SELECT now(), pg_is_in_recovery();"
    log "FIN: recuperación PITR completada --- target='$TARGET_TIME'"
    exit 0
  fi
  log "INFO: esperando... intento $i/30"
done

log "FAIL: PostgreSQL no disponible después de 5 minutos"
exit 1
