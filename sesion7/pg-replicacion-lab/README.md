# 🔁 Lab: Replicación y Failover PostgreSQL con Docker

> Clúster de 3 nodos PostgreSQL + repmgr ejecutándose en **una sola máquina**
> con Docker Compose. Incluye scripts para simular fallos, medir el RTO y
> practicar switchover y failover automático.

---

## 🗂️ Estructura del laboratorio

```
pg-replicacion-lab/
├── docker-compose.yml               # Orquestación del clúster
├── Dockerfile                       # Imagen PostgreSQL 16 + repmgr
│
├── configs/
│   ├── primary/
│   │   ├── postgresql.conf          # Config del nodo primario (síncrono habilitado)
│   │   └── pg_hba.conf              # Autenticación de todos los nodos
│   ├── standby1/
│   │   └── postgresql.conf          # Config standby1 (hot_standby, restore_command)
│   ├── standby2/
│   │   └── postgresql.conf          # Config standby2 (igual que standby1)
│   └── repmgr/
│       ├── repmgr-primary.conf      # repmgr nodo primario (priority=100)
│       ├── repmgr-standby1.conf     # repmgr standby1 (priority=100, failover automático)
│       └── repmgr-standby2.conf     # repmgr standby2 (priority=50)
│
└── scripts/
    ├── entrypoint_primary.sh        # Arranque e inicialización del primario
    ├── entrypoint_standby.sh        # Clonado, registro y arranque del standby
    ├── notify_event.sh              # Log de eventos repmgr
    ├── cluster_status.sh            # Ver estado del clúster desde el host
    ├── simulate_failure.sh          # Simular fallo (crash / stop / network)
    ├── rejoin_primary.sh            # Reincorporar el antiguo primario
    ├── switchover.sh                # Switchover controlado
    └── monitor_lag.sh               # Monitor de lag en tiempo real
```

---

## 🌐 Arquitectura simulada

```
TU MÁQUINA (host)
│
│   ┌─────────────────────────────────────────────────────────┐
│   │          Red Docker: pg_cluster_net (172.29.0.0/24)     │
│   │                                                         │
│   │  pg-primary       pg-standby1       pg-standby2         │
│   │  172.29.0.10      172.29.0.11       172.29.0.12         │
│   │  localhost:5432   localhost:5433    localhost:5434       │
│   │                                                         │
│   │  Primario ──────▶ Standby1 (síncrono,  priority=100)   │
│   │  Primario ──────▶ Standby2 (asíncrono, priority=50)    │
│   │                                                         │
│   │  repmgrd en cada nodo → failover automático             │
│   └─────────────────────────────────────────────────────────┘
│
├── psql -p 5432  → pg-primary
├── psql -p 5433  → pg-standby1
└── psql -p 5434  → pg-standby2
```

| Nodo | Contenedor | Puerto host | IP interna | Rol inicial |
|---|---|---|---|---|
| Primario | `pg-primary` | `5432` | `172.29.0.10` | Lectura/Escritura |
| Standby síncrono | `pg-standby1` | `5433` | `172.29.0.11` | Solo Lectura |
| Standby asíncrono | `pg-standby2` | `5434` | `172.29.0.12` | Solo Lectura |

---

## ⚡ Inicio rápido

### Prerequisitos

```bash
docker --version          # 24+
docker compose version    # 2.20+
psql --version            # cliente PostgreSQL en el host (para los scripts)
```

### 1 — Construir y levantar el clúster

```bash
cd pg-replicacion-lab

# Dar permisos de ejecución a los scripts
chmod +x scripts/*.sh

# Construir la imagen y levantar los 3 nodos
# (la primera vez tarda ~3 min por la descarga de la imagen base)
docker compose up --build -d

# Seguir los logs de inicialización
docker compose logs -f
```

> El clúster tarda ~2-3 minutos en estar completamente operativo.
> pg-standby1 espera a pg-primary, y pg-standby2 espera a pg-standby1.

### 2 — Verificar que el clúster está listo

```bash
# Estado completo del clúster
./scripts/cluster_status.sh
```

**Salida esperada:**

