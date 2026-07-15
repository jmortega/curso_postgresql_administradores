#!/bin/bash
# =============================================================
# practica_02_rolling_update.sh
# Práctica 2: Rolling Update simulado con Patroni
# =============================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
LOG="/tmp/rolling_update_$(date +%Y%m%d_%H%M%S).log"

log()  { echo -e "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }
info() { log "${BLUE}INFO${NC}  $1"; }
ok()   { log "${GREEN}OK${NC}    $1"; }
warn() { log "${YELLOW}WARN${NC}  $1"; }
fail() { log "${RED}FAIL${NC}  $1"; exit 1; }

patroni_cmd() {
    docker exec pg-primary patronictl \
        -c /etc/patroni/patroni.yml "$@" 2>/dev/null
}

psql_primary() {
    docker exec pg-primary psql -U postgres -At -c "$1" 2>/dev/null
}

find_primary_container() {
    for C in pg-primary pg-replica1 pg-replica2; do
        local IS_PRI
        IS_PRI=$(docker exec "$C" psql -U postgres -At \
            -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo "f")
        [ "$IS_PRI" = "t" ] && echo "$C" && return
    done
    echo ""
}

wait_node_healthy() {
    local NODE="$1"
    local MAX=30
    info "  Esperando que $NODE vuelva al clúster..."
    for i in $(seq 1 $MAX); do
        STATE=$(patroni_cmd list --format json 2>/dev/null | \
            python3 -c "
import sys,json
data=json.load(sys.stdin)
for m in data:
    if m.get('Member')=='$NODE':
        print(m.get('State','unknown'))
" 2>/dev/null || echo "unknown")
        # FIX: las réplicas reportan 'streaming' (no 'running', que es
        # exclusivo del líder). Se acepta cualquier estado operativo:
        # 'running' para el líder y 'streaming'/'in archive recovery'
        # para réplicas.
        if [[ "$STATE" == "running" || "$STATE" == "streaming" ]]; then
            ok "  $NODE está $STATE"
            return 0
        fi
        sleep 3
        [ $((i % 5)) -eq 0 ] && info "  Intento $i/$MAX — estado: $STATE"
    done
    fail "$NODE no volvió sano en $((MAX*3))s"
}

echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   PRÁCTICA 2: Rolling Update con Patroni             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"

# ── Estado inicial ─────────────────────────────────────────────
info "Estado inicial del clúster:"
patroni_cmd list
echo ""

PRIMARY=$(patroni_cmd list --format json | \
    python3 -c "
import sys,json
for m in json.load(sys.stdin):
    if m.get('Role')=='Leader': print(m['Member']); break" 2>/dev/null)

[ -z "$PRIMARY" ] && fail "No se encontró el nodo primario"
info "Primario actual: ${BOLD}$PRIMARY${NC}"

REPLICAS=$(patroni_cmd list --format json | \
    python3 -c "
import sys,json
for m in json.load(sys.stdin):
    if m.get('Role')!='Leader': print(m['Member'])" 2>/dev/null)
info "Réplicas: $(echo $REPLICAS | tr '\n' ' ')"

# ── Verificar prerequisitos ────────────────────────────────────
info "Verificando prerequisitos..."
MAX_LAG=$(psql_primary "
    SELECT COALESCE(MAX(EXTRACT(epoch FROM replay_lag)::INT),0)
    FROM pg_stat_replication;")
[ "${MAX_LAG:-99}" -gt 15 ] && fail "Lag de replicación ${MAX_LAG}s > 15s"
ok "Lag de replicación: ${MAX_LAG}s"

LONG_TX=$(psql_primary "
    SELECT count(*) FROM pg_stat_activity
    WHERE xact_start IS NOT NULL
      AND now()-xact_start > INTERVAL '5 minutes'
      AND state!='idle';")
[ "${LONG_TX:-1}" -gt 0 ] && warn "Hay $LONG_TX transacciones largas activas"
ok "Prerequisitos verificados"

# ── Paso 1: Actualizar réplicas ────────────────────────────────
echo ""
echo -e "${BOLD}── PASO 1: Actualizar réplicas ──────────────────────────${NC}"

for REPLICA in $REPLICAS; do
    info "Procesando réplica: ${BOLD}$REPLICA${NC}"

    info "  Pausando Patroni en el clúster..."
    patroni_cmd pause pg-patch-cluster --wait 2>/dev/null || true

    info "  Reiniciando $REPLICA (simula actualización de binarios)..."
    RESTART_START=$(date +%s)
    docker restart "$REPLICA" 2>/dev/null
    RESTART_END=$(date +%s)
    info "  Reinicio completado en $((RESTART_END-RESTART_START))s"

    patroni_cmd resume pg-patch-cluster --wait 2>/dev/null || true
    ok "  Patroni reanudado"

    wait_node_healthy "$REPLICA"

    sleep 5
    CURR_LAG=$(psql_primary "
        SELECT COALESCE(MAX(EXTRACT(epoch FROM replay_lag)::INT),0)
        FROM pg_stat_replication
        WHERE application_name='$REPLICA';")
    ok "  Lag de $REPLICA tras reinicio: ${CURR_LAG}s"

    info "Esperando 15s antes del siguiente nodo..."
    sleep 15
done

ok "Réplicas actualizadas"

# ── Paso 2: Switchover controlado ─────────────────────────────
echo ""
echo -e "${BOLD}── PASO 2: Switchover controlado ─────────────────────────${NC}"

# FIX: con synchronous_mode: true, Patroni solo acepta como candidato
# de switchover al nodo que ACTUALMENTE está marcado "Sync Standby"
# (error 412 "candidate name does not match with sync_standby" si se
# fuerza un nombre distinto). Qué réplica es la síncrona puede variar
# entre ejecuciones, así que se detecta en vivo en vez de asumir
# "pgreplica1" fijo.
NEW_PRIMARY=$(patroni_cmd list --format json | \
    python3 -c "
import sys,json
for m in json.load(sys.stdin):
    if m.get('Role')=='Sync Standby': print(m['Member']); break" 2>/dev/null)

if [ -z "$NEW_PRIMARY" ]; then
    warn "No se encontró un Sync Standby explícito — usando la primera réplica listada"
    NEW_PRIMARY=$(echo "$REPLICAS" | awk '{print $1}')
fi

[ -z "$NEW_PRIMARY" ] && fail "No se pudo determinar un candidato para el switchover"

SWITCH_START=$(date +%s)
info "Ejecutando switchover hacia $NEW_PRIMARY (Sync Standby actual)..."

patroni_cmd switchover pg-patch-cluster \
    --master "$PRIMARY" \
    --candidate "$NEW_PRIMARY" \
    --scheduled now \
    --force 2>&1 | tee -a "$LOG"

info "Esperando que el switchover se complete..."
sleep 15

ACTUAL_PRIMARY=$(patroni_cmd list --format json | \
    python3 -c "
import sys,json
for m in json.load(sys.stdin):
    if m.get('Role')=='Leader': print(m['Member']); break" 2>/dev/null)

SWITCH_END=$(date +%s)
SWITCH_DURATION=$((SWITCH_END - SWITCH_START))

if [ "$ACTUAL_PRIMARY" = "$NEW_PRIMARY" ]; then
    ok "Switchover exitoso → nuevo primario: ${BOLD}$ACTUAL_PRIMARY${NC} (${SWITCH_DURATION}s)"
else
    warn "Primario actual: $ACTUAL_PRIMARY (esperado: $NEW_PRIMARY)"
fi

# ── Paso 3: Actualizar antiguo primario (ahora es réplica) ────
echo ""
echo -e "${BOLD}── PASO 3: Actualizar antiguo primario ($PRIMARY) ─────────${NC}"
info "Pausando Patroni..."
patroni_cmd pause pg-patch-cluster --wait 2>/dev/null || true

info "Reiniciando $PRIMARY..."
docker restart "$PRIMARY" 2>/dev/null

patroni_cmd resume pg-patch-cluster --wait 2>/dev/null || true
wait_node_healthy "$PRIMARY"

# ── Estado final ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   ROLLING UPDATE COMPLETADO                          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"

patroni_cmd list
echo ""

FINAL_PRIMARY=$(find_primary_container)
ok "Primario final: ${BOLD}$FINAL_PRIMARY${NC}"

docker exec "$FINAL_PRIMARY" psql -U postgres \
    -c "SELECT application_name, state, sync_state, replay_lag FROM pg_stat_replication;" \
    2>/dev/null

echo ""
info "Log guardado en: $LOG"
info "RTO del switchover: ${SWITCH_DURATION}s"
