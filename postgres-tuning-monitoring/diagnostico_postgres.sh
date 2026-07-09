#!/bin/bash
# =============================================================================
# diagnostico_postgres.sh
# Muestra en tiempo real el estado de conexiones, bloqueos y cuellos de botella
#
# Uso:
#   ./diagnostico_postgres.sh                   # ejecución única
#   ./diagnostico_postgres.sh --watch           # refresco cada 5s
#   ./diagnostico_postgres.sh --watch --interval 10  # refresco cada 10s
# =============================================================================

# ── Configuración de conexión ─────────────────────────────────────────────────
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5433}"
PGUSER="${PGUSER:-pguser}"
PGPASSWORD="${PGPASSWORD:-pgpassword}"
PGDATABASE="${PGDATABASE:-appdb}"

# ── Opciones ──────────────────────────────────────────────────────────────────
WATCH_MODE=false
INTERVAL=5
while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch)     WATCH_MODE=true ;;
        --interval)  INTERVAL="$2"; shift ;;
        *)           echo "Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done

# ── Colores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Helper de conexión ────────────────────────────────────────────────────────
pg() {
    PGPASSWORD="$PGPASSWORD" psql \
        -h "$PGHOST" -p "$PGPORT" \
        -U "$PGUSER" -d "$PGDATABASE" \
        --no-align --tuples-only \
        "$@" 2>/dev/null
}

pg_table() {
    PGPASSWORD="$PGPASSWORD" psql \
        -h "$PGHOST" -p "$PGPORT" \
        -U "$PGUSER" -d "$PGDATABASE" \
        "$@" 2>/dev/null
}

# ── Verificar conectividad ────────────────────────────────────────────────────
check_connection() {
    if ! PGPASSWORD="$PGPASSWORD" pg_isready \
            -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -q 2>/dev/null; then
        echo -e "${RED}✗ No se puede conectar a ${PGHOST}:${PGPORT} (${PGUSER}@${PGDATABASE})${NC}"
        exit 1
    fi
}

# =============================================================================
# SECCIÓN 1 — Resumen general
# =============================================================================
seccion_resumen() {
    echo -e "\n${BOLD}${BLUE}── 1. Resumen general ───────────────────────────────────────────────${NC}"
    pg_table -c "
        SELECT
            count(*)                                            AS total_conexiones,
            count(*) FILTER (WHERE state = 'active')           AS activas,
            count(*) FILTER (WHERE state = 'idle')             AS idle,
            count(*) FILTER (WHERE state = 'idle in transaction')
                                                               AS idle_en_tx,
            count(*) FILTER (WHERE wait_event_type = 'Lock')   AS esperando_lock
        FROM pg_stat_activity
        WHERE pid <> pg_backend_pid();"
}

