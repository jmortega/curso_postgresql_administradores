# pg-ha-lab — Clúster PostgreSQL de Alta Disponibilidad

> Stack completo con **Patroni + etcd + HAProxy + PgBouncer** en una sola máquina.
> Simula un clúster de producción con failover automático, balanceo de carga y pool de conexiones.

---

## Arquitectura

```
                    ┌─────────────────────────────────────────────┐
                    │              Red: pg_ha_net                  │
                    │           (172.30.0.0/24)                   │
                    │                                              │
Tu App              │  ┌─────────────────────────────────────┐    │
    │               │  │  HAProxy (.40)                       │    │
    │  :5000 (W)    │  │  :5000 → primario   (GET /primary)  │    │
    ├──────────────►│  │  :5001 → réplicas   (GET /replica)  │    │
    │  :5001 (R)    │  │  :7000 → stats UI                   │    │
    │               │  └────────┬──────────────────┬──────────┘    │
    │  :6432        │           │                  │               │
    │  (pgbouncer)  │  ┌────────▼────────┐ ┌──────▼──────┐       │
    └──────────────►│  │ PgBouncer (.30) │ │    etcd (.10)│       │
                    │  │ pool=50 real    │ │  DCS/consenso│       │
                    │  └────────┬────────┘ └─────────────┘        │
                    │           │                                   │
                    │  ┌────────▼────────────────────────┐        │
                    │  │  pg-node1 (.20) — PRIMARIO       │        │
                    │  │  pg-node2 (.21) — réplica 1      │        │
                    │  │  pg-node3 (.22) — réplica 2      │        │
                    │  │  PostgreSQL 16 + Patroni          │        │
                    │  └─────────────────────────────────┘        │
                    └─────────────────────────────────────────────┘
```

### Puertos expuestos

| Puerto | Servicio | Uso |
|--------|----------|-----|
| `5000` | HAProxy → escritura | `INSERT`, `UPDATE`, `DELETE` — siempre al primario |
| `5001` | HAProxy → lectura | `SELECT` — réplicas en round-robin |
| `5432` | pg-node1 directo | Acceso directo para diagnóstico |
| `5433` | pg-node2 directo | Acceso directo para diagnóstico |
| `5434` | pg-node3 directo | Acceso directo para diagnóstico |
| `6432` | PgBouncer | Punto de entrada para aplicaciones (pool) |
| `7000` | HAProxy stats | Dashboard HTTP en tiempo real |
| `8008` | Patroni REST API node1 | Health checks y gestión |
| `8009` | Patroni REST API node2 | Health checks y gestión |
| `8010` | Patroni REST API node3 | Health checks y gestión |
| `2379` | etcd | DCS (solo para diagnóstico) |

---

## Prerequisitos

```bash
docker --version      # Docker 20+
docker compose version # Compose v2
```

---

## Inicio rápido

```bash
# dar permisos de ejecucicon
chmod +x scripts/*.sh

# 1. Construir imagen Patroni y levantar todo el stack (~4 min)
docker compose up --build -d

# 2. Seguir la inicialización
docker compose logs -f pg-node1

# 3. Estado completo del clúster
chmod +x scripts/cluster_status.sh
./scripts/cluster_status.sh

# 4. Modo watch (refresco cada 5s)
./scripts/cluster_status.sh --watch
```

**Salida esperada tras ~3 minutos:**

```
▸ Patroni — clúster pg-ha-cluster:
+ Cluster: pg-ha-cluster ---+---------+-----------+
| Member   | Host      | Role    | State   | TL | Lag |
+----------+-----------+---------+---------+----+-----+
| pg-node1 | 172.30... | Leader  | running |  1 |     |
| pg-node2 | 172.30... | Replica | running |  1 |   0 |
| pg-node3 | 172.30... | Replica | running |  1 |   0 |

▸ HAProxy:
  ✓ Escritura  (localhost:5000)
  ✓ Lectura    (localhost:5001)

▸ PgBouncer:
  ✓ PgBouncer  (localhost:6432)
```