```
════════════════════════════════════════════════════
  Estado del Clúster PostgreSQL — 2026-07-15 12:29:41
════════════════════════════════════════════════════

▸ Contenedores Docker:
NAME          STATUS                        PORTS
pg-primary    Up About a minute (healthy)   0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
pg-standby1   Up About a minute (healthy)   0.0.0.0:5433->5432/tcp, [::]:5433->5432/tcp
pg-standby2   Up About a minute (healthy)   0.0.0.0:5434->5432/tcp, [::]:5434->5432/tcp

▸ Disponibilidad de nodos:
  ✓ pg-primary (localhost:5432) → PRIMARY
  ✓ pg-standby1 (localhost:5433) → STANDBY
  ✓ pg-standby2 (localhost:5434) → STANDBY

▸ Replicación (desde primario):
  standby   |     ip      |   state   | sync_state |    lag    | estado 
------------+-------------+-----------+------------+-----------+--------
 pgstandby1 | 172.29.0.11 | streaming | sync       | 0.002251s | 🟢 ok
 pgstandby2 | 172.29.0.12 | streaming | potential  | 0.002574s | 🟢 ok
(2 rows)


▸ Estado repmgr:
 ID | Name        | Role    | Status    | Upstream     | Location | Priority | Timeline | Connection string                                                                         
----+-------------+---------+-----------+--------------+----------+----------+----------+--------------------------------------------------------------------------------------------
 1  | pg-primary  | primary | * running |              | default  | 100      | 1        | host=pg-primary port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5 
 2  | pg-standby1 | standby |   running | ! pg-primary | default  | 100      | 1        | host=pg-standby1 port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5
 3  | pg-standby2 | standby |   running | ! pg-primary | default  | 50       | 1        | host=pg-standby2 port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5

  (repmgr no disponible — comprobar: docker exec pg-primary repmgr -f /etc/repmgr/repmgr.conf cluster show)

▸ Lag en bytes:
  standby   | lag_bytes | sync_state 
------------+-----------+------------
 pgstandby1 | 0 bytes   | sync
 pgstandby2 | 0 bytes   | potential
(2 rows)



$ docker exec -u postgres pg-primary \
    repmgr -f /etc/repmgr/repmgr.conf cluster show
WARNING: node "pg-standby1" not found in "pg_stat_replication"
WARNING: node "pg-standby2" not found in "pg_stat_replication"
WARNING: following issues were detected
  - node "pg-standby1" (ID: 2) is not attached to its upstream node "pg-primary" (ID: 1)
  - node "pg-standby2" (ID: 3) is not attached to its upstream node "pg-primary" (ID: 1)

 ID | Name        | Role    | Status    | Upstream     | Location | Priority | Timeline | Connection string                                                                         
----+-------------+---------+-----------+--------------+----------+----------+----------+--------------------------------------------------------------------------------------------
 1  | pg-primary  | primary | * running |              | default  | 100      | 1        | host=pg-primary port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5 
 2  | pg-standby1 | standby |   running | ! pg-primary | default  | 100      | 1        | host=pg-standby1 port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5
 3  | pg-standby2 | standby |   running | ! pg-primary | default  | 50       | 1        | host=pg-standby2 port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5

```


---

## Práctica 1: Verificar la replicación

### Desde el host (psql externo)

```bash
# Conexión al primario
psql -h localhost -p 5432 -U postgres -d dwh

# Conexión a standby1
psql -h localhost -p 5433 -U postgres -d dwh

# Conexión a standby2
psql -h localhost -p 5434 -U postgres -d dwh
```

### Verificar replicación en tiempo real

```bash
# Terminal 1: Insertar datos en el primario
psql -h localhost -p 5432 -U postgres -d dwh -c "
    INSERT INTO pedidos (cliente_id, estado, importe)
    SELECT (random()*1000)::INT, 'pendiente', round((random()*500)::numeric,2)
    FROM generate_series(1, 100);
    SELECT count(*) AS total_pedidos FROM pedidos;"

# Terminal 2: Verificar que llegaron a los standbys
psql -h localhost -p 5433 -U postgres -d dwh -c \
    "SELECT count(*) AS en_standby1 FROM pedidos;"

psql -h localhost -p 5434 -U postgres -d dwh -c \
    "SELECT count(*) AS en_standby2 FROM pedidos;"
```

### Verificar el modo de replicación (síncrono vs asíncrono)

pgstandby1 → sync — es el síncrono activo. El primario espera su confirmación antes de hacer commit.
pgstandby2 → potential — está replicando en streaming igual que el otro, pero el primario no espera su confirmación. Actúa como asíncrono, pero si pgstandby1 cae, PostgreSQL lo promociona automáticamente a sync sin intervención manual.

