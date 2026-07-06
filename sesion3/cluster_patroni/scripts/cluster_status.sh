#!/bin/bash
# =============================================================
# cluster_status.sh — Estado del clúster pg-ha-lab
# =============================================================
WATCH_MODE=false
[ "${1:-}" = "--watch" ] && WATCH_MODE=true

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

print_status() {
  local TS=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "\n${BOLD}════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Estado del Clúster pg-ha-lab — $TS${NC}"
  echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"

  echo -e "\n${BLUE}▸ Patroni — clúster pg-ha-cluster:${NC}"
  docker exec pg-node1 patronictl -c /etc/patroni/patroni.yml list 2>/dev/null || \
    echo -e "  ${RED}✗ Patroni no disponible${NC}"

  echo -e "\n${BLUE}▸ Rol de cada nodo:${NC}"
  for NODE_PORT in "pg-node1:5432" "pg-node2:5433" "pg-node3:5434"; do
    NODE="${NODE_PORT%%:*}"; PORT="${NODE_PORT##*:}"
    if PGPASSWORD=postgres_lab psql -h localhost -p "$PORT" -U postgres -At \
        -c "SELECT 1" &>/dev/null 2>&1; then
      ROLE=$(PGPASSWORD=postgres_lab psql -h localhost -p "$PORT" -U postgres -At \
        -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END" 2>/dev/null)
      LAG=$(PGPASSWORD=postgres_lab psql -h localhost -p "$PORT" -U postgres -At \
        -c "SELECT COALESCE(pg_last_wal_receive_lsn()::TEXT, 'N/A')" 2>/dev/null || echo "N/A")
      [ "$ROLE" = "PRIMARY" ] && COLOR=$GREEN || COLOR=$YELLOW
      echo -e "  ${GREEN}✓${NC} $NODE (localhost:$PORT) → ${COLOR}${BOLD}$ROLE${NC}"
    else
      echo -e "  ${RED}✗${NC} $NODE (localhost:$PORT) → ${RED}NO DISPONIBLE${NC}"
    fi
  done

  echo -e "\n${BLUE}▸ HAProxy — backends:${NC}"
  # HAProxy habla TCP puro (L4) — pg_isready no funciona porque no hay handshake PG.
  # Se usa psql directamente para verificar la conectividad real.
  HAPROXY_WRITE=$(PGPASSWORD=postgres_lab psql -h localhost -p 5000 -U postgres       -At -c "SELECT inet_server_addr()::text" 2>/dev/null)
  if [ -n "$HAPROXY_WRITE" ]; then
    echo -e "  ${GREEN}✓${NC} Escritura  (localhost:5000) → primario en $HAPROXY_WRITE"
  else
    echo -e "  ${RED}✗${NC} Escritura  (localhost:5000) no disponible"
  fi

  HAPROXY_READ=$(PGPASSWORD=postgres_lab psql -h localhost -p 5001 -U postgres       -At -c "SELECT inet_server_addr()::text" 2>/dev/null)
  if [ -n "$HAPROXY_READ" ]; then
    echo -e "  ${GREEN}✓${NC} Lectura    (localhost:5001) → réplica en $HAPROXY_READ"
  else
    echo -e "  ${YELLOW}⚠${NC} Lectura    (localhost:5001) no disponible (normal sin réplicas activas)"
  fi

  echo -e "\n${BLUE}▸ PgBouncer — pool:${NC}"
  if pg_isready -h localhost -p 6432 -q 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} PgBouncer  (localhost:6432)"
    PGPASSWORD=postgres_lab psql -h localhost -p 6432 -U postgres -d pgbouncer \
        -c "SHOW POOLS;" 2>/dev/null | grep -v "^$" | head -8 || true
  else
    echo -e "  ${RED}✗${NC} PgBouncer  (localhost:6432) — comprobar: docker logs pgbouncer"
  fi

  echo -e "\n${BLUE}▸ Replicación (desde primario):${NC}"
  # Detectar primario directamente por puerto para evitar dependencia de HAProxy
  PRIMARY_PORT=""
  for PORT in 5432 5433 5434; do
    IS_PRI=$(PGPASSWORD=postgres_lab psql -h localhost -p "$PORT" -U postgres -At \
        -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo f)
    [ "$IS_PRI" = "t" ] && PRIMARY_PORT="$PORT" && break
  done
  if [ -n "$PRIMARY_PORT" ]; then
    PGPASSWORD=postgres_lab psql -h localhost -p "$PRIMARY_PORT" -U postgres -c "
      SELECT application_name AS standby, state, sync_state,
             COALESCE(pg_size_pretty(pg_wal_lsn_diff(
               pg_current_wal_lsn(), flush_lsn)),'0') AS lag
      FROM pg_stat_replication
      ORDER BY application_name;" 2>/dev/null || echo "  (sin réplicas conectadas)"
  else
    echo -e "  ${YELLOW}No se encontró primario activo${NC}"
  fi

  echo -e "\n${BLUE}▸ etcd:${NC}"
  docker exec etcd etcdctl --endpoints=http://localhost:2379 endpoint health 2>/dev/null && \
    echo "" || echo -e "  ${RED}✗ etcd no disponible${NC}"

  echo -e "${BOLD}════════════════════════════════════════════════════════${NC}\n"
}

if $WATCH_MODE; then
  while true; do clear; print_status; sleep 5; done
else
  print_status
fi