---

## Credenciales

| Usuario | Contraseña | Rol |
|---------|-----------|-----|
| `postgres` | `postgres_lab` | Superusuario |
| `appuser` | `app_lab` | Usuario de aplicación |
| `replicator` | `repl_lab` | Replicación streaming |
| `stats_user` | `stats_lab` | Solo estadísticas PgBouncer |

---

## Prueba 1 — Verificar el clúster inicial

```bash
# Ver el estado de Patroni
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml list
+ Cluster: pg-ha-cluster (7656520250633302053) +----+-----------+-----------------+
| Member   | Host        | Role    | State     | TL | Lag in MB | Tags            |
+----------+-------------+---------+-----------+----+-----------+-----------------+
| pg-node1 | 172.30.0.20 | Leader  | running   |  1 |           | priority: 100   |
+----------+-------------+---------+-----------+----+-----------+-----------------+
| pg-node2 | 172.30.0.21 | Replica | streaming |  1 |         0 | clonefrom: true |
|          |             |         |           |    |           | priority: 80    |
+----------+-------------+---------+-----------+----+-----------+-----------------+
| pg-node3 | 172.30.0.22 | Replica | streaming |  1 |         0 | clonefrom: true |
|          |             |         |           |    |           | priority: 50    |
+----------+-------------+---------+-----------+----+-----------+-----------------+


# Confirmar quién es el primario
PGPASSWORD=postgres_lab
psql -h localhost -p 5000 -U postgres \
    -c "SELECT pg_is_in_recovery(), inet_server_addr();"
# → f (false) = es el primario

# Confirmar que el puerto de lectura apunta a una réplica
PGPASSWORD=postgres_lab
psql -h localhost -p 5001 -U postgres \
    -c "SELECT pg_is_in_recovery(), inet_server_addr();"
# → t (true) = es una réplica

# Ver estado de replicación desde el primario
PGPASSWORD=postgres_lab
psql -h localhost -p 5000 -U postgres -c "
SELECT application_name, state, sync_state,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn)) AS lag
FROM pg_stat_replication;"
```

---

## Prueba 2 — Conexión a través de PgBouncer

### 2.1 pgbouncer.ini

```ini
[databases]
# Formato: alias = host=... port=... dbname=...
mydb = host=127.0.0.1 port=5432 dbname=mi_base_de_datos

# Múltiples bases de datos
# produccion = host=db.ejemplo.com port=5432 dbname=prod_db
# staging    = host=db-staging.ejemplo.com port=5432 dbname=staging_db

[pgbouncer]
#---------------------------------------------------------
# Conexión y escucha
#---------------------------------------------------------
listen_addr = 127.0.0.1        # IP donde escucha PgBouncer
listen_port = 6432             # Puerto de PgBouncer (distinto al 5432 de Postgres)
unix_socket_dir = /var/run/postgresql

#---------------------------------------------------------
# Autenticación
#---------------------------------------------------------
auth_type = md5                # Tipo de autenticación: md5, scram-sha-256, trust
auth_file = /etc/pgbouncer/userlist.txt

#---------------------------------------------------------
# Modo de pooling (crítico)
#---------------------------------------------------------
# transaction  → Una conexión del pool se asigna por transacción (RECOMENDADO)
# session      → Una conexión del pool por sesión de cliente
# statement    → Una conexión por sentencia (muy agresivo, sin soporte para transacciones)
pool_mode = transaction

#---------------------------------------------------------
# Tamaño del pool
#---------------------------------------------------------
max_client_conn = 1000         # Máximo de conexiones desde clientes (apps)
default_pool_size = 50         # Conexiones reales contra PostgreSQL por base de datos
min_pool_size = 10             # Conexiones mínimas siempre activas
reserve_pool_size = 5          # Conexiones extra en caso de saturación
reserve_pool_timeout = 5       # Segundos antes de usar conexiones de reserva

#---------------------------------------------------------
# Timeouts
#---------------------------------------------------------
server_idle_timeout = 600      # Cierra conexiones al servidor inactivas tras 600s
client_idle_timeout = 0        # 0 = sin límite para clientes inactivos
query_timeout = 0              # 0 = sin límite por consulta
connect_timeout = 15           # Segundos para establecer conexión con Postgres

#---------------------------------------------------------
# Logging
#---------------------------------------------------------
logfile = /var/log/pgbouncer/pgbouncer.log
pidfile = /var/run/pgbouncer/pgbouncer.pid
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1

#---------------------------------------------------------
# Estadísticas y administración
#---------------------------------------------------------
stats_period = 60              # Intervalo de estadísticas en segundos
admin_users = postgres         # Usuarios con acceso a la consola de administración
stats_users = stats_user       # Usuarios solo lectura de estadísticas
```