```sql
-- Ejecutar en el primario (puerto 5432)
psql -h localhost -p 5432 -U postgres -d dwh -c "
    SELECT
    application_name,
    state,
    sync_state,        -- 'sync' = síncrono | 'async' = asíncrono
    sync_priority,     -- prioridad en la elección de síncrono
    replay_lag
FROM pg_stat_replication
ORDER BY sync_priority DESC;"
 application_name |   state   | sync_state | sync_priority | replay_lag 
------------------+-----------+------------+---------------+------------
 pgstandby2       | streaming | potential  |             2 | 
 pgstandby1       | streaming | sync       |             1 | 
(2 rows)

```

### Probar que el standby1 es de solo lectura

```bash
# Esto debe FALLAR (Error: cannot execute INSERT in a read-only transaction)
psql -h localhost -p 5433 -U postgres -d dwh -c \
    "INSERT INTO pedidos (cliente_id, estado) VALUES (1, 'test');"
ERROR:  cannot execute INSERT in a read-only transaction


# Esto debe FUNCIONAR (SELECT en standby)
psql -h localhost -p 5433 -U postgres -d dwh -c \
    "SELECT count(*) FROM pedidos;"
 count 
-------
   100
(1 row)

```

---

## Práctica 2: Modos de replicación síncrono y asíncrono

### Cambiar a replicación completamente asíncrona

```bash
# Conectar al primario
psql -h localhost -p 5432 -U postgres

-- Desactivar replicación síncrona
ALTER SYSTEM SET synchronous_standby_names = '';
SELECT pg_reload_conf();

-- Verificar
SHOW synchronous_standby_names;
SELECT application_name, sync_state FROM pg_stat_replication;
-- sync_state debe cambiar de 'sync' a 'async' en pg-standby1

 application_name | sync_state 
------------------+------------
 pgstandby1       | async
 pgstandby2       | async
(2 rows)

```

### Probar el impacto en la latencia de escritura en primary

El COMMIT con remote_apply tarda ~3ms más — casi 3 veces más lento que el asíncrono. Esa diferencia es precisamente el tiempo que el primario espera a que pg-standby1
(la réplica síncrona) reciba el WAL, lo escriba y lo aplique antes de confirmar el commit al cliente. Con off, el primario no espera a que su propio WAL local se sincronice a disco, así que el COMMIT es casi instantáneo.

```bash
# Con replicación asíncrona
psql -h localhost -p 5432 -U postgres -d dwh << 'EOF'
\timing on
SET synchronous_commit = off;
BEGIN;
INSERT INTO pedidos (cliente_id, estado, importe)
    SELECT (random()*100)::INT, 'pendiente', 10.00
    FROM generate_series(1, 1000);
COMMIT;
EOF

Timing is on.
SET
Time: 1,550 ms
BEGIN
Time: 1,381 ms
INSERT 0 1000
Time: 9,683 ms
COMMIT
Time: 1,618 ms

# Con replicación síncrona
psql -h localhost -p 5432 -U postgres -d dwh << 'EOF'
\timing on
SET synchronous_commit = remote_apply;
BEGIN;
INSERT INTO pedidos (cliente_id, estado, importe)
    SELECT (random()*100)::INT, 'pendiente', 10.00
    FROM generate_series(1, 1000);
COMMIT;
EOF

Timing is on.
SET
Time: 1,090 ms
BEGIN
Time: 0,815 ms
INSERT 0 1000
Time: 6,434 ms
COMMIT
Time: 4,779 ms


```

### Restaurar la configuración síncrona

```bash
$ psql -h localhost -p 5432 -U postgres \
  -c "ALTER SYSTEM SET synchronous_standby_names = 'FIRST 1 (pgstandby1,pgstandby2)';" \
  -c "SELECT pg_reload_conf();"
ALTER SYSTEM
 pg_reload_conf 
----------------
 t
(1 row)


-- Verificar
$ psql -h localhost -p 5432 -U postgres -c "SHOW synchronous_standby_names;
SELECT application_name, sync_state FROM pg_stat_replication;"
    synchronous_standby_names    
---------------------------------
 FIRST 1 (pgstandby1,pgstandby2)
(1 row)

 application_name | sync_state 
------------------+------------
 pgstandby1       | sync
 pgstandby2       | potential
(2 rows)

```

---

## Práctica 3: Estado del clúster con repmgr

