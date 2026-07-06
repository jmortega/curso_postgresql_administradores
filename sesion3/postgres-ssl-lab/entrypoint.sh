#!/bin/bash
# =============================================================
# entrypoint.sh
# Corrige permisos de certificados, configura SSL en postgresql.conf
# y arranca PostgreSQL.
# =============================================================
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
# postgres:16-alpine instala los binarios en /usr/local/bin (no en /usr/lib/postgresql)
PG_BIN="/usr/local/bin"

log() { echo "[$(date '+%H:%M:%S')] [SSL-PG] $*"; }

# ── 1. Corregir permisos de los certificados ──────────────────
# Los volúmenes Docker se montan con permisos del host.
# PostgreSQL exige que server.key sea 600 y propiedad de postgres.
log "Configurando permisos de certificados..."
cp /certs/server.crt /tmp/server.crt
cp /certs/server.key /tmp/server.key
cp /certs/ca.crt     /tmp/ca.crt
chown postgres:postgres /tmp/server.crt /tmp/server.key /tmp/ca.crt
chmod 600 /tmp/server.key
chmod 644 /tmp/server.crt /tmp/ca.crt
log "Permisos OK"

# ── 2. Corregir permisos de PGDATA ────────────────────────────
chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

# ── 3. Inicializar PGDATA si está vacío ───────────────────────
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    log "Inicializando PGDATA..."
    # Crear el fichero de contraseña como usuario postgres para que initdb pueda leerlo
    install -m 600 -o postgres /dev/null /tmp/pgpass_init
    echo "$POSTGRES_PASSWORD" > /tmp/pgpass_init
    gosu postgres "$PG_BIN/initdb" \
        --pgdata="$PGDATA" \
        --username=postgres \
        --encoding=UTF8 \
        --locale=en_US.UTF-8 \
        --auth-local=trust \
        --auth-host=scram-sha-256 \
        --pwfile=/tmp/pgpass_init 2>&1
    rm -f /tmp/pgpass_init
    log "PGDATA inicializado"
fi

# ── 4. Copiar pg_hba.conf ─────────────────────────────────────
cp /etc/postgresql/pg_hba.conf "$PGDATA/pg_hba.conf"
chown postgres:postgres "$PGDATA/pg_hba.conf"

# ── 5. Configurar SSL en postgresql.conf ─────────────────────
# Se usa postgresql.auto.conf para no sobreescribir el base
gosu postgres bash -c "cat >> '$PGDATA/postgresql.auto.conf'" << PGCONF

# ── SSL ──────────────────────────────────────────────────────
ssl                         = on
ssl_cert_file               = '/tmp/server.crt'
ssl_key_file                = '/tmp/server.key'
ssl_ca_file                 = '/tmp/ca.crt'
ssl_min_protocol_version    = 'TLSv1.2'
ssl_ciphers                 = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers   = on

# ── Autenticación ────────────────────────────────────────────
hba_file                    = '$PGDATA/pg_hba.conf'

# ── Logging ──────────────────────────────────────────────────
log_connections             = on
log_disconnections          = on
log_destination             = stderr
logging_collector           = off
PGCONF

# ── 6. Arranque temporal para crear usuario y BD ──────────────
if [ ! -f "$PGDATA/.lab_initialized" ]; then
    log "Arrancando PostgreSQL (setup temporal)..."
    gosu postgres "$PG_BIN/pg_ctl" start \
        -D "$PGDATA" \
        -o "-c config_file=$PGDATA/postgresql.conf" \
        -l /tmp/pg_setup.log \
        -w -t 60

    log "Creando usuario y base de datos..."
    gosu postgres psql -U postgres << SQL
        CREATE ROLE pguser
            WITH LOGIN PASSWORD '$POSTGRES_PASSWORD'
            NOSUPERUSER NOCREATEDB NOCREATEROLE
            CONNECTION LIMIT 20;
        CREATE DATABASE testdb OWNER pguser;
        GRANT ALL PRIVILEGES ON DATABASE testdb TO pguser;
SQL

    # Ejecutar init.sql si existe (tablas y datos de prueba)
    if [ -f "/docker-entrypoint-initdb.d/init.sql" ]; then
        log "Ejecutando init.sql (tablas de prueba)..."
        gosu postgres psql -U postgres -d testdb             -f /docker-entrypoint-initdb.d/init.sql 2>&1 | grep -E "NOTICE|ERROR" || true
        log "init.sql completado"
    fi

    touch "$PGDATA/.lab_initialized"
    log "Deteniendo instancia temporal..."
    gosu postgres "$PG_BIN/pg_ctl" stop -D "$PGDATA" -m fast -w
fi

log "Arrancando PostgreSQL con SSL..."
exec gosu postgres "$PG_BIN/postgres" \
    -D "$PGDATA" \
    -c config_file="$PGDATA/postgresql.conf"
