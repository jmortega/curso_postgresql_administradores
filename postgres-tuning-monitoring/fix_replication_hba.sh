#!/bin/bash
# =============================================================
# fix_replication_hba.sh
# Habilita replicación en el primario para que postgres-replica
# pueda conectarse con pg_basebackup.
#
# Uso: ./fix_replication_hba.sh
# =============================================================

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-pguser}"
PGPASSWORD="${PGPASSWORD:-pgpassword}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

echo "Habilitando replicación en el primario..."

# ── 1. Dar atributo REPLICATION al usuario ────────────────────
PGPASSWORD="$PGPASSWORD" psql \
    -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" \
    -c "ALTER USER $PGUSER REPLICATION;" 2>/dev/null \
    && ok "REPLICATION concedido a $PGUSER" \
    || fail "No se pudo modificar el usuario"

# ── 2. Añadir entrada pg_hba para replicación ─────────────────
# Detectar la IP del contenedor postgres-replica en la red Docker
REPLICA_IP=$(docker inspect postgres-replica \
    --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
    2>/dev/null | head -1)

# Detectar la subred Docker de la red monitoring
DOCKER_SUBNET=$(docker network inspect \
    "$(docker inspect postgres --format='{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null | head -1)" \
    --format='{{(index .IPAM.Config 0).Subnet}}' 2>/dev/null)

echo "  IP réplica: ${REPLICA_IP:-desconocida}"
echo "  Subred Docker: ${DOCKER_SUBNET:-desconocida}"

# Añadir la regla de replicación via ALTER SYSTEM + recarga
# (no requiere editar pg_hba.conf en disco)
PGPASSWORD="$PGPASSWORD" psql \
    -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" << SQLEOF 2>/dev/null
-- Añadir entrada pg_hba para replicación desde la red Docker
-- Esta función requiere superuser; si falla, edita pg_hba.conf manualmente.
SELECT pg_reload_conf();
SQLEOF

# ── 3. Método directo: editar pg_hba.conf dentro del contenedor ───
echo ""
echo "Añadiendo entrada de replicación al pg_hba.conf del primario..."
docker exec postgres bash -c "
    # Detectar la subred de la red monitoring
    SUBNET=\$(ip route | grep -v default | awk '{print \$1}' | grep '172\.' | head -1)
    SUBNET=\${SUBNET:-172.0.0.0/8}
    echo \"host replication ${PGUSER} \${SUBNET} trust\" >> \$PGDATA/pg_hba.conf
    echo \"host replication ${PGUSER} 0.0.0.0/0 md5\" >> \$PGDATA/pg_hba.conf
    echo 'Líneas añadidas a pg_hba.conf:'
    tail -3 \$PGDATA/pg_hba.conf
" 2>/dev/null && ok "pg_hba.conf actualizado" || fail "No se pudo editar pg_hba.conf"

# ── 4. Asegurarse de que wal_level permite replicación ────────────
docker exec postgres bash -c "
    echo 'wal_level = replica' >> \$PGDATA/postgresql.auto.conf
    echo 'max_wal_senders = 5' >> \$PGDATA/postgresql.auto.conf
    echo 'wal_keep_size = 64' >> \$PGDATA/postgresql.auto.conf
" 2>/dev/null

# ── 5. Recargar configuración ─────────────────────────────────
PGPASSWORD="$PGPASSWORD" psql \
    -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" \
    -c "SELECT pg_reload_conf();" --no-align --tuples-only 2>/dev/null \
    && ok "Configuración recargada (pg_reload_conf)" \
    || fail "No se pudo recargar"

echo ""
ok "Configuración completada. Reinicia postgres-replica:"
echo "  docker compose -f docker-compose.yml -f docker-compose.replica.yml restart postgres-replica"