```bash

#comprobar que esté cargado repmgr
docker exec pg-primary psql -U postgres -c "SHOW shared_preload_libraries;"

# Ver el estado del clúster desde dentro de un contenedor
docker exec -u postgres pg-primary \
    /usr/lib/postgresql/16/bin/repmgr \
    -f /etc/repmgr/repmgr.conf \
    cluster show

# Ver los eventos registrados por repmgr
Esta tabla es el registro de auditoría interno de repmgr — cada vez que ocurre un evento relevante en el clúster (creación, clonado, registro, promoción, etc.),
repmgr inserta una fila.

docker exec -u postgres pg-primary \
    /usr/lib/postgresql/16/bin/repmgr \
    -f /etc/repmgr/repmgr.conf \
    cluster events --limit 10

# Ver el historial de monitorización
psql -h localhost -p 5432 -U repmgr -d repmgr -c "
    SELECT n.node_name, h.last_monitor_time, h.replication_lag, h.apply_lag
    FROM repmgr.monitoring_history h
    JOIN repmgr.nodes n ON n.node_id = h.standby_node_id
    ORDER BY h.last_monitor_time DESC
    LIMIT 10;"

# Ver los logs de repmgrd en tiempo real
docker logs pg-primary -f --tail 20
docker logs pg-standby1 -f --tail 20
docker logs pg-standby2 -f --tail 20
```

---

## Práctica 4: Simulación de fallo y failover automático

### Opción A — Script automatizado (recomendado)

```bash
# Abrir 3 terminales simultáneamente:

# Terminal 1: Monitorización en tiempo real
./scripts/monitor_lag.sh

# Terminal 2: Estado del clúster (se actualiza cada 3s)
./scripts/cluster_status.sh --watch

# Terminal 3: Simular el fallo
./scripts/simulate_failure.sh crash     # Crash del proceso PostgreSQL
# o:
./scripts/simulate_failure.sh stop      # Parada limpia del contenedor
# o:
./scripts/simulate_failure.sh network   # Partición de red
```

### Opción B — Pasos manuales

```bash
# Paso 1: Ver el estado inicial
psql -h localhost -p 5432 -U postgres \
    -c "SELECT application_name, sync_state, replay_lag FROM pg_stat_replication;"

# Paso 2: Insertar datos de prueba y registrar cuántos hay
psql -h localhost -p 5432 -U postgres -d dwh \
    -c "INSERT INTO pedidos (cliente_id, estado, importe)
        SELECT 1, 'pendiente', 100.0 FROM generate_series(1,50);
        SELECT count(*) FROM pedidos;"

# Paso 3: Simular el fallo del primario
docker stop pg-primary   # o: docker kill --signal=SIGKILL pg-primary

# Paso 4: Medir el RTO — ¿cuánto tarda en aparecer un nuevo primario?
watch -n 1 '
    echo "=== $(date) ===";
    pg_isready -h localhost -p 5432 -q && echo "5432: UP" || echo "5432: DOWN";
    pg_isready -h localhost -p 5433 -q && \
        psql -h localhost -p 5433 -U postgres -At \
        -c "SELECT CASE WHEN pg_is_in_recovery() THEN \"5433: STANDBY\" ELSE \"5433: PRIMARY ✓\" END" \
        2>/dev/null || echo "5433: DOWN";
    pg_isready -h localhost -p 5434 -q && \
        psql -h localhost -p 5434 -U postgres -At \
        -c "SELECT CASE WHEN pg_is_in_recovery() THEN \"5434: STANDBY\" ELSE \"5434: PRIMARY ✓\" END" \
        2>/dev/null || echo "5434: DOWN";
'

# Paso 5: Cuando pg-standby1 se promueva, verificar los datos
psql -h localhost -p 5433 -U postgres -d dwh \
    -c "SELECT count(*), pg_is_in_recovery() FROM pedidos;"
# pg_is_in_recovery() debe ser: f (es primario)

# Paso 6: Verificar que se pueden hacer escrituras en el nuevo primario
psql -h localhost -p 5433 -U postgres -d dwh \
    -c "INSERT INTO pedidos (cliente_id, estado, importe)
        VALUES (9999, 'procesado', 500.00);"
```

