#!/bin/bash
# =============================================================
# monitor_lag.sh
# Monitoriza el lag de replicación en tiempo real
# con histórico y alertas visuales
#
# Uso: ./scripts/monitor_lag.sh [intervalo_segundos]
# =============================================================

INTERVAL="${1:-3}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
CYAN='\033[0;36m'
NC='\033[0m'

# Encontrar el puerto del primario activo
find_primary_port() {
    for PORT in 5432 5433 5434; do
        IS_PRIMARY=$(psql -h localhost -p "$PORT" -U postgres \
            -At -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo "f")
        [ "$IS_PRIMARY" = "t" ] && echo "$PORT" && return
    done
    echo ""
}

echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Monitor de Replicación — Intervalo: ${INTERVAL}s${NC}"
echo -e "${BOLD}  Ctrl+C para salir${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

LAG_HISTORY=()

while true; do
    clear
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    PRIMARY_PORT=$(find_primary_port)

    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Monitor de Replicación — $TIMESTAMP${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

    if [ -z "$PRIMARY_PORT" ]; then
        echo -e "\n  ${RED}✗ No se encontró ningún primario activo${NC}\n"
    else
        # Determinar nombre del nodo primario
        case "$PRIMARY_PORT" in
            5432) PRIMARY_NAME="pg-primary" ;;
            5433) PRIMARY_NAME="pg-standby1" ;;
            5434) PRIMARY_NAME="pg-standby2" ;;
        esac

        echo -e "\n  ${GREEN}● PRIMARIO:${NC} ${BOLD}$PRIMARY_NAME${NC} (localhost:$PRIMARY_PORT)"
        echo -e "  LSN: $(psql -h localhost -p "$PRIMARY_PORT" -U postgres \
            -At -c 'SELECT pg_current_wal_lsn()' 2>/dev/null || echo '?')"

        echo -e "\n${BLUE}  ── Standbys conectados ───────────────────────────${NC}"

        # Header tabla
        printf "  ${BOLD}%-15s %-12s %-12s %-10s %-12s${NC}\n" \
            "STANDBY" "ESTADO" "SYNC" "LAG" "LAG (bytes)"

        # Datos de replicación
        while IFS='|' read -r APP STATE SYNC LAG_MS LAG_BYTES; do
            # Colorear según el lag
            LAG_COLOR="$GREEN"
            STATUS_ICON="🟢"
            LAG_NUM="${LAG_MS//[^0-9.]/}"
            if [ -n "$LAG_NUM" ] && (( $(echo "$LAG_NUM > 10000" | bc -l 2>/dev/null || echo 0) )); then
                LAG_COLOR="$RED"
                STATUS_ICON="🔴"
            elif [ -n "$LAG_NUM" ] && (( $(echo "$LAG_NUM > 1000" | bc -l 2>/dev/null || echo 0) )); then
                LAG_COLOR="$YELLOW"
                STATUS_ICON="🟡"
            fi

            printf "  %-15s %-12s %-12s ${LAG_COLOR}%-10s %-12s${NC}\n" \
                "$STATUS_ICON $APP" "$STATE" "$SYNC" "${LAG_MS}ms" "$LAG_BYTES"
        done < <(psql -h localhost -p "$PRIMARY_PORT" -U postgres -At -F'|' -c "
            SELECT
                application_name,
                state,
                sync_state,
                COALESCE(
                    (EXTRACT(epoch FROM replay_lag)*1000)::INT::TEXT,
                    '?'
                ),
                COALESCE(pg_size_pretty(
                    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
                ), '?')
            FROM pg_stat_replication
            ORDER BY application_name;" 2>/dev/null || true)

        # Detectar standbys desconectados
        CONNECTED=$(psql -h localhost -p "$PRIMARY_PORT" -U postgres \
            -At -c "SELECT count(*) FROM pg_stat_replication" 2>/dev/null || echo 0)
        if [ "$CONNECTED" -lt 2 ]; then
            echo -e "\n  ${RED}⚠ ALERTA: Solo $CONNECTED standby(s) conectados (esperados: 2)${NC}"
        fi

        echo -e "\n${BLUE}  ── Slots de replicación ───────────────────────────${NC}"
        psql -h localhost -p "$PRIMARY_PORT" -U postgres -c "
            SELECT slot_name, active,
                   pg_size_pretty(
                       pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
                   ) AS wal_retenido
            FROM pg_replication_slots;" 2>/dev/null || echo "  (sin slots)"

        echo -e "\n${BLUE}  ── Estado repmgr ─────────────────────────────────${NC}"
        docker exec "$PRIMARY_NAME" \
            /usr/lib/postgresql/16/bin/repmgr \
            -f /etc/repmgr/repmgr.conf \
            cluster show 2>/dev/null | \
            sed 's/^/  /' || echo "  (repmgr no disponible)"
    fi

    echo -e "\n  Próxima actualización en ${INTERVAL}s... (Ctrl+C para salir)"
    sleep "$INTERVAL"
done