### 2.2 userlist.txt

Contiene los usuarios y sus contraseñas hash que PgBouncer acepta.

```bash
# Conexión de escritura via PgBouncer → HAProxy → primario

# Crear la base de datos appdb en el primario
PGPASSWORD=postgres_lab psql -h localhost -p 5432 -U postgres \
    -c "CREATE DATABASE appdb OWNER appuser;"

# Verificar
PGPASSWORD=postgres_lab psql -h localhost -p 5432 -U postgres \
    -c "\l" | grep appdb

# Probar PgBouncer
PGPASSWORD=app_lab
psql -h localhost -p 6432 -U appuser -d appdb \
    -c "SELECT pg_is_in_recovery(), current_user, inet_server_addr();"


PGPASSWORD=app_lab
psql -h localhost -p 6432 -U appuser -d appdb \
    -c "SELECT pg_is_in_recovery(), current_user, inet_server_addr();"

# Ver estado del pool en la consola de administración
PGPASSWORD=postgres_lab
psql -h localhost -p 6432 -U postgres -d pgbouncer \
    -c "SHOW POOLS;"

# Ver estadísticas de uso
PGPASSWORD=postgres_lab
psql -h localhost -p 6432 -U postgres -d pgbouncer \
    -c "SHOW STATS;"

# Ver servidores reales conectados
PGPASSWORD=postgres_lab
psql -h localhost -p 6432 -U postgres -d pgbouncer \
    -c "SHOW SERVERS;"

# Ver CONFIG
PGPASSWORD=postgres_lab
psql -h localhost -p 6432 -U postgres -d pgbouncer \
    -c "SHOW CONFIG;"

# Ver clientes activos
PGPASSWORD=postgres_lab
psql -h localhost -p 6432 -U postgres -d pgbouncer \
    -c "SHOW CLIENTS;"
```

---

## Prueba 3 — Crear datos y verificar replicación

```bash
# Crear tabla en el primario (vía HAProxy escritura)
PGPASSWORD=postgres_lab
psql -h localhost -p 5000 -U postgres -c "
CREATE TABLE IF NOT EXISTS test_replicacion (
    id      SERIAL PRIMARY KEY,
    mensaje TEXT,
    nodo    TEXT DEFAULT inet_server_addr()::TEXT,
    ts      TIMESTAMPTZ DEFAULT now()
);"

# Insertar datos en el primario
PGPASSWORD=postgres_lab 
psql -h localhost -p 5000 -U postgres -c "
INSERT INTO test_replicacion (mensaje) VALUES
    ('fila 1 desde primario'),
    ('fila 2 desde primario'),
    ('fila 3 desde primario');"

# Verificar que llegaron a las réplicas
PGPASSWORD=postgres_lab
psql -h localhost -p 5433 -U postgres \
    -c "SELECT * FROM test_replicacion;"

PGPASSWORD=postgres_lab
psql -h localhost -p 5434 -U postgres \
    -c "SELECT * FROM test_replicacion;"
```

---

## Prueba 4 — Failover automático (Patroni)

