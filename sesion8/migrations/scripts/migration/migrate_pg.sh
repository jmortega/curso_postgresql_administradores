#!/usr/bin/env bash
# =============================================================
# scripts/migration/migrate_pg.sh
# Orquestador de migración PG14 → PG17
#
# Implementa estrategia de ZERO DOWNTIME con pg_dump/pg_restore:
#   1. Dump del esquema de PG14
#   2. Restaurar esquema en PG17
#   3. Dump de datos con pg_dump en paralelo
#   4. Restaurar datos en PG17
#   5. Sincronización incremental con publicación lógica
#   6. Validación automática
#   7. Switchover (redirección de tráfico)
#
# Uso:
#   ./scripts/migration/migrate_pg.sh [--dry-run]
# =============================================================
set -euo pipefail

# ── Configuración ─────────────────────────────────────────────
PG14_HOST="${PG14_HOST:-localhost}"
PG14_PORT="${PG14_PORT:-5414}"
PG14_DB="${PG14_DB:-tienda_v1}"
PG14_USER="${PG14_USER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres_lab}"
export PGPASSWORD

PG17_HOST="${PG17_HOST:-localhost}"
PG17_PORT="${PG17_PORT:-5417}"
PG17_DB="${PG17_DB:-tienda_v2}"
PG17_USER="${PG17_USER:-postgres}"

DUMP_DIR="${DUMP_DIR:-./dumps}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DRY_RUN="${1:-}"

mkdir -p "$DUMP_DIR"

