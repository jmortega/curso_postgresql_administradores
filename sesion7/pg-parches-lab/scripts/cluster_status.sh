#!/bin/bash
# =============================================================
# cluster_status.sh
# Muestra el estado completo del clúster en tiempo real
# Uso: ./scripts/cluster_status.sh [--watch]
# =============================================================

WATCH_MODE=false
[ "${1:-}" = "--watch" ] && WATCH_MODE=true

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BLUE='\033[0;34m'; BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'

print_status() {
    local TS
    TS=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Estado del Clúster — $TS${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

    # ── Patroni list ────────────────────────────────────────────
    echo -e "\n${BLUE}▸ Patroni — clúster pg-patch-cluster:${NC}"
    docker exec pg-primary patronictl \
        -c /etc/patroni/patroni.yml list 2>/dev/null || \
        echo -e "  ${RED}(patroni no disponible)${NC}"

    # ── Roles de cada nodo ──────────────────────────────────────
    echo -e "\n${BLUE}▸ Rol de cada nodo:${NC}"
    for NODE_PORT in "pg-primary:5432" "pg-replica1:5433" "pg-replica2:5434"; do
        NODE="${NODE_PORT%%:*}"
        PORT="${NODE_PORT##*:}"
        if pg_isready -h localhost -p "$PORT" -q 2>/dev/null; then
            ROLE=$(psql -h localhost -p "$PORT" -U postgres -At \
                -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END" \
                2>/dev/null || echo "?")
            LAG=$(psql -h localhost -p "$PORT" -U postgres -At \
                -c "SELECT COALESCE(now()-pg_last_xact_replay_timestamp(),'0')" \
                2>/dev/null | head -1 || echo "?")
            if [ "$ROLE" = "PRIMARY" ]; then
                echo -e "  ${GREEN}● $NODE${NC} (localhost:$PORT) → ${GREEN}${BOLD}$ROLE${NC}"
            else
                echo -e "  ${YELLOW}● $NODE${NC} (localhost:$PORT) → ${YELLOW}$ROLE${NC} lag=${LAG}"
            fi
        else
            echo -e "  ${RED}✗ $NODE${NC} (localhost:$PORT) → ${RED}CAÍDO${NC}"
        fi
    done

    # ── HAProxy ─────────────────────────────────────────────────
    echo -e "\n${BLUE}▸ HAProxy:${NC}"
    for LABEL_PORT in "escritura:5000" "lectura:5001"; do
        LABEL="${LABEL_PORT%%:*}"
        PORT="${LABEL_PORT##*:}"
        if pg_isready -h localhost -p "$PORT" -q 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $LABEL (localhost:$PORT)"
        else
            echo -e "  ${RED}✗${NC} $LABEL (localhost:$PORT) no disponible"
        fi
    done

    # ── Replicación ─────────────────────────────────────────────
    echo -e "\n${BLUE}▸ Replicación (desde primario):${NC}"
    # Buscar el primario activo
    for PORT in 5432 5433 5434; do
        IS_PRI=$(psql -h localhost -p "$PORT" -U postgres -At \
            -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo "f")
        if [ "$IS_PRI" = "t" ]; then
            psql -h localhost -p "$PORT" -U postgres -c "
                SELECT
                    application_name AS standby,
                    state,
                    sync_state,
                    COALESCE(replay_lag::TEXT,'0') AS lag,
                    CASE
                        WHEN replay_lag < INTERVAL '5s' THEN '🟢'
                        WHEN replay_lag < INTERVAL '30s' THEN '🟡'
                        ELSE '🔴'
                    END AS semaforo
                FROM pg_stat_replication
                ORDER BY application_name;" 2>/dev/null || true
            break
        fi
    done

    # ── etcd ────────────────────────────────────────────────────
    echo -e "\n${BLUE}▸ etcd:${NC}"
    docker exec etcd etcdctl endpoint health 2>/dev/null | \
        sed 's/^/  /' || echo -e "  ${RED}(no disponible)${NC}"

    # ── pg-v15 ──────────────────────────────────────────────────
    echo -e "\n${BLUE}▸ pg-v15 (major upgrade lab):${NC}"
    if pg_isready -h localhost -p 5435 -q 2>/dev/null; then
        VER=$(psql -h localhost -p 5435 -U postgres -At \
            -c "SELECT current_setting('server_version')" 2>/dev/null || echo "?")
        echo -e "  ${GREEN}✓${NC} pg-v15 (localhost:5435) → PostgreSQL $VER"
    else
        echo -e "  ${YELLOW}⊘${NC} pg-v15 (localhost:5435) no disponible"
    fi

    echo -e "\n${BOLD}════════════════════════════════════════════════════${NC}\n"
}

if $WATCH_MODE; then
    while true; do clear; print_status; sleep 3; done
else
    print_status
fi
