#!/bin/bash
# =============================================================
# Script: 04_validate_backup.sh
# Descripción: Valida el backup más reciente levantando una
#              instancia temporal en el puerto 5434
# =============================================================
set -euo pipefail

BACKUP_ROOT="/backup/basebackup"
PGDATA_TEST="/tmp/pg_validate_$(date +%Y%m%d_%H%M%S)"
PGPORT_TEST=5434
LOG="/var/log/pg_scripts/validate.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
PASS=0
FAIL=0

log()  { echo "[$DATE] $1" | tee -a "$LOG"; }
pass() { log "PASS: $1"; PASS=$((PASS+1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL+1)); }

mkdir -p "$(dirname "$LOG")"
log "INICIO: validación de backup ==========================="

# Obtener backup más reciente
BACKUP_PATH=$(ls -td "$BACKUP_ROOT"/*/ 2>/dev/null | head -1)
if [ -z "$BACKUP_PATH" ]; then
  fail "no se encontró ningún backup en $BACKUP_ROOT"
  exit 1
fi
log "INFO: validando backup en $BACKUP_PATH"

# 1. Verificar presencia de backup_label
if [ -f "$BACKUP_PATH/backup_label" ]; then
  pass "backup_label encontrado"
  cat "$BACKUP_PATH/backup_label" >> "$LOG"
else
  fail "backup_label ausente --- el backup puede estar incompleto"
fi

# 2. Verificar checksums de ficheros
if [ -f "$BACKUP_PATH/checksums.sha256" ]; then
  if (cd "$BACKUP_PATH" && sha256sum --check checksums.sha256 >> "$LOG" 2>&1); then
    pass "checksums SHA256 verificados correctamente"
  else
    fail "checksums SHA256 no coinciden"
  fi
else
  log "INFO: sin fichero checksums.sha256 --- omitiendo verificación de hash"
fi

# 3. Verificar checksums internos de PostgreSQL
if pg_checksums --check --pgdata "$BACKUP_PATH" >> "$LOG" 2>&1; then
  pass "pg_checksums internos OK"
else
  fail "pg_checksums detectó bloques corruptos"
fi

# 4. Arrancar instancia temporal
log "INFO: arrancando instancia temporal en puerto $PGPORT_TEST"
mkdir -p "$PGDATA_TEST"
rsync -a "$BACKUP_PATH"/ "$PGDATA_TEST"/

# Ajustar para instancia standalone (sin archivado, sin replicación)
cat >> "$PGDATA_TEST/postgresql.auto.conf" << EOF
archive_mode = off
hot_standby = on
port = $PGPORT_TEST
EOF

pg_ctl -D "$PGDATA_TEST" -o "-p $PGPORT_TEST" \
       -l /tmp/pg_validate_instance.log start

sleep 8

# 5. Comprobar conectividad
if pg_isready -p "$PGPORT_TEST" -U postgres 2>/dev/null; then
  pass "instancia temporal arrancó y acepta conexiones"
else
  fail "instancia temporal no responde"
  pg_ctl -D "$PGDATA_TEST" stop 2>/dev/null || true
  rm -rf "$PGDATA_TEST"
  exit 1
fi

# 6. Verificar integridad de catálogos
TABLE_COUNT=$(psql -p "$PGPORT_TEST" -U postgres -At \
  -c "SELECT count(*) FROM pg_class WHERE relkind='r';" 2>/dev/null || echo 0)
if [ "$TABLE_COUNT" -gt 0 ]; then
  pass "catálogo de tablas accesible --- $TABLE_COUNT tablas encontradas"
else
  fail "no se pudo consultar el catálogo de PostgreSQL"
fi

# 7. Listar bases de datos
log "INFO: bases de datos en el backup:"
psql -p "$PGPORT_TEST" -U postgres -c "\l" >> "$LOG" 2>&1

# Detener y limpiar instancia temporal
pg_ctl -D "$PGDATA_TEST" stop -m fast >> "$LOG" 2>&1
rm -rf "$PGDATA_TEST"
log "INFO: instancia temporal eliminada"

# Resumen
log "=== RESUMEN: $PASS pruebas pasadas, $FAIL fallos ==="
if [ "$FAIL" -eq 0 ]; then
  log "FIN: backup válido y restaurable"
  exit 0
else
  log "FIN: backup con $FAIL problema(s) --- revisar log"
  exit 1
fi
