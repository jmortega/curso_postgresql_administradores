#!/bin/bash
# =============================================================
# validate_backup.sh
# Valida el último backup físico levantando una instancia
# temporal de PostgreSQL en un puerto alternativo.
#
# Uso:
#   ./validate_backup.sh
#   BACKUP_DIR=/ruta/backups ./validate_backup.sh
#
# Variables de entorno:
#   BACKUP_DIR   → /backup/fisico
#   TEST_PORT    → 5454
#   PG_USER      → postgres
# =============================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backup/fisico}"
TEST_PORT="${TEST_PORT:-5454}"
PG_USER="${PG_USER:-postgres}"
TEST_DATA="/tmp/pg_validate_$(date '+%Y%m%d_%H%M%S')"
LOG="${VALIDATE_LOG:-/var/log/pg_lab/validate.log}"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
PASS=0
FAIL=0

log()  { echo "[$DATE] $1" | tee -a "$LOG" 2>/dev/null || echo "[$DATE] $1"; }
pass() { log "PASS: $1"; PASS=$((PASS + 1)); }
fail() { log "FAIL: $1"; FAIL=$((FAIL + 1)); }

mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

log "========================================================"
log "INICIO: validación de backup"

# ── Localizar el backup más reciente ─────────────────────────────
ULTIMO=$(ls -td "$BACKUP_DIR"/*/ 2>/dev/null | head -1 || echo "")
if [ -z "$ULTIMO" ]; then
    log "FAIL: no se encontró ningún backup en $BACKUP_DIR"
    exit 1
fi
log "INFO: validando backup en $ULTIMO"

# ── 1. Verificar backup_label ─────────────────────────────────────
if [ -f "$ULTIMO/backup_label" ]; then
    pass "backup_label presente"
    grep "START WAL LOCATION\|START TIME" "$ULTIMO/backup_label" >> "$LOG" 2>/dev/null || true
else
    fail "backup_label ausente — backup potencialmente incompleto"
fi

# ── 2. Verificar checksums SHA256 ─────────────────────────────────
if [ -f "$ULTIMO/checksums.sha256" ]; then
    if (cd "$ULTIMO" && sha256sum --check checksums.sha256 > /dev/null 2>&1); then
        pass "checksums SHA256 verificados correctamente"
    else
        fail "checksums SHA256 no coinciden — posible corrupción"
    fi
else
    log "INFO: sin fichero checksums.sha256 — omitiendo verificación de hash"
fi

# ── 3. Verificar checksums internos de PostgreSQL ─────────────────
if command -v pg_checksums &>/dev/null; then
    if pg_checksums --check --pgdata "$ULTIMO" > /dev/null 2>&1; then
        pass "pg_checksums internos OK"
    else
        fail "pg_checksums detectó bloques corruptos"
    fi
else
    log "INFO: pg_checksums no disponible — omitiendo verificación de bloques"
fi

# ── 4. Arrancar instancia temporal ────────────────────────────────
log "INFO: preparando instancia temporal en puerto $TEST_PORT"
mkdir -p "$TEST_DATA"
rsync -a "$ULTIMO"/ "$TEST_DATA"/ 2>/dev/null

# Ajustar configuración para instancia standalone
cat >> "$TEST_DATA/postgresql.auto.conf" << EOF
port             = $TEST_PORT
archive_mode     = off
hot_standby      = on
logging_collector = off
EOF

# Eliminar recovery.signal si existe (para que arranque como primario)
rm -f "$TEST_DATA/recovery.signal" "$TEST_DATA/standby.signal"

pg_ctl -D "$TEST_DATA" -o "-p $TEST_PORT" \
       -l /tmp/pg_val_instance.log start > /dev/null 2>&1
sleep 10

# ── 5. Comprobar conectividad ──────────────────────────────────────
if pg_isready -p "$TEST_PORT" -U "$PG_USER" -q 2>/dev/null; then
    pass "instancia temporal arrancó y acepta conexiones"
else
    fail "instancia temporal no responde en el puerto $TEST_PORT"
    pg_ctl -D "$TEST_DATA" stop -m immediate > /dev/null 2>&1 || true
    rm -rf "$TEST_DATA"
    log "RESUMEN: $PASS PASS / $FAIL FAIL — validación abortada"
    exit 1
fi

# ── 6. Verificar integridad del catálogo ──────────────────────────
TABLAS=$(psql -p "$TEST_PORT" -U "$PG_USER" -At \
    -c "SELECT count(*) FROM pg_class WHERE relkind='r'" 2>/dev/null || echo "0")
if [ "$TABLAS" -gt 0 ]; then
    pass "catálogo de tablas accesible ($TABLAS tablas)"
else
    fail "catálogo de PostgreSQL inaccesible"
fi

# ── 7. Listar bases de datos ───────────────────────────────────────
log "INFO: bases de datos en el backup:"
psql -p "$TEST_PORT" -U "$PG_USER" -c "\l" >> "$LOG" 2>/dev/null || true

# ── Detener y limpiar ─────────────────────────────────────────────
pg_ctl -D "$TEST_DATA" stop -m fast > /dev/null 2>&1 || true
rm -rf "$TEST_DATA"
log "INFO: instancia temporal eliminada"

# ── Resultado final ───────────────────────────────────────────────
log "========================================================"
log "RESUMEN: $PASS PASS / $FAIL FAIL"

if [ "$FAIL" -eq 0 ]; then
    log "RESULTADO: backup VÁLIDO y restaurable"
    log "========================================================"
    exit 0
else
    log "RESULTADO: backup con $FAIL PROBLEMA(S) — revisar log"
    log "========================================================"
    exit 1
fi