```bash
# Ver quién es el primario antes del failover
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml list

# Simular caída del primario — parar el contenedor
docker stop pg-node1

# Observar en tiempo real cómo Patroni elige un nuevo líder (~15-20s)
./scripts/cluster_status.sh --watch

# Verificar que HAProxy redirigió al nuevo primario automáticamente
PGPASSWORD=postgres_lab psql -h localhost -p 5000 -U postgres \
    -c "SELECT pg_is_in_recovery(), inet_server_addr();"

# Insertar datos en el nuevo primario para confirmar que funciona
PGPASSWORD=postgres_lab psql -h localhost -p 5000 -U postgres -c "
INSERT INTO test_replicacion (mensaje) VALUES ('escrito en el nuevo primario');"

# Reincorporar pg-node1 como réplica
docker start pg-node1
sleep 20

# Verificar estado final — pg-node1 debería volver como réplica
docker exec -u postgres pg-node2 \
    patronictl -c /etc/patroni/patroni.yml list
```

---

## Prueba 5 — Switchover controlado (Patroni)

```bash
# Promover pg-node2 a primario de forma controlada (sin downtime)
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml \
    switchover pg-ha-cluster \
    --master pg-node1 \
    --candidate pg-node2 \
    --scheduled now \
    --force

# Verificar el cambio de líder
sleep 15
docker exec -u postgres pg-node2 \
    patronictl -c /etc/patroni/patroni.yml list

# HAProxy debería apuntar automáticamente al nuevo primario
PGPASSWORD=postgres_lab psql -h localhost -p 5000 -U postgres \
    -c "SELECT pg_is_in_recovery(), inet_server_addr();"
```

---

## Prueba 6 — Gestión de configuración distribuida (Patroni DCS)

```bash
# Ver configuración actual almacenada en etcd
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml show-config

# Cambiar un parámetro en todos los nodos con un solo comando
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml \
    edit-config pg-ha-cluster \
    --set 'postgresql.parameters.work_mem=8MB' \
    --force

# Verificar que se propagó a todos los nodos
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml \
    query --command "SHOW work_mem" --role any

# Ver si hay parámetros pendientes de restart
PGPASSWORD=postgres_lab psql -h localhost -p 5000 -U postgres \
    -c "SELECT name, setting, pending_restart FROM pg_settings WHERE pending_restart = true;"
```

---

## Prueba 7 — Saturar el pool de PgBouncer

```bash
# Generar carga concurrente (requiere pgbench)
PGPASSWORD=app_lab pgbench -h localhost -p 6432 -U appuser -d appdb \
    -i --scale=10 2>/dev/null || \
PGPASSWORD=postgres_lab pgbench -h localhost -p 5000 -U postgres \
    -i --scale=10

# Ejecutar benchmark con 100 clientes concurrentes durante 30 segundos
PGPASSWORD=app_lab pgbench -h localhost -p 6432 -U appuser -d appdb \
    -c 100 -j 4 -T 30 -P 5

# Durante el benchmark, en otra terminal, ver el pool en tiempo real
PGPASSWORD=postgres_lab psql -h localhost -p 6432 -U postgres -d pgbouncer \
    -c "SHOW POOLS;"

# Comparar conexiones reales en PostgreSQL vs clientes en PgBouncer
PGPASSWORD=postgres_lab psql -h localhost -p 5000 -U postgres \
    -c "SELECT count(*) AS conexiones_reales FROM pg_stat_activity WHERE state != 'idle';"
```

---

## Prueba 8 — Diagnóstico de la API REST de Patroni

