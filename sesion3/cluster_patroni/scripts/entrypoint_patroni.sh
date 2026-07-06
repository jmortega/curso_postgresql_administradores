#!/bin/bash
set -euo pipefail

PGDATA="/data/patroni"
PG_BIN="/usr/lib/postgresql/16/bin"

log() { echo "[$(date '+%H:%M:%S')] [${NODE_NAME:-patroni}] $*"; }

# Corregir permisos del volumen (arrancamos como root)
chown -R postgres:postgres "$PGDATA" 2>/dev/null || true
chmod 700 "$PGDATA"
mkdir -p /var/run/postgresql /tmp
chown postgres:postgres /var/run/postgresql

# Escribir script que ejecuta patroni como postgres
install -m 700 -o postgres /dev/null /tmp/pgpass_init 2>/dev/null || true

cat > /tmp/run_patroni.sh << 'INNER'
#!/bin/bash
set -euo pipefail
export PATH="/usr/lib/postgresql/16/bin:$PATH"
log() { echo "[$(date '+%H:%M:%S')] [${NODE_NAME:-patroni}] $*"; }

log "Arrancando Patroni para nodo ${NODE_NAME}..."
touch /tmp/patroni_ready

exec patroni /etc/patroni/patroni.yml
INNER
chmod +x /tmp/run_patroni.sh

log "Iniciando como usuario postgres..."
exec gosu postgres /tmp/run_patroni.sh
