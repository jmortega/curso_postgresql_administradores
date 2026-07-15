# 🔄 Lab: Despliegue de Parches PostgreSQL con Docker + Patroni

> Stack completo con **Patroni + etcd + HAProxy** en una sola máquina.
> Incluye una instancia **PostgreSQL 15** independiente para practicar
> el major version upgrade sin downtime con replicación lógica.

---

## 🗂️ Estructura del laboratorio

```
pg-parches-lab/
├── docker-compose.yml                     # 6 servicios: etcd, 3×PG16+Patroni, HAProxy, PG15
├── Dockerfile.patroni                     # Imagen PG16 + Patroni + python3
│
├── configs/
│   ├── patroni/
│   │   ├── patroni-primary.yml            # Patroni primario (sync standby habilitado)
│   │   ├── patroni-replica1.yml           # Patroni réplica1 (priority=100)
│   │   └── patroni-replica2.yml           # Patroni réplica2 (priority=50)
│   └── haproxy/
│       └── haproxy.cfg                    # Puerto 5000=escritura, 5001=lectura
│
└── scripts/
    ├── init_v15.sql                       # Datos y publicación lógica en PG15 (BD: dwh)
    ├── cluster_status.sh                  # Estado completo del clúster
    │
    ├── practica_01_inventario.sql         # Inventario y prerequisitos pre-parche
    ├── practica_02_rolling_update.sh      # Rolling update con Patroni
    ├── practica_03_major_upgrade_logico.sql  # Replicación lógica v15→v16
    ├── practica_03b_switchover.sql        # Switchover final del major upgrade
    ├── practica_04_extensiones_config.sql # Extensiones y config reload sin reinicio
    └── practica_05_validacion_post_upgrade.sh  # Validación automática PASS/WARN/FAIL
```

---

## 🌐 Arquitectura del laboratorio

```
TU MÁQUINA (host)
│
│  ┌──────────────────────────────────────────────────────────────┐
│  │       Red Docker: pg_patch_net (172.28.0.0/24)               │
│  │                                                              │
│  │  etcd (.10)          ← coordinación del clúster Patroni      │
│  │                                                              │
│  │  pg-primary (.20)    ← Patroni Leader + PostgreSQL 16        │
│  │  pg-replica1 (.21)   ← Patroni Replica (priority=100)        │
│  │  pg-replica2 (.22)   ← Patroni Replica (priority=50)         │
│  │                                                              │
│  │  haproxy (.30)       ← :5000=escritura | :5001=lectura       │
│  │                                                              │
│  │  pg-v15 (.40)        ← PostgreSQL 15 (major upgrade lab)     │
│  │                         BD: dwh | tabla: pedidos_v15         │
│  └──────────────────────────────────────────────────────────────┘
│
├── localhost:5000  → HAProxy → primario activo (escritura)
├── localhost:5001  → HAProxy → réplicas (lectura, round-robin)
├── localhost:5432  → pg-primary directo
├── localhost:5433  → pg-replica1 directo
├── localhost:5434  → pg-replica2 directo
├── localhost:5435  → pg-v15 (PostgreSQL 15, BD: dwh)
├── localhost:8008  → Patroni REST API pg-primary
├── localhost:8009  → Patroni REST API pg-replica1
├── localhost:8010  → Patroni REST API pg-replica2
└── localhost:7000  → HAProxy stats (http)
```

---

## ⚡ Inicio rápido

```bash
cd pg-parches-lab
chmod +x scripts/*.sh

# Construir imagen Patroni y levantar todos los servicios (~3 min)
docker compose up --build -d

# Seguir la inicialización
docker compose logs -f

# Verificar estado completo
./scripts/cluster_status.sh
```

**Salida esperada (~3-4 min):**

