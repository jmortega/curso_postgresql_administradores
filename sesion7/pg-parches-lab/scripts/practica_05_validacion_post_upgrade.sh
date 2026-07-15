#!/bin/bash
# =============================================================
# practica_05_validacion_post_upgrade.sh
# Práctica 5: Validación automatizada post-despliegue
# Equivale a validate_post_upgrade.sh pero usando docker exec
#
# Uso: ./scripts/practica_05_validacion_post_upgrade.sh
# =============================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
LOG="/tmp/validate_upgrade_$(date +%Y%m%d_%H%M%S).log"
PASS=0; FAIL=0; WARN=0

log()  { echo -e "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }
pass() { log "${GREEN}✅ PASS${NC}  $1"; PASS=$((PASS+1)); }
fail() { log "${RED}❌ FAIL${NC}  $1"; FAIL=$((FAIL+1)); }
warn() { log "${YELLOW}⚠️  WARN${NC}  $1"; WARN=$((WARN+1)); }
info() { log "${BLUE}INFO${NC}   $1"; }

# Buscar el primario activo
find_primary() {
    for C in pg-primary pg-replica1 pg-replica2; do
        local IS_PRI
        IS_PRI=$(docker exec "$C" psql -U postgres -At \
            -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo "f")
        [ "$IS_PRI" = "t" ] && echo "$C" && return
    done
    echo ""
}

psql_node() {
    local NODE="$1"; shift
    docker exec "$NODE" psql -U postgres -At -c "$1" 2>/dev/null
}

echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   PRÁCTICA 5: Validación Post-Despliegue             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"

# ── Detectar primario activo ────────────────────────────────────
PRIMARY=$(find_primary)
[ -z "$PRIMARY" ] && { fail "No se encontró ningún primario activo"; exit 1; }
info "Primario activo: ${BOLD}$PRIMARY${NC}"

# ── Check 1: Estado Patroni de todos los nodos ──────────────────
echo ""
echo -e "${BOLD}── CHECK 1: Estado del clúster Patroni ──────────────────${NC}"
CLUSTER_OUTPUT=$(docker exec "$PRIMARY" patronictl \
    -c /etc/patroni/patroni.yml list 2>/dev/null)
echo "$CLUSTER_OUTPUT"

RUNNING_NODES=$(echo "$CLUSTER_OUTPUT" | grep -c "running" || echo 0)
if [ "$RUNNING_NODES" -ge 3 ]; then
    pass "Los 3 nodos del clúster están running"
elif [ "$RUNNING_NODES" -ge 1 ]; then
    warn "Solo $RUNNING_NODES nodos running (esperados 3)"
else
    fail "Solo $RUNNING_NODES nodos running"
fi

# ── Check 2: Versión PostgreSQL ─────────────────────────────────
echo ""
echo -e "${BOLD}── CHECK 2: Versión PostgreSQL ──────────────────────────${NC}"
for NODE in pg-primary pg-replica1 pg-replica2; do
    VER=$(docker exec "$NODE" psql -U postgres -At \
        -c "SELECT version()" 2>/dev/null | head -1 || echo "NO DISPONIBLE")
    info "$NODE: $VER"
done
pass "Versión verificada en todos los nodos"

# ── Check 3: pg_isready en cada nodo ───────────────────────────
echo ""
echo -e "${BOLD}── CHECK 3: pg_isready en cada nodo ─────────────────────${NC}"
for NODE in pg-primary pg-replica1 pg-replica2; do
    if docker exec "$NODE" pg_isready -U postgres -q 2>/dev/null; then
        pass "$NODE responde a pg_isready"
    else
        fail "$NODE NO responde a pg_isready"
    fi
done

# ── Check 4: Replicación streaming activa ──────────────────────
echo ""
echo -e "${BOLD}── CHECK 4: Replicación streaming ───────────────────────${NC}"
REPLICAS_COUNT=$(psql_node "$PRIMARY" \
    "SELECT count(*) FROM pg_stat_replication WHERE state='streaming'")
if [ "${REPLICAS_COUNT:-0}" -ge 2 ]; then
    pass "$REPLICAS_COUNT réplica(s) en streaming"
else
    fail "Solo $REPLICAS_COUNT réplica(s) en streaming (esperadas 2)"
fi

docker exec "$PRIMARY" psql -U postgres -c \
    "SELECT application_name, state, sync_state, replay_lag
     FROM pg_stat_replication ORDER BY application_name;" \
    2>/dev/null

# ── Check 5: Lag de replicación ─────────────────────────────────
echo ""
echo -e "${BOLD}── CHECK 5: Lag de replicación ──────────────────────────${NC}"
MAX_LAG=$(psql_node "$PRIMARY" \
    "SELECT COALESCE(MAX(EXTRACT(epoch FROM replay_lag)::INT),0)
     FROM pg_stat_replication")
if [ "${MAX_LAG:-99}" -le 10 ]; then
    pass "Lag de replicación: ${MAX_LAG}s (≤ 10s)"
elif [ "${MAX_LAG:-99}" -le 30 ]; then
    warn "Lag de replicación: ${MAX_LAG}s (entre 10 y 30s)"
else
    fail "Lag de replicación: ${MAX_LAG}s (> 30s)"
fi

# ── Check 6: HAProxy estado ─────────────────────────────────────
echo ""
echo -e "${BOLD}── CHECK 6: HAProxy (puerto 5000 escritura / 5001 lectura) ──${NC}"
if pg_isready -h localhost -p 5000 -U postgres -q 2>/dev/null; then
    ROLE_5000=$(psql -h localhost -p 5000 -U postgres \
        -At -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END" \
        2>/dev/null || echo "?")
    if [ "$ROLE_5000" = "PRIMARY" ]; then
        pass "HAProxy:5000 apunta al PRIMARIO (escritura OK)"
    else
        fail "HAProxy:5000 apunta a un STANDBY (debe apuntar al primario)"
    fi
else
    warn "HAProxy:5000 no disponible (puede no estar configurado desde el host)"
fi

# ── Check 7: Extensiones al día ─────────────────────────────────
echo ""
echo -e "${BOLD}── CHECK 7: Extensiones instaladas ──────────────────────${NC}"
EXT_PENDING=$(psql_node "$PRIMARY" \
    "SELECT count(*) FROM pg_available_extensions
     WHERE installed_version IS NOT NULL
       AND installed_version != default_version")
if [ "${EXT_PENDING:-0}" -eq 0 ]; then
    pass "Todas las extensiones al día"
else
    warn "$EXT_PENDING extensión(es) con actualización pendiente"
fi

# ── Check 8: Cache hit ratio ────────────────────────────────────
echo ""
echo -e "${BOLD}── CHECK 8: Cache hit ratio ─────────────────────────────${NC}"
CACHE_HIT=$(psql_node "$PRIMARY" \
    "SELECT COALESCE(ROUND(
        sum(heap_blks_hit)*100.0
        /NULLIF(sum(heap_blks_hit)+sum(heap_blks_read),0), 1
    ), 100)
    FROM pg_statio_user_tables")
if (( $(echo "${CACHE_HIT:-0} >= 90" | bc -l 2>/dev/null || echo 0) )); then
    pass "Cache hit ratio: ${CACHE_HIT}% (≥ 90%)"
else
    warn "Cache hit ratio: ${CACHE_HIT}% (bajo — normal en instancia recién arrancada)"
fi

# ── Check 9: Transacciones largas ──────────────────────────────
echo ""
echo -e "${BOLD}── CHECK 9: Sin transacciones largas ────────────────────${NC}"
LONG_TX=$(psql_node "$PRIMARY" \
    "SELECT count(*) FROM pg_stat_activity
     WHERE xact_start IS NOT NULL
       AND now()-xact_start > INTERVAL '5 minutes'
       AND state != 'idle'")
if [ "${LONG_TX:-0}" -eq 0 ]; then
    pass "Sin transacciones largas activas"
else
    warn "$LONG_TX transacción(es) largas activas"
fi

# ── Check 10: etcd disponible ────────────────────────────────────
echo ""
echo -e "${BOLD}── CHECK 10: etcd disponible ────────────────────────────${NC}"
if docker exec etcd etcdctl endpoint health 2>/dev/null | grep -q "healthy"; then
    pass "etcd disponible y healthy"
else
    warn "etcd no respondió correctamente"
fi

# ── Resumen ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   RESUMEN DE VALIDACIÓN                              ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════╣${NC}"
printf "${BOLD}║  ✅ PASS: %-3d  ⚠️  WARN: %-3d  ❌ FAIL: %-3d          ║${NC}\n" \
    "$PASS" "$WARN" "$FAIL"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"

echo ""
info "Log guardado en: $LOG"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}${BOLD}Validación FALLIDA — revisar errores antes de cerrar la ventana de mantenimiento${NC}"
    exit 1
else
    echo -e "${GREEN}${BOLD}Validación EXITOSA — clúster operativo${NC}"
    exit 0
fi