# =============================================================================
# SECCIÓN 2 — Conexiones activas con detalle
# =============================================================================
seccion_conexiones_activas() {
    echo -e "\n${BOLD}${BLUE}── 2. Conexiones activas (excluye idle) ─────────────────────────────${NC}"

    local COUNT
    COUNT=$(pg -c "
        SELECT count(*) FROM pg_stat_activity
        WHERE state != 'idle' AND pid <> pg_backend_pid();")

    if [ "${COUNT:-0}" -eq 0 ]; then
        echo -e "  ${GREEN}✓ Sin conexiones activas${NC}"
        return
    fi

    pg_table -c "
        SELECT
            pid,
            usename                                     AS usuario,
            application_name                            AS aplicacion,
            client_addr                                 AS ip_cliente,
            state,
            COALESCE(wait_event_type, '-')              AS wait_tipo,
            COALESCE(wait_event, '-')                   AS wait_evento,
            to_char(query_start, 'HH24:MI:SS')         AS inicio,
            round(EXTRACT(EPOCH FROM (now() - query_start))::numeric, 1)
                                                        AS duracion_s,
            left(query, 80)                             AS consulta
        FROM pg_stat_activity
        WHERE state != 'idle'
          AND pid <> pg_backend_pid()
        ORDER BY duracion_s DESC NULLS LAST;"
}

# =============================================================================
# SECCIÓN 3 — Bloqueos y deadlocks
# =============================================================================
seccion_bloqueos() {
    echo -e "\n${BOLD}${BLUE}── 3. Bloqueos activos (deadlocks / cuellos de botella) ─────────────${NC}"

    local COUNT
    COUNT=$(pg -c "
        SELECT count(*) FROM pg_stat_activity blocked
        JOIN pg_stat_activity blocking
            ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
        WHERE blocked.wait_event_type = 'Lock';")

    if [ "${COUNT:-0}" -eq 0 ]; then
        echo -e "  ${GREEN}✓ Sin bloqueos activos${NC}"
        return
    fi

    echo -e "  ${RED}⚠ ${COUNT} bloqueo(s) detectado(s)${NC}"
    pg_table -c "
        SELECT
            blocked.pid                                 AS pid_bloqueado,
            blocked.usename                             AS usuario_bloqueado,
            blocking.pid                                AS pid_bloqueador,
            blocking.usename                            AS usuario_bloqueador,
            round(EXTRACT(EPOCH FROM (now() - blocked.query_start))::numeric, 1)
                                                        AS espera_s,
            left(blocked.query, 60)                     AS consulta_bloqueada,
            left(blocking.query, 60)                    AS consulta_bloqueadora
        FROM pg_stat_activity blocked
        JOIN pg_stat_activity blocking
            ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
        WHERE blocked.wait_event_type = 'Lock'
        ORDER BY espera_s DESC;"
}

# =============================================================================
# SECCIÓN 4 — Consultas largas (> 5 minutos)
# =============================================================================
seccion_consultas_largas() {
    echo -e "\n${BOLD}${BLUE}── 4. Consultas largas (via monitoring.long_running_queries) ────────${NC}"

    local COUNT
    COUNT=$(pg -c "SELECT count(*) FROM monitoring.long_running_queries;" 2>/dev/null || echo "0")

    if [ "${COUNT:-0}" -eq 0 ]; then
        echo -e "  ${GREEN}✓ Sin consultas que superen 5 minutos${NC}"
        return
    fi

    echo -e "  ${YELLOW}⚠ ${COUNT} consulta(s) con más de 5 minutos de ejecución${NC}"
    pg_table -c "SELECT pid, usename, state, round(duration_seconds::numeric,0) AS duracion_s,
                        left(query_preview,80) AS consulta
                 FROM monitoring.long_running_queries;" 2>/dev/null
}

# =============================================================================
# SECCIÓN 5 — Backlog de eventos sin procesar
# =============================================================================
seccion_backlog() {
    echo -e "\n${BOLD}${BLUE}── 5. Backlog de eventos pendientes (public.eventos) ────────────────${NC}"
    pg_table -c "
        SELECT
            origen,
            severidad,
            count(*)                                    AS pendientes,
            min(creado_en)::TIMESTAMP(0)                AS mas_antiguo,
            round(EXTRACT(EPOCH FROM (now() - min(creado_en)))/60, 1)
                                                        AS antiguedad_min
        FROM public.eventos
        WHERE NOT procesado
        GROUP BY origen, severidad
        ORDER BY pendientes DESC
        LIMIT 10;" 2>/dev/null || \
    echo -e "  ${YELLOW}(tabla eventos no encontrada — ejecuta init_monitoring.sql primero)${NC}"
}

# =============================================================================
# SECCIÓN 6 — Tasa de error en tiempo real
# =============================================================================
seccion_tasa_error() {
    echo -e "\n${BOLD}${BLUE}── 6. Tasa de error por origen — última hora ────────────────────────${NC}"
    pg_table -c "
        SELECT
            origen,
            count(*)                                                    AS total,
            count(*) FILTER (WHERE severidad IN ('error','critical'))   AS errores,
            round(
                count(*) FILTER (WHERE severidad IN ('error','critical'))
                * 100.0 / NULLIF(count(*), 0), 1
            )                                                           AS pct_error
        FROM public.eventos
        WHERE creado_en > now() - interval '1 hour'
        GROUP BY origen
        HAVING count(*) > 0
        ORDER BY pct_error DESC NULLS LAST;" 2>/dev/null || \
    echo -e "  ${YELLOW}(tabla eventos no disponible)${NC}"
}

# =============================================================================
# SECCIÓN 7 — Top 5 consultas más lentas (pg_stat_statements)
# =============================================================================
seccion_top_queries() {
    echo -e "\n${BOLD}${BLUE}── 7. Top 5 consultas más lentas (pg_stat_statements) ──────────────${NC}"
    pg_table -c "
        SELECT
            left(query, 70)                             AS consulta,
            calls,
            round(mean_exec_time::numeric, 2)           AS media_ms,
            round(max_exec_time::numeric, 2)            AS max_ms,
            round(stddev_exec_time::numeric, 2)         AS stddev_ms
        FROM pg_stat_statements
        WHERE query NOT LIKE '%pg_stat%'
          AND calls > 1
        ORDER BY mean_exec_time DESC
        LIMIT 5;" 2>/dev/null || \
    echo -e "  ${YELLOW}(pg_stat_statements no disponible — añade shared_preload_libraries)${NC}"
}

# =============================================================================
# SECCIÓN 8 — Cache hit ratio
# =============================================================================
seccion_cache() {
    echo -e "\n${BOLD}${BLUE}── 8. Cache hit ratio ───────────────────────────────────────────────${NC}"
    pg_table -c "
        SELECT
            datname,
            blks_hit,
            blks_read,
            round(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2)
                                                        AS cache_hit_pct,
            xact_commit,
            xact_rollback,
            deadlocks
        FROM pg_stat_database
        WHERE datname = current_database();"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================
imprimir_todo() {
    local TS
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Diagnóstico PostgreSQL — ${TS}${NC}"
    echo -e "${BOLD}  ${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════${NC}"

    seccion_resumen
    seccion_conexiones_activas
    seccion_bloqueos
    seccion_consultas_largas
    seccion_backlog
    seccion_tasa_error
    seccion_top_queries
    seccion_cache

    echo -e "\n${BOLD}════════════════════════════════════════════════════════════════════${NC}"
    if $WATCH_MODE; then
        echo -e "  Próxima actualización en ${INTERVAL}s — Ctrl+C para salir"
    fi
}

# =============================================================================
# ARRANQUE
# =============================================================================
check_connection

if $WATCH_MODE; then
    while true; do
        clear
        imprimir_todo
        sleep "$INTERVAL"
    done
else
    imprimir_todo
fi
