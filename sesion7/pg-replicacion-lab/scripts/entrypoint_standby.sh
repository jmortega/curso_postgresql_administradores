#!/bin/bash
# =============================================================
# entrypoint_standby.sh
# Clona el primario, registra el nodo standby y arranca repmgrd
# =============================================================
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PG_BIN="/usr/lib/postgresql/16/bin"
REPMGR_CONF="/etc/repmgr/repmgr.conf"
PRIMARY_HOST="${PRIMARY_HOST:-pg-primary}"
PRIMARY_PORT="${PRIMARY_PORT:-5432}"
LOG_DIR="/var/log/repmgr"
NODE_NAME="${NODE_NAME:-standby}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$NODE_NAME] $*"; }

# ── Corregir permisos (arrancamos como root) ──────────────────
chown -R postgres:postgres "$PGDATA" /var/log/repmgr /etc/repmgr 2>/dev/null || true
chmod 700 "$PGDATA"
mkdir -p "$LOG_DIR"

# ── Escribir script que corre como postgres ───────────────────
cat > /tmp/pg_standby_setup.sh << SCRIPT
#!/bin/bash
set -euo pipefail
PGDATA="$PGDATA"
PG_BIN="$PG_BIN"
REPMGR_CONF="$REPMGR_CONF"
PRIMARY_HOST="$PRIMARY_HOST"
PRIMARY_PORT="$PRIMARY_PORT"
LOG_DIR="$LOG_DIR"
NODE_NAME="$NODE_NAME"
REPL_PASSWORD="$REPL_PASSWORD"
REPMGR_PASSWORD="$REPMGR_PASSWORD"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [\$NODE_NAME] \$*"; }

# ── 1. Esperar al primario ────────────────────────────────────
log "Esperando que el primario (\$PRIMARY_HOST:\$PRIMARY_PORT) esté disponible..."
for i in \$(seq 1 60); do
    if PGPASSWORD="\$REPMGR_PASSWORD" \
        psql -h "\$PRIMARY_HOST" -p "\$PRIMARY_PORT" \
             -U repmgr -d repmgr -c "SELECT 1" &>/dev/null; then
        log "Primario disponible tras \${i}s"
        break
    fi
    [ "\$i" -eq 60 ] && { log "ERROR: primario no respondió en 60s"; exit 1; }
    sleep 1
done

# ── 2. Clonar si PGDATA vacío ─────────────────────────────────
if [ ! -f "\$PGDATA/PG_VERSION" ]; then
    log "Clonando desde el primario..."
    PGPASSWORD="\$REPMGR_PASSWORD" \
    "\$PG_BIN/repmgr" \
        -h "\$PRIMARY_HOST" -p "\$PRIMARY_PORT" \
        -U repmgr -d repmgr \
        -f "\$REPMGR_CONF" \
        standby clone \
        --fast-checkpoint \
        --copy-external-config-files=pgdata \
        --verbose 2>&1 | tee -a "\$LOG_DIR/repmgr_clone.log"
    log "Clonado completado"
else
    log "PGDATA ya existe — usando datos existentes"
fi

# ── 3. Aplicar configuración ──────────────────────────────────
log "Aplicando configuración del standby..."
cp /etc/postgresql/postgresql.conf "\$PGDATA/postgresql.conf"

cat > "\$PGDATA/postgresql.auto.conf" << AUTOCONF
primary_conninfo = 'host=\${PRIMARY_HOST} port=\${PRIMARY_PORT} user=replicator password=\${REPL_PASSWORD} application_name=\${NODE_NAME} sslmode=prefer'
primary_slot_name = 'slot_\${NODE_NAME}'
restore_command = 'cp /mnt/wal_archive/%f %p 2>/dev/null || true'
AUTOCONF

touch "\$PGDATA/standby.signal"

# ── 4. Arranque temporal ──────────────────────────────────────
log "Arrancando PostgreSQL en modo standby (temporal)..."
"\$PG_BIN/pg_ctl" start \
    -D "\$PGDATA" \
    -o "-c config_file=\$PGDATA/postgresql.conf" \
    -l "\$LOG_DIR/postgresql.log" \
    -w -t 60

# ── 5. Esperar WAL receiver ───────────────────────────────────
log "Esperando streaming del primario..."
for i in \$(seq 1 30); do
    STATUS=\$(psql -U postgres -At -c "SELECT status FROM pg_stat_wal_receiver" 2>/dev/null || echo "")
    [ "\$STATUS" = "streaming" ] && { log "Replicación activa"; break; }
    sleep 2
done

# ── 6. Crear slot en primario ─────────────────────────────────
SLOT_NAME="slot_\${NODE_NAME}"
PGPASSWORD="\$REPL_PASSWORD" \
psql -h "\$PRIMARY_HOST" -p "\$PRIMARY_PORT" -U replicator -d postgres \
     -c "SELECT pg_create_physical_replication_slot('\${SLOT_NAME}', true)" \
     2>/dev/null || log "WARN: slot \${SLOT_NAME} puede que ya exista"

# ── 7. Registrar en repmgr ────────────────────────────────────
log "Registrando standby en repmgr..."
PGPASSWORD="\$REPMGR_PASSWORD" \
"\$PG_BIN/repmgr" -f "\$REPMGR_CONF" standby register \
    --superuser=postgres --upstream-node-id=1 --force --verbose \
    2>&1 | tee -a "\$LOG_DIR/repmgr_register.log" || \
log "WARN: error no crítico en registro"

sleep 2
PGPASSWORD="\$REPMGR_PASSWORD" \
"\$PG_BIN/repmgr" -f "\$REPMGR_CONF" cluster show 2>/dev/null || true

# ── 8. Parar instancia temporal ───────────────────────────────
log "Deteniendo instancia temporal..."
"\$PG_BIN/pg_ctl" stop -D "\$PGDATA" -m fast -w

# ── 9. Arrancar PostgreSQL definitivo en segundo plano ─────────
# FIX: antes se arrancaba repmgrd (paso 9 original) mientras
# postgres seguía parado, y solo se relanzaba postgres al final
# con 'exec' — repmgrd arrancaba contra una base de datos que
# todavía no existía. Ahora postgres se relanza aquí primero.
log "Arrancando PostgreSQL (proceso principal)..."
"\$PG_BIN/postgres" \
    -D "\$PGDATA" \
    -c config_file="\$PGDATA/postgresql.conf" &
PG_PID=\$!

log "Esperando que postgres acepte conexiones TCP..."
for i in \$(seq 1 30); do
    if psql -U postgres -c "SELECT 1" &>/dev/null; then
        log "Postgres listo tras \${i}s"
        break
    fi
    [ "\$i" -eq 30 ] && log "WARN: postgres tardó más de 30s en aceptar TCP"
    sleep 1
done

# ── 10. Arrancar repmgrd ───────────────────────────────────────
log "Arrancando repmgrd..."
PGPASSWORD="\$REPMGR_PASSWORD" \
"\$PG_BIN/repmgrd" \
    -f "\$REPMGR_CONF" \
    --monitoring-history \
    --pid-file=/tmp/repmgrd.pid \
    -d &

log "══════════════════════════════════════════════"
log "Standby \${NODE_NAME} listo"
log "══════════════════════════════════════════════"

# ── 11. Mantener el contenedor vivo mientras postgres corra ────
# Ya no se usa 'exec postgres': ya está corriendo desde el paso 9,
# y relanzarlo chocaría con el puerto 5432 ya en uso.
wait "\$PG_PID"
SCRIPT

chmod +x /tmp/pg_standby_setup.sh
exec gosu postgres /tmp/pg_standby_setup.sh
