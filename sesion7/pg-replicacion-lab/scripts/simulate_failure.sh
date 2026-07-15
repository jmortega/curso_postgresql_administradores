#!/bin/bash
# =============================================================
# simulate_failure.sh
# Simula el fallo del nodo primario y mide el RTO
#
# Uso: ./scripts/simulate_failure.sh [--type crash|stop|network]
# =============================================================

FAILURE_TYPE="${1:-crash}"
LOG="/tmp/failover_test_$(date +%Y%m%d_%H%M%S).log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }
info() { log "${BLUE}INFO${NC}  $1"; }
ok()   { log "${GREEN}OK${NC}    $1"; }
warn() { log "${YELLOW}WARN${NC}  $1"; }
fail() { log "${RED}FAIL${NC}  $1"; }

echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Simulación de Fallo — Tipo: $FAILURE_TYPE${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"

# ── Verificar estado pre-fallo ────────────────────────────────
info "Verificando estado inicial del clúster..."

if ! docker inspect pg-primary &>/dev/null; then
    fail "Contenedor pg-primary no encontrado. ¿Está el lab levantado?"
    exit 1
fi

PRIMARY_ROLE=$(psql -h localhost -p 5432 -U postgres \
    -At -c "SELECT pg_is_in_recovery()" 2>/dev/null || echo "error")
if [ "$PRIMARY_ROLE" = "f" ]; then
    ok "pg-primary está activo como PRIMARIO (puerto 5432)"
else
    warn "pg-primary no es el primario actual — ajustando puertos"
fi

# ── Insertar datos de prueba antes del fallo ──────────────────
info "Insertando datos de prueba antes del fallo..."
ROWS_BEFORE=$(psql -h localhost -p 5432 -U postgres -d dwh \
    -At -c "SELECT count(*) FROM pedidos" 2>/dev/null || echo "0")
info "Filas en pedidos antes del fallo: $ROWS_BEFORE"

psql -h localhost -p 5432 -U postgres -d dwh -c "
    INSERT INTO pedidos (cliente_id, estado, importe)
    SELECT (random()*1000)::INT, 'pendiente', round((random()*500)::numeric,2)
    FROM generate_series(1,100);" 2>/dev/null || true

ROWS_AFTER_INSERT=$(psql -h localhost -p 5432 -U postgres -d dwh \
    -At -c "SELECT count(*) FROM pedidos" 2>/dev/null || echo "0")
info "Filas tras INSERT de prueba: $ROWS_AFTER_INSERT"

# ── Registrar tiempo de inicio del fallo ─────────────────────
FAIL_TIME=$(date +%s)
FAIL_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
info "═══ INICIANDO FALLO en $FAIL_TIMESTAMP ═══"

# ── Ejecutar el fallo según el tipo ──────────────────────────
case "$FAILURE_TYPE" in
    crash)
        info "Simulando CRASH del proceso PostgreSQL (SIGKILL)..."
        docker exec pg-primary \
            /usr/lib/postgresql/16/bin/pg_ctl \
            stop -D /var/lib/postgresql/data \
            -m immediate 2>/dev/null || \
        docker kill --signal=SIGKILL pg-primary 2>/dev/null || true
        info "pg-primary detenido de forma abrupta (SIGKILL)"
        ;;
    stop)
        info "Deteniendo pg-primary de forma limpia..."
        docker stop pg-primary
        info "pg-primary detenido (graceful stop)"
        ;;
    network)
        info "Simulando partición de red (desconectar pg-primary de la red)..."
        docker network disconnect pg-replicacion-lab_pg_cluster_net pg-primary
        info "pg-primary desconectado de la red del clúster"
        ;;
    *)
        fail "Tipo de fallo desconocido: $FAILURE_TYPE"
        fail "Opciones: crash | stop | network"
        exit 1
        ;;
esac

# ── Monitorizar el failover ───────────────────────────────────
info "Monitorizando el failover automático..."
echo ""
echo "  Tiempo | Puerto 5432 | Puerto 5433 | Puerto 5434 | Evento"
echo "  -------|-------------|-------------|-------------|-------"

