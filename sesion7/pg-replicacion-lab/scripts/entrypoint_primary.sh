#!/bin/bash
# =============================================================
# entrypoint_primary.sh
# Inicializa y arranca el nodo PRIMARIO con repmgr
# =============================================================
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PG_BIN="/usr/lib/postgresql/16/bin"
REPMGR_CONF="/etc/repmgr/repmgr.conf"
LOG_DIR="/var/log/repmgr"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PRIMARY] $*"; }

# ── Corregir permisos (arrancamos como root) ──────────────────
chown -R postgres:postgres "$PGDATA" /var/log/repmgr /etc/repmgr 2>/dev/null || true
chmod 700 "$PGDATA"
mkdir -p "$LOG_DIR"

# ── Escribir script que corre como postgres ───────────────────
# (evita problemas de heredoc con gosu y expansión de variables)
cat > /tmp/pg_primary_setup.sh << SCRIPT
#!/bin/bash
set -euo pipefail
PGDATA="$PGDATA"
PG_BIN="$PG_BIN"
REPMGR_CONF="$REPMGR_CONF"
LOG_DIR="$LOG_DIR"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
REPL_PASSWORD="$REPL_PASSWORD"
REPMGR_PASSWORD="$REPMGR_PASSWORD"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PRIMARY] \$*"; }

# ── 1. Detectar rol: primario o rejoin como standby ───────────
# Si PGDATA está vacío comprobamos si ya existe un primario activo
# en el clúster. Si existe, clonamos como standby (rejoin post-failover).
# Si no existe, inicializamos como primario nuevo.
FIRST_RUN=false
MODE=primary

if [ ! -f "\$PGDATA/PG_VERSION" ]; then
    # Comprobar si hay un primario activo en el clúster
    EXISTING_PRIMARY=""
    for TRY_HOST in pg-standby1 pg-standby2; do
        IS_PRI=\$(PGPASSWORD="\$REPMGR_PASSWORD" psql \
            -h "\$TRY_HOST" -p 5432 -U repmgr -d repmgr \
            -At -c "SELECT NOT pg_is_in_recovery()" 2>/dev/null || echo "f")
        if [ "\$IS_PRI" = "t" ]; then
            EXISTING_PRIMARY="\$TRY_HOST"
            break
        fi
    done

    if [ -n "\$EXISTING_PRIMARY" ]; then
        # Hay un primario activo → clonar como standby (rejoin)
        # FIX: --force es necesario aquí porque el volumen puede tener
        # residuos triviales (p.ej. "lost+found" que ext4 crea solo al
        # formatear un volumen nuevo) aunque no exista PG_VERSION — es
        # decir, no hay una instalación real de Postgres que perder.
        # 'repmgr standby clone' se niega a operar en un directorio no
        # vacío salvo que se le indique explícitamente sobrescribirlo.
        log "Primario activo detectado en \$EXISTING_PRIMARY — clonando como standby..."
        MODE=standby
        PGPASSWORD="\$REPMGR_PASSWORD" \
        "\$PG_BIN/repmgr" \
            -h "\$EXISTING_PRIMARY" -p 5432 \
            -U repmgr -d repmgr \
            -f "\$REPMGR_CONF" \
            standby clone \
            --force \
            --fast-checkpoint \
            --copy-external-config-files=pgdata \
            --verbose 2>&1
        log "Clonado completado — pg-primary rejoineando como standby"

        cp /etc/postgresql/postgresql.conf "\$PGDATA/postgresql.conf"
        cat > "\$PGDATA/postgresql.auto.conf" << AUTOCONF
primary_conninfo = 'host=\${EXISTING_PRIMARY} port=5432 user=replicator password=\${REPL_PASSWORD} application_name=pg-primary sslmode=prefer'
restore_command = 'cp /mnt/wal_archive/%f %p 2>/dev/null || true'
AUTOCONF
        touch "\$PGDATA/standby.signal"
    else
        # No hay primario → inicializar como primario nuevo
        log "Inicializando PGDATA con data-checksums..."
        "\$PG_BIN/initdb" \
            --pgdata="\$PGDATA" \
            --username=postgres \
            --encoding=UTF8 \
            --locale=en_US.UTF-8 \
            --data-checksums \
            --auth-local=trust \
            --auth-host=scram-sha-256 \
            --pwfile=<(echo "\$POSTGRES_PASSWORD") 2>&1
        log "PGDATA inicializado"
        FIRST_RUN=true
    fi
fi

# ── 2. Copiar configuración ───────────────────────────────────
log "Copiando configuración de PostgreSQL..."
cp /etc/postgresql/postgresql.conf "\$PGDATA/postgresql.conf"
cp /etc/postgresql/pg_hba.conf     "\$PGDATA/pg_hba.conf"