```bash
# Estado completo del nodo (primario o réplica)
curl -s http://localhost:8008/patroni | python3 -m json.tool
{
    "state": "running",
    "postmaster_start_time": "2026-06-28 18:48:59.047545+00:00",
    "role": "master",
    "server_version": 160014,
    "xlog": {
        "location": 55227424
    },
    "timeline": 1,
    "replication": [
        {
            "usename": "replicator",
            "application_name": "pg-node2",
            "client_addr": "172.30.0.21",
            "state": "streaming",
            "sync_state": "async",
            "sync_priority": 0
        },
        {
            "usename": "replicator",
            "application_name": "pg-node3",
            "client_addr": "172.30.0.22",
            "state": "streaming",
            "sync_state": "async",
            "sync_priority": 0
        }
    ],
    "dcs_last_seen": 1782679130,
    "tags": {
        "priority": 100
    },
    "database_system_identifier": "7656520250633302053",
    "patroni": {
        "version": "3.3.0",
        "scope": "pg-ha-cluster",
        "name": "pg-node1"
    }
}

# Health check del primario (200 = es primario, 503 = no es primario)
$ curl -s http://localhost:8008/primary |  python3 -m json.tool
{
    "state": "running",
    "postmaster_start_time": "2026-06-28 18:48:59.047545+00:00",
    "role": "master",
    "server_version": 160014,
    "xlog": {
        "location": 55227424
    },
    "timeline": 1,
    "replication": [
        {
            "usename": "replicator",
            "application_name": "pg-node2",
            "client_addr": "172.30.0.21",
            "state": "streaming",
            "sync_state": "async",
            "sync_priority": 0
        },
        {
            "usename": "replicator",
            "application_name": "pg-node3",
            "client_addr": "172.30.0.22",
            "state": "streaming",
            "sync_state": "async",
            "sync_priority": 0
        }
    ],
    "dcs_last_seen": 1782679190,
    "tags": {
        "priority": 100
    },
    "database_system_identifier": "7656520250633302053",
    "patroni": {
        "version": "3.3.0",
        "scope": "pg-ha-cluster",
        "name": "pg-node1"
    }
}

# Health check de leader
$ curl -s http://localhost:8008/leader |  python3 -m json.tool
{
    "state": "running",
    "postmaster_start_time": "2026-06-28 18:48:59.047545+00:00",
    "role": "master",
    "server_version": 160014,
    "xlog": {
        "location": 55227424
    },
    "timeline": 1,
    "replication": [
        {
            "usename": "replicator",
            "application_name": "pg-node2",
            "client_addr": "172.30.0.21",
            "state": "streaming",
            "sync_state": "async",
            "sync_priority": 0
        },
        {
            "usename": "replicator",
            "application_name": "pg-node3",
            "client_addr": "172.30.0.22",
            "state": "streaming",
            "sync_state": "async",
            "sync_priority": 0
        }
    ],
    "dcs_last_seen": 1782683210,
    "tags": {
        "priority": 100
    },
    "database_system_identifier": "7656520250633302053",
    "patroni": {
        "version": "3.3.0",
        "scope": "pg-ha-cluster",
        "name": "pg-node1"
    }
}



# Health check de réplica
$ curl -s http://localhost:8009/replica |  python3 -m json.tool
{
    "state": "running",
    "postmaster_start_time": "2026-06-28 18:49:05.149984+00:00",
    "role": "replica",
    "server_version": 160014,
    "xlog": {
        "received_location": 55227424,
        "replayed_location": 55227424,
        "replayed_timestamp": "2026-06-28 19:55:27.049009+00:00",
        "paused": false
    },
    "timeline": 1,
    "replication_state": "streaming",
    "dcs_last_seen": 1782679320,
    "tags": {
        "clonefrom": true,
        "priority": 80
    },
    "database_system_identifier": "7656520250633302053",
    "patroni": {
        "version": "3.3.0",
        "scope": "pg-ha-cluster",
        "name": "pg-node2"
    }
}



# Historial de eventos del clúster
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml \
    history pg-ha-cluster

# Configuración actual en el DCS
docker exec etcd etcdctl \
    --endpoints=http://localhost:2379 \
    get /db/pg-ha-cluster/config
```

---

## Prueba 9 — HAProxy stats

A continuación se muestra una configuración completa y comentada para un clúster PostgreSQL con Patroni:

```haproxy
#---------------------------------------------------------------------
# Configuración global
#---------------------------------------------------------------------
global
    maxconn 100
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

#---------------------------------------------------------------------
# Valores por defecto
#---------------------------------------------------------------------
defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    retries 3

#---------------------------------------------------------------------
# Panel de estadísticas (opcional pero recomendado)
#---------------------------------------------------------------------
listen stats
    bind *:7000
    mode http
    stats enable
    stats uri /
    stats refresh 5s
    stats show-legends
    stats show-node

#---------------------------------------------------------------------
# Frontend de escritura — apunta siempre al nodo PRIMARIO
# Puerto 5000: punto de entrada para escrituras
#---------------------------------------------------------------------
listen postgres_primary
    bind *:5000
    mode            tcp
    option          httpchk GET /primary
    http-check      expect status 200
    default-server  inter 3s fall 3 rise 2 on-marked-down shutdown-sessions

    # Nodos del clúster — HAProxy interroga el puerto 8008 de Patroni
    server postgresql-node1 192.168.1.101:5432 maxconn 100 check port 8008
    server postgresql-node2 192.168.1.102:5432 maxconn 100 check port 8008
    server postgresql-node3 192.168.1.103:5432 maxconn 100 check port 8008

#---------------------------------------------------------------------
# Frontend de lectura — distribuye entre las RÉPLICAS
# Puerto 5001: punto de entrada para lecturas (opcional)
#---------------------------------------------------------------------
listen postgres_replicas
    bind *:5001
    mode            tcp
    balance         roundrobin
    option          httpchk GET /replica
    http-check      expect status 200
    default-server  inter 3s fall 3 rise 2 on-marked-down shutdown-sessions

    server postgresql-node1 192.168.1.101:5432 maxconn 100 check port 8008
    server postgresql-node2 192.168.1.102:5432 maxconn 100 check port 8008
    server postgresql-node3 192.168.1.103:5432 maxconn 100 check port 8008
```

### Parámetros explicados

| Parámetro | Descripción |
|---|---|
| `option httpchk GET /primary` | HAProxy usa HTTP para preguntar a Patroni quién es el primario |
| `http-check expect status 200` | Solo acepta el nodo si Patroni responde con `200 OK` |
| `inter 3s` | Intervalo entre health checks: cada 3 segundos |
| `fall 3` | Marca el nodo como caído tras 3 fallos consecutivos |
| `rise 2` | Marca el nodo como recuperado tras 2 éxitos consecutivos |
| `on-marked-down shutdown-sessions` | Cierra las sesiones activas si el nodo cae |
| `check port 8008` | Puerto donde Patroni expone su API REST |

---

```bash
# Abrir en el navegador
http://localhost:7000

# O via API de estadísticas en formato CSV
curl -s "http://localhost:7000/;csv" | head -5

# Ver estado de backends vía socket (si está disponible)
docker exec haproxy sh -c \
    'echo "show stat" | socat stdio /var/run/haproxy/admin.sock 2>/dev/null' \
    | cut -d',' -f1,2,18,19 | head -10
```

---

## Pausa y mantenimiento

```bash
# Pausar la gestión automática de Patroni (útil para mantenimiento planificado)
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml pause pg-ha-cluster --wait

# Realizar mantenimiento...

# Reanudar
docker exec -u postgres pg-node1 \
    patronictl -c /etc/patroni/patroni.yml resume pg-ha-cluster --wait

# Recargar configuración de PgBouncer sin cortar conexiones
PGPASSWORD=postgres_lab psql -h localhost -p 6432 -U postgres -d pgbouncer \
    -c "RELOAD;"
```

## Prueba 10 - Comandos de verificación de etcd

### Health y disponibilidad

```bash
# Estado de salud del nodo etcd
docker exec etcd etcdctl --endpoints=http://localhost:2379 endpoint health

# Estado detallado en formato tabla
docker exec etcd etcdctl --endpoints=http://localhost:2379 endpoint status --write-out=table

# Estado en JSON con el líder del clúster etcd
docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    endpoint status --write-out=json | python3 -m json.tool

# Listar todos los miembros del clúster
docker exec etcd etcdctl --endpoints=http://localhost:2379 member list --write-out=table
```

### Claves del clúster Patroni en etcd

