#!/bin/bash
# =============================================================
# rejoin_primary.sh
# Reincorpora el antiguo primario (pg-primary) como standby
# del nuevo primario activo.
#
# Uso: ./scripts/rejoin_primary.sh
# =============================================================
set -euo pipefail

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

echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Reincorporar pg-primary como Standby${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

# ── Detectar el primario activo ───────────────────────────────
info "Buscando el primario activo..."
NEW_PRIMARY_HOST=""
NEW_PRIMARY_PORT=""

declare -A NODE_MAP=(
    ["pg-standby1"]="5433"
    ["pg-standby2"]="5434"
    ["pg-primary"]="5432"
)

for NODE in pg-standby1 pg-standby2 pg-primary; do
    PORT="${NODE_MAP[$NODE]}"
    IS_PRIMARY=$(psql -h localhost -p "$PORT" -U postgres \
        -At -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo "f")
    if [ "$IS_PRIMARY" = "t" ]; then
        NEW_PRIMARY_HOST="$NODE"
        NEW_PRIMARY_PORT="$PORT"
        ok "Primario activo encontrado: $NEW_PRIMARY_HOST (localhost:$NEW_PRIMARY_PORT)"
        break
    fi
done

[ -z "$NEW_PRIMARY_HOST" ] && fail "No se encontró ningún primario activo"
[ "$NEW_PRIMARY_HOST" = "pg-primary" ] && {
    ok "pg-primary ya es el primario activo — nada que hacer"
    exit 0
}

# ── Reiniciar pg-primary si estaba caído ─────────────────────
info "Verificando estado del contenedor pg-primary..."
CONTAINER_STATUS=$(docker inspect pg-primary \
    --format='{{.State.Status}}' 2>/dev/null || echo "not_found")

case "$CONTAINER_STATUS" in
    running)
        ok "Contenedor pg-primary ya está corriendo"
        ;;
    exited|stopped)
        info "Reiniciando contenedor pg-primary..."
        docker start pg-primary
        ;;
    not_found)
        fail "Contenedor pg-primary no encontrado"
        ;;
    restarting)
        # El contenedor está en bucle de reinicios (datos incompatibles
        # con el nuevo primario). Hay que pararlo, limpiar PGDATA y
        # rearrancar para que el entrypoint haga un clon limpio.
        warn "Contenedor en bucle de reinicios — deteniendo para limpiar PGDATA..."
        docker stop pg-primary 2>/dev/null || true
        docker exec pg-primary rm -rf /var/lib/postgresql/data/* 2>/dev/null ||             docker run --rm                 -v pg-replicacion-lab_pg_primary_data:/data                 alpine sh -c "rm -rf /data/*"
        docker start pg-primary
        ;;
    *)
        warn "Estado inesperado del contenedor: $CONTAINER_STATUS"
        docker start pg-primary 2>/dev/null || true
        ;;
esac

# Esperar a que el contenedor esté running (máx 30s)
info "Esperando a que pg-primary esté running..."
for i in $(seq 1 30); do
    STATUS=$(docker inspect pg-primary --format='{{.State.Status}}' 2>/dev/null)
    if [ "$STATUS" = "running" ]; then
        ok "Contenedor pg-primary running"
        sleep 3  # dar tiempo al entrypoint
        break
    fi
    [ "$i" -eq 30 ] && fail "pg-primary no arrancó en 30s (estado: $STATUS)"
    sleep 1
done

# Reconectar a red si fue desconectado (simulación de partición)
docker network connect pg-replicacion-lab_pg_cluster_net pg-primary \
    2>/dev/null || true

# ── Intentar rejoin con pg_rewind ────────────────────────────
info "Intentando reincorporación con pg_rewind (sin re-clonar)..."

docker exec pg-primary bash -c "
    /usr/lib/postgresql/16/bin/pg_ctl \
        stop -D /var/lib/postgresql/data -m fast 2>/dev/null || true
    sleep 2

    PGPASSWORD=repmgr_lab \
    /usr/lib/postgresql/16/bin/repmgr \
        -f /etc/repmgr/repmgr.conf \
        node rejoin \
        --force-rewind \
        --upstream-conninfo='host=${NEW_PRIMARY_HOST} port=5432 user=repmgr password=repmgr_lab dbname=repmgr' \
        --verbose 2>&1
" && REJOIN_OK=true || REJOIN_OK=false

if $REJOIN_OK; then
    ok "Rejoin con pg_rewind completado"
else
    warn "pg_rewind no fue suficiente — re-clonando desde el nuevo primario..."

    docker exec pg-primary bash -c "
        # Detener si está corriendo
        /usr/lib/postgresql/16/bin/pg_ctl \
            stop -D /var/lib/postgresql/data -m fast 2>/dev/null || true
        sleep 2

        # Limpiar PGDATA
        rm -rf /var/lib/postgresql/data/*

        # Re-clonar desde el nuevo primario
        PGPASSWORD=repmgr_lab \
        /usr/lib/postgresql/16/bin/repmgr \
            -h ${NEW_PRIMARY_HOST} -p 5432 \
            -U repmgr -d repmgr \
            -f /etc/repmgr/repmgr.conf \
            standby clone \
            --fast-checkpoint \
            --verbose 2>&1

        # Arrancar como standby
        touch /var/lib/postgresql/data/standby.signal
        /usr/lib/postgresql/16/bin/pg_ctl \
            start -D /var/lib/postgresql/data -w -t 60 2>&1
    "
    ok "Re-clonado completado"
fi

# ── Registrar como standby ────────────────────────────────────
info "Registrando pg-primary como standby en repmgr..."
sleep 5
docker exec pg-primary bash -c "
    PGPASSWORD=repmgr_lab \
    /usr/lib/postgresql/16/bin/repmgr \
        -f /etc/repmgr/repmgr.conf \
        standby register \
        --upstream-node-id=\$(
            psql -h ${NEW_PRIMARY_HOST} -p 5432 -U repmgr -d repmgr \
            -At -c 'SELECT node_id FROM repmgr.nodes WHERE type=\\'primary\\'' \
            2>/dev/null || echo 2
        ) \
        --force \
        --verbose 2>&1
" || warn "Registro repmgr con advertencias — puede ser normal"

# ── Estado final ──────────────────────────────────────────────
sleep 5
echo ""
ok "═══ REINCORPORACIÓN COMPLETADA ═══"
echo ""
info "Estado final del clúster:"
docker exec "$NEW_PRIMARY_HOST" \
    /usr/lib/postgresql/16/bin/repmgr \
    -f /etc/repmgr/repmgr.conf \
    cluster show 2>/dev/null || true

echo ""
info "Estado de replicación:"
psql -h localhost -p "$NEW_PRIMARY_PORT" -U postgres -c "
    SELECT application_name, state, sync_state, replay_lag
    FROM pg_stat_replication
    ORDER BY application_name;" 2>/dev/null || true
