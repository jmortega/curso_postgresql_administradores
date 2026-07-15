#!/bin/bash
# =============================================================
# cluster_status.sh
# Muestra el estado completo del clúster desde fuera de Docker
# Uso: ./scripts/cluster_status.sh [--watch]
# =============================================================

WATCH_MODE=false
[ "${1:-}" = "--watch" ] && WATCH_MODE=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

print_status() {
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Estado del Clúster PostgreSQL — $TIMESTAMP${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

    # ── Contenedores ───────────────────────────────────────────
    echo -e "\n${BLUE}▸ Contenedores Docker:${NC}"
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" \
        2>/dev/null || echo "  (docker compose no disponible)"

    # ── Disponibilidad de nodos ────────────────────────────────
    echo -e "\n${BLUE}▸ Disponibilidad de nodos:${NC}"
    for HOST_PORT in "pg-primary:5432" "pg-standby1:5433" "pg-standby2:5434"; do
        NODE="${HOST_PORT%%:*}"
        PORT="${HOST_PORT##*:}"
        if pg_isready -h localhost -p "$PORT" -q 2>/dev/null; then
            ROLE=$(PGPASSWORD=postgres_lab psql -h localhost -p "$PORT" -U postgres \
                -At -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END" \
                2>/dev/null || echo "?")
            if [ "$ROLE" = "PRIMARY" ]; then
                echo -e "  ${GREEN}✓${NC} $NODE (localhost:$PORT) → ${GREEN}${BOLD}$ROLE${NC}"
            else
                echo -e "  ${GREEN}✓${NC} $NODE (localhost:$PORT) → ${YELLOW}$ROLE${NC}"
            fi
        else
            echo -e "  ${RED}✗${NC} $NODE (localhost:$PORT) → ${RED}NO DISPONIBLE${NC}"
        fi
    done

    # ── Replicación desde el primario ──────────────────────────
    echo -e "\n${BLUE}▸ Replicación (desde primario):${NC}"
    PRIMARY_PORT=""
    for PORT in 5432 5433 5434; do
        IS_PRIMARY=$(PGPASSWORD=postgres_lab psql -h localhost -p "$PORT" -U postgres \
            -At -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo "f")
        [ "$IS_PRIMARY" = "t" ] && PRIMARY_PORT="$PORT" && break
    done

    if [ -n "$PRIMARY_PORT" ]; then
        # FIX: replay_lag es NULL cuando el standby está al día y no hay
        # actividad reciente — no significa desconexión. El semáforo correcto
        # usa write_lag/flush_lag/replay_lag y el estado 'streaming'.
        PGPASSWORD=postgres_lab psql -h localhost -p "$PRIMARY_PORT" -U postgres -c "
            SELECT
                application_name                                    AS standby,
                client_addr                                         AS ip,
                state,
                sync_state,
                COALESCE(
                    extract(epoch FROM replay_lag)::TEXT || 's',
                    '0s'
                )                                                   AS lag,
                CASE
                    WHEN state != 'streaming'
                        THEN '🔴 desconectado'
                    WHEN replay_lag > INTERVAL '30s'
                        THEN '🟡 lag elevado'
                    ELSE '🟢 ok'
                END                                                 AS estado
            FROM pg_stat_replication
            ORDER BY application_name;" 2>/dev/null || \
        echo "  (no hay standbys conectados)"
    else
        echo -e "  ${RED}No se encontró ningún primario activo${NC}"
    fi

    # ── Estado repmgr ─────────────────────────────────────────
    echo -e "\n${BLUE}▸ Estado repmgr:${NC}"
    # FIX: repmgr necesita PGPASSWORD para conectar a la BD repmgr
    docker exec -u postgres pg-primary bash -c "
        PGPASSWORD=repmgr_lab \
        /usr/lib/postgresql/16/bin/repmgr \
        -f /etc/repmgr/repmgr.conf \
        cluster show" 2>/dev/null || \
    echo "  (repmgr no disponible — comprobar: docker exec pg-primary repmgr -f /etc/repmgr/repmgr.conf cluster show)"

    # ── Lag en bytes ──────────────────────────────────────────
    if [ -n "$PRIMARY_PORT" ]; then
        echo -e "\n${BLUE}▸ Lag en bytes:${NC}"
        PGPASSWORD=postgres_lab psql -h localhost -p "$PRIMARY_PORT" -U postgres -c "
            SELECT
                application_name                                AS standby,
                pg_size_pretty(
                    pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn)
                )                                               AS lag_bytes,
                sync_state
            FROM pg_stat_replication
            ORDER BY application_name;" 2>/dev/null || true
    fi

    echo -e "\n${BOLD}════════════════════════════════════════════════════${NC}\n"
}

if $WATCH_MODE; then
    while true; do clear; print_status; sleep 3; done
else
    print_status
fi