### Promover de forma manual
```bash
docker exec -u postgres pg-standby1 \
    repmgr -f /etc/repmgr/repmgr.conf \
    standby promote -v
NOTICE: using provided configuration file "/etc/repmgr/repmgr.conf"
INFO: connected to standby, checking its state
INFO: searching for primary node
INFO: checking if node 1 is primary
ERROR: connection to database failed
DETAIL: 
could not translate host name "pg-primary" to address: Name or service not known

DETAIL: attempted to connect using:
  user=repmgr password=repmgr_lab connect_timeout=5 dbname=repmgr host=pg-primary port=5432 fallback_application_name=repmgr options=-csearch_path=
INFO: checking if node 3 is primary
INFO: checking if node 2 is primary
WARNING: 1 sibling nodes found, but option "--siblings-follow" not specified
DETAIL: these nodes will remain attached to the current primary:
  pg-standby2 (node ID: 3)
NOTICE: promoting standby to primary
DETAIL: promoting server "pg-standby1" (ID: 2) using pg_promote()
NOTICE: waiting up to 60 seconds (parameter "promote_check_timeout") for promotion to complete
INFO: standby promoted to primary after 1 second(s)
NOTICE: STANDBY PROMOTE successful
DETAIL: server "pg-standby1" (ID: 2) was successfully promoted to primary
INFO: executing notification command for event "standby_promote"
DETAIL: command is:
  /scripts/notify_event.sh 2 standby_promote 1 "2026-06-26 20:08:11.045494+00" "server \"pg-standby1\" (ID: 2) was successfully promoted to primary"
[2026-06-26 20:08:11.045494+00] 🔴 FAILOVER | Nodo=2 Evento=standby_promote Status=OK | server "pg-standby1" (ID: 2) was successfully promoted to primary
```

### Secuencia de logs esperada durante el failover

```bash
# Observar los eventos de repmgr en pg-standby1
docker logs pg-standby1 --follow 2>&1 | grep -E "NOTICE|WARNING|ERROR|FAILOVER|promote"
```

```
[10:32:20] WARNING  unable to connect to upstream node "pg-primary" (1)
[10:32:25] WARNING  attempt 1 of 4 to reconnect...
[10:32:30] WARNING  attempt 2 of 4 to reconnect...
[10:32:35] WARNING  attempt 3 of 4 to reconnect...
[10:32:40] WARNING  attempt 4 of 4 to reconnect...
[10:32:40] NOTICE   this node is the most advanced standby
[10:32:41] NOTICE   promoting this node to primary...
[10:32:42] NOTICE   STANDBY PROMOTE successful
[10:32:42] INFO     node "pg-standby1" (node ID: 2) promoted to primary
```

---

## Práctica 5: Reincorporar el nodo caído