```
════════════════════════════════════════════════════
  Estado del Clúster — 2026-06-26 15:36:49
════════════════════════════════════════════════════

▸ Patroni — clúster pg-patch-cluster:
+ Cluster: pg-patch-cluster ---+-----------+-----------------+
| Member     | Host       | Role    | State     | TL | Lag in MB | Tags            |
+------------+------------+---------+-----------+----+-----------+-----------------+
| pgprimary  | pgprimary  | Leader  | running   |  1 |           |                 |
| pgreplica1 | pgreplica1 | Replica | streaming |  1 |         0 | clonefrom: true |
| pgreplica2 | pgreplica2 | Replica | streaming |  1 |         0 | clonefrom: true |
+------------+------------+---------+-----------+----+-----------+-----------------+

▸ HAProxy:
  ✓ escritura (localhost:5000)
  ✓ lectura (localhost:5001)

▸ etcd:
  127.0.0.1:2379 is healthy
```

---

## Práctica 1 — Inventario Pre-Parche

```bash
docker exec -it pg-primary psql -U postgres \
    -f /scripts/practica_01_inventario.sql

# Ver versión
docker exec -it pg-primary psql -U postgres \
    -c "SELECT version(), current_setting('server_version_num') AS num;"

# Verificar prerequisitos (transacciones largas, vacuums, slots)
docker exec -it pg-primary psql -U postgres -c "
    SELECT 'transacciones largas' AS check, count(*) AS cantidad
    FROM pg_stat_activity
    WHERE xact_start IS NOT NULL
      AND now()-xact_start > INTERVAL '5 minutes'
      AND state != 'idle'
    UNION ALL
    SELECT 'vacuums activos', count(*) FROM pg_stat_progress_vacuum
    UNION ALL
    SELECT 'slots inactivos', count(*) FROM pg_replication_slots WHERE NOT active;"

# Tamaño de bases de datos (join con pg_stat_database para numbackends)
docker exec -it pg-primary psql -U postgres -c "
    SELECT d.datname,
           pg_size_pretty(pg_database_size(d.datname)) AS tamanio,
           s.numbackends AS conexiones_activas
    FROM pg_database d
    JOIN pg_stat_database s ON s.datid = d.oid
    WHERE d.datname NOT IN ('template0','template1')
    ORDER BY pg_database_size(d.datname) DESC;"

# Lag de replicación en tiempo real
docker exec -it pg-primary psql -U postgres -c "
    SELECT application_name, state, sync_state,
           COALESCE(replay_lag::TEXT,'0') AS lag,
           CASE WHEN replay_lag < INTERVAL '5s' THEN '✓ OK'
                ELSE '⚠ REVISAR' END AS estado
    FROM pg_stat_replication;"
```

---

## Práctica 2 — Rolling Update con Patroni

```bash
./scripts/practica_02_rolling_update.sh
```

### Pasos manuales alternativos:

```bash
# PASO 1: Pausar Patroni
docker exec -it pg-primary patronictl \
    -c /etc/patroni/patroni.yml pause pg-patch-cluster --wait

# PASO 2: Reiniciar pg-replica2 (simula actualización de binarios)
docker restart pg-replica2
sleep 15

# PASO 3: Verificar que pg-replica2 volvió al clúster
docker exec -it pg-primary patronictl -c /etc/patroni/patroni.yml list

# PASO 4: Reanudar Patroni
docker exec -it pg-primary patronictl \
    -c /etc/patroni/patroni.yml resume pg-patch-cluster --wait

# Repetir para pg-replica1
docker exec -it pg-primary patronictl \
    -c /etc/patroni/patroni.yml pause pg-patch-cluster --wait
docker restart pg-replica1
sleep 15
docker exec -it pg-primary patronictl \
    -c /etc/patroni/patroni.yml resume pg-patch-cluster --wait

# PASO 5: Switchover controlado → pgreplica1 pasa a ser primario
docker exec -it pg-primary patronictl \
    -c /etc/patroni/patroni.yml \
    switchover pg-patch-cluster \
    --master pgprimary \
    --candidate pgreplica1 \
    --scheduled now \
    --force

sleep 15
docker exec -it pg-primary patronictl -c /etc/patroni/patroni.yml list

# PASO 6: Actualizar el antiguo primario (ahora réplica)
docker restart pg-primary
sleep 20
docker exec -it pg-replica1 patronictl -c /etc/patroni/patroni.yml list
```

---

## Práctica 3 — Major Version Upgrade v15 → v16 (Replicación Lógica)