```bash
# Ver todas las claves que gestiona Patroni
docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    get / --prefix --keys-only

# Ver quién es el líder actual del clúster pg-ha-cluster
docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    get /pg-ha-cluster/leader

# Ver configuración DCS almacenada por Patroni
docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    get /pg-ha-cluster/config | python3 -m json.tool

# Ver estado de todos los nodos registrados
docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    get /pg-ha-cluster/ --prefix

# Ver el historial de timelines (optime history)
docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    get /pg-ha-cluster/history
```

### Rendimiento y métricas

```bash
# Latencia del clúster etcd
docker exec etcd etcdctl --endpoints=http://localhost:2379 check perf

# Métricas internas en formato Prometheus
curl -s http://localhost:2379/metrics \
    | grep -E "etcd_server_leader|etcd_server_proposals|etcd_disk"

# Número de claves almacenadas
curl -s http://localhost:2379/metrics | grep etcd_debugging_mvcc_keys_total
```

### Diagnóstico avanzado

```bash
# Ver logs del contenedor etcd
docker logs etcd --tail 30

# Comprobar conectividad desde los nodos Patroni a etcd
docker exec pg-node1 python3 -c \
    "import urllib.request; print(urllib.request.urlopen('http://etcd:2379/health').read())"

# Ver cuánto tiempo lleva etcd corriendo
docker inspect etcd --format='Started: {{.State.StartedAt}} | Status: {{.State.Status}}'

# Compactar el historial de revisiones (mantenimiento)
REVISION=$(docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    endpoint status --write-out=json | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['Status']['header']['revision'])")
docker exec etcd etcdctl --endpoints=http://localhost:2379 compact "$REVISION"

# Desfragmentar la base de datos de etcd
docker exec etcd etcdctl --endpoints=http://localhost:2379 defrag
```

### Seguimiento en tiempo real durante un failover

```bash
# Observar qué escribe Patroni en etcd durante un failover
docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    watch /pg-ha-cluster/ --prefix

# Ver el lock de liderazgo (quién lo tiene y cuándo expira)
docker exec etcd etcdctl --endpoints=http://localhost:2379 \
    get /pg-ha-cluster/leader -w json | python3 -m json.tool
```

---

## Comandos de diagnóstico rápido

```bash
# Logs de todos los servicios
docker compose logs --tail 20

# Logs de un servicio específico
docker logs pg-node1 --tail 30
docker logs haproxy --tail 20
docker logs pgbouncer --tail 20

# Estado de contenedores
docker compose ps

# Detener todo
docker compose down

# Destruir todo incluyendo volúmenes
docker compose down -v
```

---

## Resumen de puertos

| Puerto | Propósito |
|---|---|
| `5000` | Conexiones de **escritura** → nodo primario |
| `5001` | Conexiones de **lectura** → réplicas (round-robin) |
| `7000` | Panel de **estadísticas** de HAProxy (HTTP) |
| `8008` | API REST de **Patroni** (health check interno) |

## Troubleshooting

| Síntoma | Causa probable | Solución |
|---------|---------------|---------|
| `no leader` en patronictl | etcd no disponible | `docker logs etcd` |
| HAProxy lectura no disponible | Sin réplicas conectadas | Esperar a que pg-node2/3 arranquen |
| PgBouncer rechaza conexión | Hash md5 incorrecto | Regenerar `userlist.txt` |
| Failover no ocurre | `primary_visibility_consensus` | Ver logs de repmgrd |
| Réplica con lag creciente | Red o disco saturado | Ver `pg_stat_replication` |
| `split-brain` | Pérdida de quórum etcd | Restaurar etcd primero |

## Referencias

- [Documentación oficial de HAProxy](https://www.haproxy.org/#docs)
- [Documentación de Patroni](https://patroni.readthedocs.io/)
- [HAProxy Configuration Manual](https://cbonte.github.io/haproxy-dconv/)
- [Documentación oficial de Patroni](https://patroni.readthedocs.io/)
- [etcd documentation](https://etcd.io/docs/)
- [PostgreSQL High Availability](https://www.postgresql.org/docs/current/high-availability.html)