```bash
# Después de un failover, reincorporar pg-primary como standby
./scripts/rejoin_primary.sh

# Verificar que quedó como standby del nuevo primario
./scripts/cluster_status.sh

════════════════════════════════════════════════════
  Estado del Clúster PostgreSQL — 2026-07-15 19:17:14
════════════════════════════════════════════════════

▸ Contenedores Docker:
NAME          STATUS                    PORTS
pg-primary    Up 19 minutes (healthy)   0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
pg-standby1   Up 2 hours (healthy)      0.0.0.0:5433->5432/tcp, [::]:5433->5432/tcp
pg-standby2   Up 2 hours (healthy)      0.0.0.0:5434->5432/tcp, [::]:5434->5432/tcp

▸ Disponibilidad de nodos:
  ✓ pg-primary (localhost:5432) → STANDBY
  ✓ pg-standby1 (localhost:5433) → PRIMARY
  ✓ pg-standby2 (localhost:5434) → STANDBY

▸ Replicación (desde primario):
  standby   |     ip      |   state   | sync_state |    lag    | estado 
------------+-------------+-----------+------------+-----------+--------
 pg-primary | 172.29.0.10 | streaming | async      | 0.003483s | 🟢 ok
(1 row)


▸ Estado repmgr:
 ID | Name        | Role    | Status    | Upstream     | Location | Priority | Timeline | Connection string                                                                         
----+-------------+---------+-----------+--------------+----------+----------+----------+--------------------------------------------------------------------------------------------
 1  | pg-primary  | standby |   running | pg-standby1  | default  | 100      | 2        | host=pg-primary port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5 
 2  | pg-standby1 | primary | * running |              | default  | 100      | 2        | host=pg-standby1 port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5
 3  | pg-standby2 | standby |   running | ! pg-primary | default  | 50       | 1        | host=pg-standby2 port=5432 dbname=repmgr user=repmgr password=repmgr_lab connect_timeout=5

  (repmgr no disponible — comprobar: docker exec pg-primary repmgr -f /etc/repmgr/repmgr.conf cluster show)

▸ Lag en bytes:
  standby   | lag_bytes | sync_state 
------------+-----------+------------
 pg-primary | 0 bytes   | async
(1 row)

pg-primary sigue registrado en repmgr como primary, aunque Postgres ya sabe que es standby. Hay que actualizar su propio registro:

docker exec -u postgres pg-primary repmgr -f /etc/repmgr/repmgr.conf standby register --force

$ psql -h localhost -p 5433 -U postgres -d dwh \
    -c "SELECT count(*), pg_is_in_recovery() FROM pedidos;"
 count | pg_is_in_recovery 
-------+-------------------
  2101 | f
(1 row)

linux@linux-EVO14-A8:~/Descargas/sesion7/pg-replicacion-lab$ psql -h localhost -p 5432 -U postgres -d dwh     -c "SELECT count(*), pg_is_in_recovery() FROM pedidos;"
 count | pg_is_in_recovery 
-------+-------------------
  2101 | t
(1 row)

linux@linux-EVO14-A8:~/Descargas/sesion7/pg-replicacion-lab$ psql -h localhost -p 5434 -U postgres -d dwh     -c "SELECT count(*), pg_is_in_recovery() FROM pedidos;"
 count | pg_is_in_recovery 
-------+-------------------
  2100 | t
(1 row)

$ psql -h localhost -p 5433 -U postgres -d dwh -c \
    "INSERT INTO pedidos (cliente_id, estado) VALUES (1, 'test');"
INSERT 0 1
linux@linux-EVO14-A8:~/Descargas/sesion7/pg-replicacion-lab$ psql -h localhost -p 5432 -U postgres -d dwh -c     "INSERT INTO pedidos (cliente_id, estado) VALUES (1, 'test');"
ERROR:  cannot execute INSERT in a read-only transaction
linux@linux-EVO14-A8:~/Descargas/sesion7/pg-replicacion-lab$ psql -h localhost -p 5433 -U postgres -d dwh -c     "SELECT count(*) FROM pedidos;"
 count 
-------
  2102
(1 row)

linux@linux-EVO14-A8:~/Descargas/sesion7/pg-replicacion-lab$ psql -h localhost -p 5432 -U postgres -d dwh -c     "SELECT count(*) FROM pedidos;"
 count 
-------
  2102
(1 row)

linux@linux-EVO14-A8:~/Descargas/sesion7/pg-replicacion-lab$ psql -h localhost -p 5433 -U postgres -d dwh -c     "SELECT count(*) FROM pedidos;"
 count 
-------
  2102
(1 row)

Volver al estado incial

promover pg-primary de standby a primary

$ docker exec -u postgres pg-primary repmgr -f /etc/repmgr/repmgr.conf standby promote --force

#Reiniciar pg-standby1
# 1. Confirmar lag = 0
docker exec -u postgres pg-standby1 psql -U postgres -c "
    SELECT application_name, state, sync_state, replay_lag
    FROM pg_stat_replication;"

# 2. Parada limpia del primario actual (pg-standby1)
docker exec -u postgres pg-standby1 \
    /usr/lib/postgresql/16/bin/pg_ctl stop -D /var/lib/postgresql/data -m fast

# 3. Ver la promoción automática en vivo (pg-primary tiene prioridad 100)
docker exec pg-primary tail -f /var/log/repmgr/repmgr.log

# 4. Confirmar que pg-primary ya es primario
docker exec -u postgres pg-primary psql -U postgres -c "SELECT pg_is_in_recovery();"
# esperado: f

# 5. Reincorporar pg-standby1 — con el fix, ahora detectará que
#    pg-primary es el primario real y se purgará/reclonará solo
docker restart pg-standby1
docker logs pg-standby1 -f

# 6. Verificación final
./scripts/cluster_status.sh

#Reiniciar pg-standby2
# 1. Parar postgres limpiamente en pg-standby2
docker exec -u postgres pg-standby2 \
    /usr/lib/postgresql/16/bin/pg_ctl stop -D /var/lib/postgresql/data -m fast

# 2. Verificar el nombre exacto del volumen
docker volume ls | grep standby2

# 3. Purgar sus datos (ajusta el nombre del volumen al que veas en el paso 2)
docker run --rm -v pg-replicacion-lab_pg_standby2_data:/data \
    alpine sh -c "find /data -mindepth 1 -delete"

# 4. Reiniciar — el entrypoint (ya corregido) detecta el primario
#    real dinámicamente y clona desde ahí automáticamente
docker restart pg-standby2
docker logs pg-standby2 -f
```
```

---

## Práctica 6: Monitor en tiempo real

```bash
# Monitorización continua con alertas visuales (cada 3 segundos)
./scripts/monitor_lag.sh

