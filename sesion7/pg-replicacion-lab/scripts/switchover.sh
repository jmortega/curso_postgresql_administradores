#!/bin/bash
# =============================================================
# switchover.sh
# Realiza un switchover controlado (mantenimiento planificado)
# Promueve pg-standby1 a primario de forma ordenada
#
# Uso: ./scripts/switchover.sh [--target pg-standby1|pg-standby2]
# =============================================================

TARGET="${2:-pg-standby1}"
TARGET_PORT=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $1"; }
info() { log "${BLUE}INFO${NC}  $1"; }
ok()   { log "${GREEN}OK${NC}    $1"; }
warn() { log "${YELLOW}WARN${NC}  $1"; }
fail() { log "${RED}FAIL${NC}  $1"; exit 1; }

case "$TARGET" in
    pg-standby1) TARGET_PORT=5433 ;;
    pg-standby2) TARGET_PORT=5434 ;;
    *) fail "Target desconocido: $TARGET (opciones: pg-standby1, pg-standby2)" ;;
esac

echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Switchover Controlado → $TARGET${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

# ── Detectar primario actual ──────────────────────────────────
info "Detectando primario actual..."
CURRENT_PRIMARY=""
CURRENT_PORT=""

for PORT in 5432 5433 5434; do
    IS_PRIMARY=$(psql -h localhost -p "$PORT" -U postgres \
        -At -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo "f")
    if [ "$IS_PRIMARY" = "t" ]; then
        case "$PORT" in
            5432) CURRENT_PRIMARY="pg-primary" ;;
            5433) CURRENT_PRIMARY="pg-standby1" ;;
            5434) CURRENT_PRIMARY="pg-standby2" ;;
        esac
        CURRENT_PORT="$PORT"
        break
    fi
done

[ -z "$CURRENT_PRIMARY" ] && fail "No se encontró ningún primario"
[ "$CURRENT_PRIMARY" = "$TARGET" ] && {
    ok "$TARGET ya es el primario — nada que hacer"
    exit 0
}

ok "Primario actual: $CURRENT_PRIMARY (localhost:$CURRENT_PORT)"
info "Candidato a nuevo primario: $TARGET (localhost:$TARGET_PORT)"

# ── Verificar que el target está en streaming ────────────────
REPL_STATE=$(psql -h localhost -p "$CURRENT_PORT" -U postgres \
    -At -c "SELECT state FROM pg_stat_replication
            WHERE application_name='$TARGET'" 2>/dev/null || echo "?")

if [ "$REPL_STATE" != "streaming" ]; then
    warn "El standby $TARGET no está en streaming (estado: $REPL_STATE)"
    warn "Continuando de todas formas..."
fi

# ── Dry-run ───────────────────────────────────────────────────
info "Ejecutando dry-run del switchover..."
docker exec -u postgres "$TARGET" bash -c "
    PGPASSWORD=repmgr_lab \
    /usr/lib/postgresql/16/bin/repmgr \
        -f /etc/repmgr/repmgr.conf \
        standby switchover \
        --siblings-follow \
        --dry-run \
        --verbose 2>&1
" || warn "Dry-run con advertencias — revisar antes de continuar"

echo ""
read -rp "¿Continuar con el switchover? [y/N] " CONFIRM
[ "${CONFIRM,,}" != "y" ] && { info "Switchover cancelado"; exit 0; }

# ── Ejecutar switchover ───────────────────────────────────────
SWITCH_START=$(date +%s)
info "Ejecutando switchover..."

docker exec -u postgres "$TARGET" bash -c "
    PGPASSWORD=repmgr_lab \
    /usr/lib/postgresql/16/bin/repmgr \
        -f /etc/repmgr/repmgr.conf \
        standby switchover \
        --siblings-follow \
        --verbose 2>&1
"

SWITCH_END=$(date +%s)
SWITCH_DURATION=$((SWITCH_END - SWITCH_START))

# ── Verificar resultado ───────────────────────────────────────
sleep 5
NEW_ROLE=$(psql -h localhost -p "$TARGET_PORT" -U postgres \
    -At -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END" \
    2>/dev/null || echo "?")

if [ "$NEW_ROLE" = "PRIMARY" ]; then
    ok "═══ SWITCHOVER COMPLETADO en ${SWITCH_DURATION}s ═══"
    ok "$TARGET es ahora el PRIMARIO"
else
    fail "Switchover falló — $TARGET sigue como: $NEW_ROLE"
fi

# ── Estado final ──────────────────────────────────────────────
echo ""
info "Estado final del clúster:"
docker exec "$TARGET" \
    /usr/lib/postgresql/16/bin/repmgr \
    -f /etc/repmgr/repmgr.conf \
    cluster show 2>/dev/null || true