# ── 3-5. Solo en primera ejecución: arranque temporal + setup ─
if [ "\$FIRST_RUN" = "true" ]; then
    log "Arrancando PostgreSQL (temporal para setup)..."
    # Arranque sin synchronous_commit para que los CREATE ROLE/DATABASE
    # no esperen réplicas que aún no existen.
    "\$PG_BIN/pg_ctl" start \
        -D "\$PGDATA" \
        -o "-c config_file=\$PGDATA/postgresql.conf -c synchronous_standby_names='' -c synchronous_commit=local" \
        -l "\$LOG_DIR/postgresql.log" \
        -w -t 60
    log "PostgreSQL arrancado"

    log "Creando usuarios y bases de datos..."
    psql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='replicator'" | grep -q 1 || \
    psql -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '\$REPL_PASSWORD' CONNECTION LIMIT 10;"

    psql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='repmgr'" | grep -q 1 || \
    psql -U postgres -c "CREATE ROLE repmgr WITH SUPERUSER LOGIN PASSWORD '\$REPMGR_PASSWORD' CONNECTION LIMIT 20;"

    psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='repmgr'" | grep -q 1 || \
    psql -U postgres -c "CREATE DATABASE repmgr OWNER repmgr;"

    psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='dwh'" | grep -q 1 || \
    psql -U postgres -c "CREATE DATABASE dwh;"

    psql -U postgres -d dwh -c "
        CREATE TABLE IF NOT EXISTS pedidos (
            id              BIGSERIAL PRIMARY KEY,
            cliente_id      INTEGER       NOT NULL,
            fecha_creacion  TIMESTAMP     NOT NULL DEFAULT now(),
            estado          VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
            importe         NUMERIC(10,2)
        );" 2>/dev/null || true

    log "Usuarios y bases de datos creados"

    log "Registrando nodo primario en repmgr..."
    PGPASSWORD="\$REPMGR_PASSWORD" \
    "\$PG_BIN/repmgr" -f "\$REPMGR_CONF" primary register \
        --superuser=postgres --verbose \
        2>&1 | tee -a "\$LOG_DIR/repmgr_setup.log" || \
    log "WARN: repmgr ya registrado o error no crítico"

    log "Deteniendo instancia temporal..."
    "\$PG_BIN/pg_ctl" stop -D "\$PGDATA" -m fast -w
fi

# ── 6. Arrancar PostgreSQL en segundo plano ────────────────────
# FIX: antes se esperaba a que postgres aceptara conexiones y se
# arrancaba repmgrd ANTES de volver a lanzar postgres (que solo se
# arrancaba al final con 'exec'). Eso hacía que la comprobación de
# TCP agotara siempre sus 30 intentos contra un servidor que aún no
# existía, y que el fichero centinela del healthcheck se tocara
# antes de que postgres estuviera realmente escuchando. Ahora
# postgres arranca aquí, en segundo plano, ANTES de comprobar nada.
log "Arrancando PostgreSQL (proceso principal)..."
"\$PG_BIN/postgres" \
    -D "\$PGDATA" \
    -c config_file="\$PGDATA/postgresql.conf" &
PG_PID=\$!

# ── 7. Esperar a que postgres acepte conexiones TCP ────────────
log "Esperando que postgres acepte conexiones TCP..."
for i in \$(seq 1 30); do
    if PGPASSWORD="\$REPMGR_PASSWORD" psql -h "\$(hostname)" -p 5432 \
            -U repmgr -d repmgr -c "SELECT 1" &>/dev/null; then
        log "Postgres listo tras \${i}s"
        break
    fi
    [ "\$i" -eq 30 ] && log "WARN: postgres tardó más de 30s en aceptar TCP"
    sleep 1
done

log "Arrancando repmgrd..."
PGPASSWORD="\$REPMGR_PASSWORD" \
"\$PG_BIN/repmgrd" \
    -f "\$REPMGR_CONF" \
    --monitoring-history \
    --pid-file=/tmp/repmgrd.pid \
    -d &

log "══════════════════════════════════════════════"
log "Nodo PRIMARIO listo. Puerto: 5432"
log "══════════════════════════════════════════════"

# Fichero centinela para el healthcheck de Docker
touch /tmp/primary_ready

# ── 8. Mantener el contenedor vivo mientras postgres corra ─────
# Ya no se usa 'exec postgres' aquí: postgres ya está corriendo en
# segundo plano desde el paso 6, y volver a lanzarlo chocaría con
# el puerto 5432 ya en uso. 'wait' bloquea el script (PID 1 del
# contenedor) hasta que el proceso postgres termine.
wait "\$PG_PID"
SCRIPT

chmod +x /tmp/pg_primary_setup.sh
exec gosu postgres /tmp/pg_primary_setup.sh