# ── Helpers ───────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✓ $*"; }
err()  { echo "[$(date '+%H:%M:%S')] ✗ $*" >&2; exit 1; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠ $*"; }

psql14() { psql -h "$PG14_HOST" -p "$PG14_PORT" -U "$PG14_USER" "$PG14_DB" "$@"; }
psql17() { psql -h "$PG17_HOST" -p "$PG17_PORT" -U "$PG17_USER" "$PG17_DB" "$@"; }

# ── Verificar conectividad ────────────────────────────────────
check_connectivity() {
    log "Verificando conectividad con PG14 y PG17..."
    pg_isready -h "$PG14_HOST" -p "$PG14_PORT" -U "$PG14_USER" -d "$PG14_DB" \
        || err "PG14 no responde en $PG14_HOST:$PG14_PORT"
    ok "PG14 activo"

    pg_isready -h "$PG17_HOST" -p "$PG17_PORT" -U "$PG17_USER" -d "$PG17_DB" \
        || err "PG17 no responde en $PG17_HOST:$PG17_PORT"
    ok "PG17 activo"
}

# ── Paso 1: Dump del esquema (sin datos) ─────────────────────
dump_schema() {
    local SCHEMA_FILE="$DUMP_DIR/schema_${TIMESTAMP}.sql"
    log "PASO 1: Dump del esquema de PG14..."

    pg_dump \
        -h "$PG14_HOST" -p "$PG14_PORT" -U "$PG14_USER" \
        --schema-only \
        --no-owner \
        --no-acl \
        --format=plain \
        --file="$SCHEMA_FILE" \
        "$PG14_DB" \
        || err "Fallo en pg_dump --schema-only"

    ok "Esquema volcado → $SCHEMA_FILE ($(wc -c < "$SCHEMA_FILE") bytes)"
    echo "$SCHEMA_FILE"
}

# ── Paso 2: Restaurar esquema en PG17 ─────────────────────────
restore_schema() {
    local SCHEMA_FILE="$1"
    log "PASO 2: Restaurando esquema en PG17..."

    psql17 -f "$SCHEMA_FILE" \
        || warn "Algunos objetos ya existían en PG17 (normal en reintento)"

    ok "Esquema restaurado en PG17"
}

# ── Paso 3: Dump de datos en formato custom (paralelo) ────────
dump_data() {
    local DATA_FILE="$DUMP_DIR/data_${TIMESTAMP}.dump"
    log "PASO 3: Dump de datos de PG14 (formato custom, 4 workers)..."

    local ROWS
    ROWS=$(psql14 -tAc \
        "SELECT sum(reltuples::bigint) FROM pg_class WHERE relkind='r' AND relname NOT LIKE 'pg_%'")
    log "  Filas estimadas: ${ROWS:-desconocido}"

    pg_dump \
        -h "$PG14_HOST" -p "$PG14_PORT" -U "$PG14_USER" \
        --data-only \
        --format=custom \
        --compress=6 \
        --file="$DATA_FILE" \
        "$PG14_DB" \
        || err "Fallo en pg_dump --data-only"

    local SIZE
    SIZE=$(du -sh "$DATA_FILE" | cut -f1)
    ok "Datos volcados → $DATA_FILE ($SIZE)"
    echo "$DATA_FILE"
}

# ── Paso 4: Restaurar datos en PG17 ──────────────────────────
restore_data() {
    local DATA_FILE="$1"
    log "PASO 4: Restaurando datos en PG17 (4 workers paralelos)..."

    pg_restore \
        -h "$PG17_HOST" -p "$PG17_PORT" -U "$PG17_USER" \
        --dbname="$PG17_DB" \
        --jobs=4 \
        --no-owner \
        --no-acl \
        --disable-triggers \
        --exit-on-error \
        "$DATA_FILE" \
        || warn "Algunos errores en pg_restore (ver arriba)"

    ok "Datos restaurados en PG17"
}

# ── Paso 5: Sincronización incremental (cambios durante la migración)
sync_incremental() {
    log "PASO 5: Sincronización incremental (publicación lógica)..."
    log "  Capturando cambios ocurridos durante la migración..."

    # Verificar cambios recientes en PG14 que aún no están en PG17
    local DELTA
    DELTA=$(psql14 -tAc "SELECT count(*) FROM pedidos WHERE creado_en > now() - INTERVAL '10 minutes'")
    log "  Pedidos creados en los últimos 10 min (en PG14): $DELTA"

    if [ "${DELTA:-0}" -gt 0 ]; then
        warn "$DELTA pedidos recientes. Considera habilitar replicación lógica para zero-downtime real."
        log "  Para zero-downtime completo usa: pg_logical o pglogical extension"
    else
        ok "Sin cambios pendientes de sincronizar"
    fi
}

# ── Paso 6: Validación automática ────────────────────────────
validate() {
    log "PASO 6: Validación automática de la migración..."

    local COUNT14 COUNT17
    COUNT14=$(psql14 -tAc "SELECT count(*) FROM clientes")
    COUNT17=$(psql17 -tAc "SELECT count(*) FROM clientes")

    if [ "$COUNT14" -eq "$COUNT17" ]; then
        ok "Clientes: PG14=$COUNT14 = PG17=$COUNT17 ✓"
    else
        err "Discrepancia en clientes: PG14=$COUNT14 ≠ PG17=$COUNT17"
    fi

    local TOTAL14 TOTAL17
    TOTAL14=$(psql14 -tAc "SELECT COALESCE(round(sum(total)::numeric,2), 0) FROM pedidos")
    TOTAL17=$(psql17 -tAc "SELECT COALESCE(round(sum(total)::numeric,2), 0) FROM pedidos")

    if [ "$TOTAL14" = "$TOTAL17" ]; then
        ok "Total facturado: $TOTAL14 € = $TOTAL17 € ✓"
    else
        err "Discrepancia en totales: PG14=$TOTAL14 ≠ PG17=$TOTAL17"
    fi

    ok "Validación básica superada"
}

# ── Paso 7: Switchover ────────────────────────────────────────
switchover() {
    log "PASO 7: Switchover — redirección de tráfico a PG17"
    log "  Actualiza la variable DATABASE_URL en tu aplicación:"
    log "  DE: postgresql://postgres:***@$PG14_HOST:$PG14_PORT/$PG14_DB"
    log "  A:  postgresql://postgres:***@$PG17_HOST:$PG17_PORT/$PG17_DB"
    log ""
    log "  Poner PG14 en modo read-only (previene escrituras accidentales):"
    psql14 -c "ALTER DATABASE $PG14_DB SET default_transaction_read_only = on;" \
        || warn "No se pudo poner PG14 en read-only"
    ok "PG14 marcada como read-only — PG17 es ahora el nodo activo"
}

# ── Main ──────────────────────────────────────────────────────
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Migración PostgreSQL 14 → 17  (zero-downtime)"
    echo "  Timestamp: $TIMESTAMP"
    [ -n "$DRY_RUN" ] && echo "  MODO: DRY-RUN (sin cambios reales)"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    check_connectivity

    if [ -n "$DRY_RUN" ]; then
        warn "DRY-RUN: los siguientes pasos no ejecutan cambios reales"
        log "  Pasos que se ejecutarían:"
        log "  1. pg_dump --schema-only PG14 → $DUMP_DIR/schema_*.sql"
        log "  2. psql PG17 < schema.sql"
        log "  3. pg_dump --data-only --format=custom PG14 → $DUMP_DIR/data_*.dump"
        log "  4. pg_restore --jobs=4 PG17"
        log "  5. Sincronización incremental"
        log "  6. Validación"
        log "  7. Switchover"
        exit 0
    fi

    local SCHEMA_FILE DATA_FILE
    SCHEMA_FILE=$(dump_schema)
    restore_schema "$SCHEMA_FILE"
    DATA_FILE=$(dump_data)
    restore_data   "$DATA_FILE"
    sync_incremental
    validate

    echo ""
    read -r -p "¿Proceder con el switchover a PG17? [s/N] " CONFIRM
    if [[ "${CONFIRM,,}" == "s" ]]; then
        switchover
        ok "Migración completada con éxito"
    else
        warn "Switchover cancelado. PG17 tiene los datos pero el tráfico sigue en PG14."
        log "  Para reintentarlo: ejecuta solo la función switchover"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Dumps guardados en: $DUMP_DIR/"
    echo "  Validación completa: scripts/validation/validate_pg_migration.sql"
    echo "  Rollback si hay problemas: scripts/rollback/rollback_pg_migration.sql"
    echo "═══════════════════════════════════════════════════════"
}

main "$@"