> **Contexto:** la instancia pg-v15 tiene la tabla `pedidos_v15` en la base de datos **`dwh`**
> (no en `postgres`). Todos los comandos del origen usan `-d dwh`.

### Paso 3.1 — Verificar el origen (pg-v15)

```bash
# Confirmar que wal_level=logical está activo
docker exec -it pg-v15 psql -U postgres -d dwh -c "SHOW wal_level;"
# Debe mostrar: logical


# Confirmar que la publicación existe (pg_publication almacena
# las publicaciones de replicación lógica: qué tablas expone
# el origen para que un suscriptor se conecte)

pg_publication es el catálogo de sistema de PostgreSQL que almacena las publicaciones de replicación lógica — el mecanismo que usa Postgres (desde la v10) para replicar cambios a nivel de fila (INSERT/UPDATE/DELETE) hacia otro servidor, en lugar de replicar bloques físicos como hace la replicación estándar (streaming/WAL).


docker exec -it pg-v15 psql -U postgres -d dwh -c "
    SELECT pubname, puballtables FROM pg_publication;"
# Salida esperada:
#    pubname   | puballtables
#  -------------+--------------
#   pub_upgrade | t
#  (1 row)


# Confirmar que hay datos
docker exec -it pg-v15 psql -U postgres -d dwh -c "
    SELECT count(*) AS filas_en_v15 FROM pedidos_v15;"
# Debe mostrar: 200
```

### Paso 3.2 — Crear la tabla destino en v16 en la replica1 que está actuando como lider

La suscripción lógica copia datos pero no crea la estructura. Hay que crear la tabla
en el clúster v16 antes de suscribirse:

```bash
docker exec -it pg-replica1 psql -U postgres -c "
    CREATE TABLE IF NOT EXISTS public.pedidos_v15 (
        id             BIGSERIAL PRIMARY KEY,
        cliente_id     INTEGER       NOT NULL,
        fecha          TIMESTAMP     NOT NULL DEFAULT now(),
        estado         VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
        importe        NUMERIC(10,2)
    );"
```

### Paso 3.3 — Crear la suscripción lógica (v16 suscribe a v15)

> La connection string apunta a `dbname=dwh` porque ahí está la publicación `pub_upgrade`.

```bash
docker exec -it pg-replica1 psql -U postgres -c "DROP SUBSCRIPTION IF EXISTS sub_desde_v15;"

docker exec -it pg-replica1 psql -U postgres -c "
    CREATE SUBSCRIPTION sub_desde_v15
        CONNECTION 'host=pg-v15 port=5432 dbname=dwh
                    user=logical_repl password=logical_lab_2025
                    connect_timeout=10'
        PUBLICATION pub_upgrade
        WITH (
            copy_data          = true,
            synchronous_commit = off,
            create_slot        = true
        );"
```

O ejecutar el script completo:

```bash
docker exec -it pg-replica1 psql -U postgres \
    -f /scripts/practica_03_major_upgrade_logico.sql
```

### Paso 3.4 — Monitorizar la copia inicial

```bash
# Estado de la suscripción
docker exec -it pg-replica1 psql -U postgres -c "
    SELECT subname, received_lsn, latest_end_lsn,
           now() - latest_end_time AS lag
    FROM pg_stat_subscription;"

# Verificar datos copiados en v16
docker exec -it pg-primary psql -U postgres -c "
    SELECT count(*) AS filas_en_v16 FROM public.pedidos_v15;"

docker exec -it pg-replica1 psql -U postgres -c "
    SELECT count(*) AS filas_en_v16 FROM public.pedidos_v15;"
```

### Paso 3.5 — Verificar replicación en tiempo real

