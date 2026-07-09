#!/bin/bash
# =============================================================
# simular_carga.sh
# Genera carga artificial en PostgreSQL para que el script
# diagnostico_postgres.sh muestre datos en las secciones 2 y 3.
#
# Uso:
#   ./simular_carga.sh            # lanza todo y espera
#   ./simular_carga.sh --stop     # mata todos los procesos de carga
# =============================================================

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5433}"
PGUSER="${PGUSER:-pguser}"
PGPASSWORD="${PGPASSWORD:-pgpassword}"
PGDATABASE="${PGDATABASE:-appdb}"
PID_FILE="/tmp/simular_carga.pids"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $1"; }
ok()   { log "${GREEN}✓${NC}  $1"; }
warn() { log "${YELLOW}⚠${NC}  $1"; }
info() { log "$1"; }

pg() {
    PGPASSWORD="$PGPASSWORD" psql \
        -h "$PGHOST" -p "$PGPORT" \
        -U "$PGUSER" -d "$PGDATABASE" \
        -v ON_ERROR_STOP=0 \
        "$@" 2>/dev/null
}

# ── Stop ──────────────────────────────────────────────────────
if [ "${1:-}" = "--stop" ]; then
    if [ -f "$PID_FILE" ]; then
        info "Deteniendo procesos de carga..."
        while IFS= read -r PID; do
            kill "$PID" 2>/dev/null && ok "PID $PID detenido"
        done < "$PID_FILE"
        rm -f "$PID_FILE"
        ok "Carga detenida"
    else
        warn "No hay procesos de carga activos"
    fi
    exit 0
fi

echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Simulador de carga PostgreSQL${NC}"
echo -e "${BOLD}  ${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""

# Limpiar PIDs anteriores
rm -f "$PID_FILE"

# ── ESCENARIO A: Consulta lenta (aparece en sección 2) ────────
# Hace un full scan con pg_sleep para que dure 90 segundos
info "Lanzando consulta lenta (90s) — aparecerá en sección 2..."
PGPASSWORD="$PGPASSWORD" psql \
    -h "$PGHOST" -p "$PGPORT" \
    -U "$PGUSER" -d "$PGDATABASE" \
    -c "SELECT pg_sleep(90), count(*) FROM public.eventos;" \
    -v ON_ERROR_STOP=0 \
    --no-align --tuples-only \
    2>/dev/null &
echo $! >> "$PID_FILE"
ok "Consulta lenta lanzada (PID $!)"

sleep 1

# ── ESCENARIO B: Transacción abierta con lock (sección 2 y 3) ─
# Sesión 1: abre transacción y hace UPDATE sin commit (mantiene lock)
info "Abriendo transacción con lock en public.eventos (fila id=1)..."
PGPASSWORD="$PGPASSWORD" psql \
    -h "$PGHOST" -p "$PGPORT" \
    -U "$PGUSER" -d "$PGDATABASE" \
    -v ON_ERROR_STOP=0 \
    2>/dev/null << 'BLOCKER_SQL' &
BEGIN;
UPDATE public.eventos SET procesado = true WHERE id = 1;
-- Mantener el lock durante 120 segundos
SELECT pg_sleep(120);
ROLLBACK;
BLOCKER_SQL
BLOCKER_PID=$!
echo $BLOCKER_PID >> "$PID_FILE"
ok "Sesión bloqueadora lanzada (PID $BLOCKER_PID)"

sleep 2

# ── ESCENARIO C: Sesión bloqueada (sección 3) ─────────────────
# Sesión 2: intenta UPDATE sobre la misma fila → queda bloqueada
info "Lanzando sesión que intentará actualizar la misma fila (quedará bloqueada)..."
PGPASSWORD="$PGPASSWORD" psql \
    -h "$PGHOST" -p "$PGPORT" \
    -U "$PGUSER" -d "$PGDATABASE" \
    -v ON_ERROR_STOP=0 \
    2>/dev/null << 'BLOCKED_SQL' &
BEGIN;
-- Esta línea quedará bloqueada por la sesión anterior
UPDATE public.eventos SET procesado = false WHERE id = 1;
ROLLBACK;
BLOCKED_SQL
BLOCKED_PID=$!
echo $BLOCKED_PID >> "$PID_FILE"
ok "Sesión bloqueada lanzada (PID $BLOCKED_PID)"

sleep 1

# ── ESCENARIO D: Carga continua de inserción (sección 2) ──────
info "Lanzando bucle de inserciones continuas (60s)..."
(
    END_TIME=$(($(date +%s) + 60))
    while [ "$(date +%s)" -lt "$END_TIME" ]; do
        PGPASSWORD="$PGPASSWORD" psql \
            -h "$PGHOST" -p "$PGPORT" \
            -U "$PGUSER" -d "$PGDATABASE" \
            -c "INSERT INTO public.eventos (tipo, severidad, origen)
                VALUES ('test','info','simular_carga.sh');" \
            --no-align --tuples-only -v ON_ERROR_STOP=0 2>/dev/null
        sleep 0.5
    done
) &
echo $! >> "$PID_FILE"
ok "Bucle de inserciones lanzado (PID $!)"

echo ""
echo -e "${BOLD}Carga activa. Ahora ejecuta en otra terminal:${NC}"
echo -e "  ${YELLOW}./diagnostico_postgres.sh --watch${NC}"
echo ""
echo -e "Las secciones 2 y 3 deberían mostrar actividad."
echo -e "Para detener la carga: ${YELLOW}./simular_carga.sh --stop${NC}"
echo ""
info "Esperando 90s antes de limpiar automáticamente..."

# Esperar y luego limpiar
sleep 90
info "Limpiando procesos de carga..."
while IFS= read -r PID; do
    kill "$PID" 2>/dev/null
done < "$PID_FILE"
rm -f "$PID_FILE"
ok "Simulación completada"