RECOVERED=false
RTO_SECONDS=0
MAX_WAIT=120

for i in $(seq 1 "$MAX_WAIT"); do
    NOW=$(date +%s)
    ELAPSED=$((NOW - FAIL_TIME))

    STATUS_5432=$(pg_isready -h localhost -p 5432 -q 2>/dev/null && \
        psql -h localhost -p 5432 -U postgres -At \
        -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END" \
        2>/dev/null || echo "CAÍDO")

    STATUS_5433=$(pg_isready -h localhost -p 5433 -q 2>/dev/null && \
        psql -h localhost -p 5433 -U postgres -At \
        -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END" \
        2>/dev/null || echo "CAÍDO")

    STATUS_5434=$(pg_isready -h localhost -p 5434 -q 2>/dev/null && \
        psql -h localhost -p 5434 -U postgres -At \
        -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END" \
        2>/dev/null || echo "CAÍDO")

    EVENT=""
    # Detectar si algún standby se promovió a primario
    if [ "$STATUS_5433" = "PRIMARY" ] && ! $RECOVERED; then
        EVENT="🔴→🟢 pg-standby1 PROMOVIDO"
        RTO_SECONDS=$ELAPSED
        RECOVERED=true
    elif [ "$STATUS_5434" = "PRIMARY" ] && ! $RECOVERED; then
        EVENT="🔴→🟢 pg-standby2 PROMOVIDO"
        RTO_SECONDS=$ELAPSED
        RECOVERED=true
    fi

    printf "  %6ds | %-11s | %-11s | %-11s | %s\n" \
        "$ELAPSED" "$STATUS_5432" "$STATUS_5433" "$STATUS_5434" "$EVENT"

    $RECOVERED && break
    sleep 2
done

echo ""

# ── Resultado del failover ────────────────────────────────────
if $RECOVERED; then
    ok "═══ FAILOVER COMPLETADO ═══"
    ok "RTO (Recovery Time Objective): ${RTO_SECONDS}s"

    # Verificar que los datos están disponibles en el nuevo primario
    NEW_PRIMARY_PORT=""
    [ "$STATUS_5433" = "PRIMARY" ] && NEW_PRIMARY_PORT=5433
    [ "$STATUS_5434" = "PRIMARY" ] && NEW_PRIMARY_PORT=5434

    if [ -n "$NEW_PRIMARY_PORT" ]; then
        ROWS_RECOVERED=$(psql -h localhost -p "$NEW_PRIMARY_PORT" -U postgres -d dwh \
            -At -c "SELECT count(*) FROM pedidos" 2>/dev/null || echo "?")
        info "Filas recuperadas en nuevo primario: $ROWS_RECOVERED (esperadas: $ROWS_AFTER_INSERT)"

        # Verificar escritura en el nuevo primario
        psql -h localhost -p "$NEW_PRIMARY_PORT" -U postgres -d dwh -c "
            INSERT INTO pedidos (cliente_id, estado, importe)
            VALUES (9999, 'procesado', 100.00);" 2>/dev/null && \
            ok "Escrituras funcionando en el nuevo primario (puerto $NEW_PRIMARY_PORT)" || \
            warn "No se pudo escribir en el nuevo primario"
    fi
else
    fail "El failover NO completó en ${MAX_WAIT}s"
    fail "Revisar logs: docker logs pg-standby1 | docker logs pg-standby2"
fi

# ── Estado final ──────────────────────────────────────────────
echo ""
info "Estado final del clúster:"
docker exec pg-standby1 \
    /usr/lib/postgresql/16/bin/repmgr \
    -f /etc/repmgr/repmgr.conf \
    cluster show 2>/dev/null || true

echo ""
info "Log guardado en: $LOG"
echo ""
echo -e "${BOLD}════════════════ PRÓXIMOS PASOS ════════════════════${NC}"
echo "  Para reincorporar pg-primary:"
echo "    ./scripts/rejoin_primary.sh"
echo ""
echo "  Para restaurar el tipo de fallo 'network':"
echo "    docker network connect pg-replicacion-lab_pg_cluster_net pg-primary"
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