# Intervalo personalizado (cada segundo para mayor precisión durante un failover)
./scripts/monitor_lag.sh 1
```

---

## 🛠️ Comandos útiles

```bash
# Levantar el laboratorio
docker compose up -d

# Ver logs de todos los nodos
docker compose logs -f

# Ver logs de un nodo específico
docker logs pg-primary -f
docker logs pg-standby1 -f

# Conectar a un contenedor interactivamente
docker exec -it pg-primary bash
docker exec -it pg-primary psql -U postgres -d dwh

# Detener y destruir todo (incluidos volúmenes)
docker compose down -v

# Reconstruir la imagen tras cambios en el Dockerfile
docker compose build && docker compose up -d

# Ver el estado de repmgr desde el primario
docker exec pg-primary \
    /usr/lib/postgresql/16/bin/repmgr \
    -f /etc/repmgr/repmgr.conf \
    cluster show

# Ver logs de repmgrd en un nodo
docker exec pg-standby1 cat /var/log/repmgr/repmgr.log

# Ver eventos de failover en la BD repmgr
psql -h localhost -p 5432 -U repmgr -d repmgr -c \
    "SELECT * FROM repmgr.events ORDER BY event_timestamp DESC LIMIT 10;"
```

---

## ⚠️ Resolución de problemas

### Los standbys no se conectan al primario

```bash
# Ver los logs de error del standby
docker logs pg-standby1 --tail 30

# Verificar que el primario acepta replicación
psql -h localhost -p 5432 -U postgres \
    -c "SELECT * FROM pg_hba_file_rules WHERE database='{replication}';"

# Verificar conectividad dentro de la red Docker
docker exec pg-standby1 ping -c 3 pg-primary
docker exec pg-standby1 nc -zv pg-primary 5432
```

### repmgrd no inicia el failover automático

```bash
# Verificar que repmgrd está corriendo en el standby
docker exec pg-standby1 ps aux | grep repmgrd

# Ver los últimos logs de repmgrd
docker exec pg-standby1 tail -30 /var/log/repmgr/repmgr.log

# Verificar que failover=automatic en el repmgr.conf
docker exec pg-standby1 grep failover /etc/repmgr/repmgr.conf
```

### Los datos no aparecen en el standby

```bash
# Verificar que el standby está en streaming (no en catchup)
psql -h localhost -p 5432 -U postgres \
    -c "SELECT application_name, state FROM pg_stat_replication;"
# 'state' debe ser 'streaming', no 'catchup'

# Ver el lag de recuperación en el standby
psql -h localhost -p 5433 -U postgres \
    -c "SELECT now() - pg_last_xact_replay_timestamp() AS lag;"
```

### Reiniciar el laboratorio desde cero

```bash
docker compose down -v   # Elimina contenedores Y volúmenes
docker compose up --build -d
```

---

## 📊 Referencia de puertos y credenciales

| Recurso | Valor |
|---|---|
| Usuario PostgreSQL | `postgres` |
| Contraseña PostgreSQL | `postgres_lab` |
| Usuario replicación | `replicator` |
| Contraseña replicación | `repl_lab_2025` |
| Usuario repmgr | `repmgr` |
| Contraseña repmgr | `repmgr_lab` |
| BD aplicación | `dwh` |
| BD repmgr | `repmgr` |
| pg-primary port | `5432` |
| pg-standby1 port | `5433` |
| pg-standby2 port | `5434` |

---

## 📚 Referencias

- [PostgreSQL — Streaming Replication](https://www.postgresql.org/docs/current/warm-standby.html)
- [repmgr — Documentación](https://www.repmgr.org/docs/current/)
- [repmgr — GitHub](https://github.com/EnterpriseDB/repmgr)
- [PostgreSQL — pg_rewind](https://www.postgresql.org/docs/current/app-pgrewind.html)