```bash
# Terminal 1: insertar en el ORIGEN (pg-v15, BD dwh)
docker exec -it pg-v15 psql -U postgres -d dwh -c "
    INSERT INTO pedidos_v15 (cliente_id, estado, importe)
    VALUES (7777, 'pendiente', 123.45);"

# Terminal 2: verificar que llegó al DESTINO (pg-primary, esquema public)
$ docker exec -it pg-primary psql -U postgres -c "
    SELECT * FROM public.pedidos_v15 WHERE cliente_id = 7777;"
 id  | cliente_id |           fecha            |  estado   | importe 
-----+------------+----------------------------+-----------+---------
 201 |       7777 | 2026-07-14 17:00:01.673897 | pendiente |  123.45
(1 row)


$ docker exec -it pg-replica1 psql -U postgres -c "
    SELECT * FROM public.pedidos_v15 WHERE cliente_id = 7777;"
 id  | cliente_id |           fecha            |  estado   | importe 
-----+------------+----------------------------+-----------+---------
 201 |       7777 | 2026-07-14 17:00:01.673897 | pendiente |  123.45
(1 row)

linux@linux-EVO14-A8:~/Descargas/pg-parches-lab$ docker exec -it pg-replica2 psql -U postgres -c "
    SELECT * FROM public.pedidos_v15 WHERE cliente_id = 7777;"
 id  | cliente_id |           fecha            |  estado   | importe 
-----+------------+----------------------------+-----------+---------
 201 |       7777 | 2026-07-14 17:00:01.673897 | pendiente |  123.45
(1 row)
```

### Paso 3.6 — Ejecutar el switchover

Cuando el lag de la suscripción sea < 1 segundo:

```bash
docker exec -it pg-replica1 psql -U postgres \
    -f /scripts/practica_03b_switchover.sql
```

El script:
1. Espera a que el lag baje de 2 segundos
2. Desactiva la suscripción (`ALTER SUBSCRIPTION sub_desde_v15 DISABLE`)
3. Verifica el recuento final de filas en v16
4. **Sincroniza las secuencias** (`setval` a `MAX(id)`) — paso crítico, ver nota abajo
5. Inserta una fila de prueba para confirmar que v16 acepta escrituras

> ⚠️ **Por qué el paso 4 es imprescindible:** la replicación lógica replica
> los *valores* de cada fila (vía INSERT/UPDATE/DELETE), pero **nunca
> replica el estado de las secuencias**. La secuencia `pedidos_v15_id_seq`
> en v16 se crea desde cero al hacer `CREATE TABLE` (Paso 3.2) y sigue en
> su valor inicial aunque la tabla ya tenga cientos de filas copiadas
> desde v15. Sin este paso, el primer `INSERT` nuevo en v16 intentará
> reutilizar un `id` que ya existe y fallará con
> `duplicate key value violates unique constraint`. Esto no es una
> particularidad de este laboratorio — es la trampa clásica de cualquier
> migración real basada en replicación lógica, y hay que resolverla
> **antes** de reabrir el sistema a escrituras.

```bash
# Verificar que v16 acepta escrituras tras el switchover
docker exec -it pg-replica1 psql -U postgres -c "
    INSERT INTO public.pedidos_v15 (cliente_id, estado, importe)
    VALUES (9999, 'procesado', 500.00);
    SELECT count(*) FROM public.pedidos_v15;"

$ docker exec -it pg-primary psql -U postgres -c "
    INSERT INTO public.pedidos_v15 (cliente_id, estado, importe)
    VALUES (9999, 'procesado', 500.00);
    SELECT count(*) FROM public.pedidos_v15;"
ERROR:  cannot execute INSERT in a read-only transaction

$ docker exec -it pg-replica2 psql -U postgres -c "
    INSERT INTO public.pedidos_v15 (cliente_id, estado, importe)
    VALUES (9999, 'procesado', 500.00);
    SELECT count(*) FROM public.pedidos_v15;"
ERROR:  cannot execute INSERT in a read-only transaction

$ docker exec -it pg-replica2 psql -U postgres -c "
    SELECT * FROM public.pedidos_v15 WHERE cliente_id = 9999;"
 id  | cliente_id |           fecha            |  estado   | importe 
-----+------------+----------------------------+-----------+---------
 204 |       9999 | 2026-07-14 17:40:38.624575 | procesado |  500.00
 205 |       9999 | 2026-07-14 17:44:41.050261 | procesado |  500.00
 206 |       9999 | 2026-07-14 17:44:43.781571 | procesado |  500.00
(3 rows)

```

---

## Práctica 4 — Extensiones y Configuración Sin Reinicio

```bash
docker exec -it pg-primary psql -U postgres \
    -f /scripts/practica_04_extensiones_config.sql

# Ver parámetros que requieren reinicio vs reload
docker exec -it pg-primary psql -U postgres -c "
    SELECT name, context, pending_restart
    FROM pg_settings
    WHERE name IN ('shared_buffers','work_mem','log_min_duration_statement',
                   'max_connections','shared_preload_libraries')
    ORDER BY name;"

# Cambiar configuración y recargar SIN reiniciar
docker exec -it pg-primary psql -U postgres -c "
    ALTER SYSTEM SET log_min_duration_statement = '1000';
    SELECT pg_reload_conf();
    SHOW log_min_duration_statement;"

# Patroni REST API
curl -s http://localhost:8008/patroni | python3 -m json.tool
curl -s http://localhost:8008/primary
curl -s http://localhost:8008/replica
```

---

## Práctica 5 — Validación Post-Despliegue

```bash
./scripts/practica_05_validacion_post_upgrade.sh
```

**Salida esperada:**

```
╔══════════════════════════════════════════════════════╗
║   PRÁCTICA 5: Validación Post-Despliegue             ║
╚══════════════════════════════════════════════════════╝
✅ PASS  Los 3 nodos del clúster están running
✅ PASS  pg-primary responde a pg_isready
✅ PASS  pg-replica1 responde a pg_isready
✅ PASS  pg-replica2 responde a pg_isready
✅ PASS  2 réplica(s) en streaming
✅ PASS  Lag de replicación: 0s (≤ 10s)
✅ PASS  HAProxy:5000 apunta al PRIMARIO (escritura OK)
✅ PASS  Todas las extensiones al día
⚠️  WARN  Cache hit ratio: 85% (bajo — normal en instancia recién arrancada)
✅ PASS  Sin transacciones largas activas
✅ PASS  etcd disponible y healthy
╔══════════════════════════════════════════════════════╗
║  ✅ PASS: 10  ⚠️  WARN: 1   ❌ FAIL: 0              ║
╚══════════════════════════════════════════════════════╝
✅ Validación EXITOSA — clúster operativo
```

---

## 🛠️ Comandos útiles

```bash
# Estado completo
./scripts/cluster_status.sh

# Patroni: estado del clúster
docker exec -it pg-primary patronictl \
    -c /etc/patroni/patroni.yml list

# Patroni: historial de eventos
docker exec -it pg-primary patronictl \
    -c /etc/patroni/patroni.yml history pg-patch-cluster

# Patroni REST API
curl -s http://localhost:8008/patroni | python3 -m json.tool
curl -s http://localhost:8008/primary
curl -s http://localhost:8008/replica

# HAProxy stats
curl -s http://localhost:7000/haproxy?stats

# Ver logs
docker logs pg-primary --tail 30
docker logs pg-replica1 --tail 20
docker logs haproxy --tail 20

# Conectar por HAProxy (escritura) — contraseña: postgres_lab
psql -h localhost -p 5000 -U postgres -c "SELECT pg_is_in_recovery();"

# Conectar a pg-v15 (BD dwh)
psql -h localhost -p 5435 -U postgres -d dwh -c "SELECT version();"
psql -h localhost -p 5435 -U postgres -d dwh -c "SELECT count(*) FROM pedidos_v15;"

# Detener el laboratorio
docker compose down

# Destruir todo incluyendo volúmenes
docker compose down -v
```

---

## 📋 Credenciales

| Recurso | Valor |
|---|---|
| Usuario PostgreSQL | `postgres` |
| Contraseña | `postgres_lab` |
| Base de datos pg-v15 | `dwh` |
| Usuario replicación streaming | `replicator` |
| Contraseña replicación streaming | `repl_lab_2025` |
| Usuario replicación lógica | `logical_repl` |
| Contraseña replicación lógica | `logical_lab_2025` |
| HAProxy stats | sin autenticación |

---

## 📚 Referencias

- [Patroni — Documentación](https://patroni.readthedocs.io/)
- [PostgreSQL — Upgrading](https://www.postgresql.org/docs/current/upgrading.html)
- [PostgreSQL — Logical Replication](https://www.postgresql.org/docs/current/logical-replication.html)
- [Patroni — switchover/failover](https://patroni.readthedocs.io/en/latest/patronictl.html)
