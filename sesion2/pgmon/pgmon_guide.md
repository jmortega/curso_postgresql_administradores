# Monitorización Avanzada en PostgreSQL
## `pg_stat_statements` y `pg_wait_sampling`

> **Guía completa** — Instalación, configuración, consultas de diagnóstico,
> casos de uso reales y buenas prácticas para monitorización de rendimiento,
> análisis de queries lentas y detección de cuellos de botella en PostgreSQL.

---

## 🐳 Entorno Docker

> Este guia asume que el contenedor está levantado con `docker compose up -d`.
> Consulta el **README.md** principal para los pasos de instalación.

### Conexión utilizada por el script

```bash
# Variables de entorno (valores por defecto → apuntan al contenedor)
PG_HOST=localhost
PG_PORT=5432
PG_USER=postgres
PG_PASSWORD=postgres_lab
```

### Ejecutar el script

```bash
pip install psycopg2-binary tabulate
python scripts/pgmon_manager.py
```

---


## Índice

1. [Introducción a la monitorización avanzada](#1-introducción-a-la-monitorización-avanzada)
2. [pg_stat_statements](#2-pg_stat_statements)
   - 2.1 [Instalación y configuración](#21-instalación-y-configuración)
   - 2.2 [Estructura de la vista](#22-estructura-de-la-vista)
   - 2.3 [Consultas de diagnóstico esenciales](#23-consultas-de-diagnóstico-esenciales)
   - 2.4 [Casos de uso](#24-casos-de-uso)
3. [pg_wait_sampling](#3-pg_wait_sampling)
   - 3.1 [Instalación y configuración](#31-instalación-y-configuración)
   - 3.2 [Tipos de eventos de espera](#32-tipos-de-eventos-de-espera)
   - 3.3 [Consultas de diagnóstico](#33-consultas-de-diagnóstico)
   - 3.4 [Casos de uso](#34-casos-de-uso)
4. [Análisis combinado](#4-análisis-combinado)
5. [Dashboard de monitorización](#5-dashboard-de-monitorización)
6. [Alertas y umbrales](#6-alertas-y-umbrales)
7. [Integración con herramientas externas](#7-integración-con-herramientas-externas)
8. [Buenas prácticas](#8-buenas-prácticas)
9. [Referencias](#9-referencias)

---

## 1. Introducción a la monitorización

PostgreSQL ofrece un ecosistema rico de extensiones para monitorización que van
más allá de las vistas del catálogo. Las dos extensiones más importantes
para diagnóstico de rendimiento son:

| Extensión | Qué mide | Cuándo usarla |
|-----------|----------|---------------|
| `pg_stat_statements` | **Estadísticas acumuladas de ejecución** por consulta normalizada | Identificar queries lentas, costosas o frecuentes |
| `pg_wait_sampling` | **Muestreo de eventos de espera** en tiempo real | Detectar cuellos de botella: locks, I/O, CPU, red |

### ¿Por qué no basta con `EXPLAIN ANALYZE`?

`EXPLAIN ANALYZE` analiza **una query individual** en el momento de ejecución.
Las extensiones de monitorización capturan el comportamiento **agregado y continuo**
del sistema, revelando patrones que no son visibles en análisis puntuales:

```
EXPLAIN ANALYZE  →  Una query, un momento, un plan
pg_stat_statements →  Todas las queries, todo el tiempo, estadísticas acumuladas
pg_wait_sampling   →  Qué hace el servidor mientras espera (muestreo continuo)
```

### Visión general del stack de monitorización

```
┌─────────────────────────────────────────────────────────┐
│                   Aplicación / ORM                       │
└──────────────────────────┬──────────────────────────────┘
                           │ queries SQL
┌──────────────────────────▼──────────────────────────────┐
│                    PostgreSQL                             │
│  ┌─────────────────────┐   ┌────────────────────────┐   │
│  │  pg_stat_statements  │   │   pg_wait_sampling     │   │
│  │  ¿Qué queries son   │   │  ¿Por qué espera el    │   │
│  │  lentas/costosas?   │   │  servidor?             │   │
│  └─────────────────────┘   └────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐│
│  │  pg_stat_activity · pg_locks · pg_stat_bgwriter     ││
│  └─────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────┐
│    Herramientas externas                                  │
│    pgAdmin · Grafana · Prometheus · pgBadger             │
└──────────────────────────────────────────────────────────┘
```

---

## 2. pg_stat_statements

### 2.1 Instalación y configuración

`pg_stat_statements` es una extensión incluida por defecto en PostgreSQL y
solo requiere activación.

#### Paso 1 — Activar la precarga en `postgresql.conf`

```ini
# postgresql.conf
shared_preload_libraries = 'pg_stat_statements'

# Configuración de la extensión
pg_stat_statements.max = 10000        # Máximo de queries almacenadas (por defecto 5000)
pg_stat_statements.track = all        # all | top | none
                                       # all: incluye queries anidadas (funciones, CTEs)
                                       # top: solo queries de nivel superior
pg_stat_statements.track_utility = on # Incluir VACUUM, COPY, CREATE TABLE, etc.
pg_stat_statements.track_planning = on # Incluir tiempo de planificación (PG >= 13)
pg_stat_statements.save = on          # Persistir estadísticas en reinicio
```

> **Importante:** Tras modificar `shared_preload_libraries` se requiere **reiniciar**
> PostgreSQL (no solo `pg_reload_conf()`).

```bash
# Reiniciar PostgreSQL
sudo systemctl restart postgresql
# o
sudo service postgresql restart
```

### conectarse mediante plsql

```sql
-- Conectarse a la base de datos postgis_geo_db
PGPASSWORD=postgres_lab
psql -h localhost -p 5432 -U postgres -d postgres

-- Verificar que está activa
SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';

-- Ver tablas
\dt

-- Ver todas las columnas disponibles de la vista
\d pg_stat_statements

-- Columnas principales (PostgreSQL 14+)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'pg_stat_statements';

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `userid` | oid | Usuario que ejecutó la query |
| `dbid` | oid | Base de datos |
| `queryid` | bigint | Hash único de la query normalizada |
| `query` | text | Texto de la query con parámetros reemplazados por `$1`, `$2`… |
| `calls` | bigint | Número de veces ejecutada |
| `total_exec_time` | float8 | Tiempo total de ejecución (ms) |
| `mean_exec_time` | float8 | Tiempo medio por ejecución (ms) |
| `min_exec_time` | float8 | Tiempo mínimo (ms) |
| `max_exec_time` | float8 | Tiempo máximo (ms) |
| `stddev_exec_time` | float8 | Desviación estándar (ms) |
| `total_plan_time` | float8 | Tiempo total de planificación (ms) — PG >= 13 |
| `rows` | bigint | Total de filas devueltas/afectadas |
| `shared_blks_hit` | bigint | Bloques servidos desde cache (shared buffers) |
| `shared_blks_read` | bigint | Bloques leídos desde disco |
| `shared_blks_dirtied` | bigint | Bloques marcados como sucios |
| `shared_blks_written` | bigint | Bloques escritos en disco |
| `local_blks_hit` | bigint | Bloques locales (tablas temporales) desde cache |
| `temp_blks_read` | bigint | Bloques leídos de archivos temporales |
| `temp_blks_written` | bigint | Bloques escritos en archivos temporales |
| `blk_read_time` | float8 | Tiempo en lectura de bloques (ms) |
| `blk_write_time` | float8 | Tiempo en escritura de bloques (ms) |
| `wal_records` | bigint | Registros WAL generados — PG >= 13 |
| `wal_bytes` | bigint | Bytes WAL generados — PG >= 13 |
| `jit_functions` | bigint | Funciones JIT compiladas — PG >= 14 |

```

### 2.2 Consultas de diagnóstico esenciales

#### Las 10 queries más lentas (por tiempo total)

```sql
SELECT
    LEFT(query, 100)                           AS query,
    calls,
    ROUND(total_exec_time::numeric, 2)         AS total_ms,
    ROUND(mean_exec_time::numeric, 2)          AS media_ms,
    ROUND(max_exec_time::numeric, 2)           AS max_ms,
    ROUND(stddev_exec_time::numeric, 2)        AS stddev_ms,
    rows,
    ROUND(
        (100.0 * total_exec_time /
        SUM(total_exec_time) OVER ())::numeric, 2
    )                                           AS pct_tiempo_total
FROM pg_stat_statements
WHERE query NOT ILIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 10;
```

### 5 consultas que más tiempo de CPU e I/O han consumido en total

El cache_hit_ratio nos dice qué porcentaje de los datos que necesitaba la consulta ya estaban en la RAM (Shared Buffers).
Si está por debajo del 95%, esa consulta está obligando a Postgres a leer constantemente del disco, ralentizando de esta forma la consulta.

```sql
SELECT 
    query, 
    calls, 
    total_exec_time / 1000 AS total_time_seconds, 
    mean_exec_time AS avg_time_ms, 
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS cache_hit_ratio
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 5;
```

#### Queries con mayor tiempo medio (candidatas a optimización)

```sql
SELECT
    LEFT(query, 120)                    AS query,
    calls,
    ROUND(mean_exec_time::numeric, 2)   AS media_ms,
    ROUND(max_exec_time::numeric, 2)    AS max_ms,
    ROUND(stddev_exec_time::numeric, 2) AS stddev_ms,
    -- Alta stddev indica comportamiento inconsistente (problema de plan cacheado)
    CASE
        WHEN stddev_exec_time > mean_exec_time THEN '⚠ Inconsistente'
        WHEN mean_exec_time > 1000             THEN '🔴 Crítica (>1s)'
        WHEN mean_exec_time > 100              THEN '🟡 Lenta (>100ms)'
        ELSE '🟢 OK'
    END                                 AS estado
FROM pg_stat_statements
WHERE calls > 10
  AND query NOT ILIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 15;
```

#### Queries con mayor I/O (lecturas de disco)

```sql
SELECT
    LEFT(query, 100)                        AS query,
    calls,
    shared_blks_read,
    shared_blks_hit,
    ROUND(
        100.0 * shared_blks_hit /
        NULLIF(shared_blks_hit + shared_blks_read, 0), 2
    )                                        AS cache_hit_pct,
    temp_blks_written,
    ROUND(
        (blk_read_time + blk_write_time)::numeric, 2
    )                                        AS io_time_ms
FROM pg_stat_statements
WHERE (shared_blks_read + temp_blks_written) > 0
  AND query NOT ILIKE '%pg_stat_statements%'
ORDER BY shared_blks_read DESC
LIMIT 10;
```

#### Queries que generan más archivos temporales

```sql
-- Indica sorts y hash joins que no caben en work_mem
SELECT
    LEFT(query, 100)                    AS query,
    calls,
    temp_blks_written,
    ROUND(
        temp_blks_written * 8.0 / 1024, 2
    )                                    AS temp_mb,
    ROUND(mean_exec_time::numeric, 2)    AS media_ms
FROM pg_stat_statements
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 10;

-- Si hay queries aquí, considera aumentar work_mem:
-- SET work_mem = '256MB';  -- Por sesión
-- ALTER SYSTEM SET work_mem = '64MB';  -- Global
```

#### Queries más frecuentes (mayor carga por volumen)

```sql
SELECT
    LEFT(query, 100)                    AS query,
    calls,
    ROUND(total_exec_time::numeric, 2)  AS total_ms,
    ROUND(mean_exec_time::numeric, 4)   AS media_ms,
    rows,
    ROUND(rows::numeric / calls, 1)     AS filas_por_llamada
FROM pg_stat_statements
WHERE calls > 100
ORDER BY calls DESC
LIMIT 10;
```

#### Ratio de cache hit por query

cache_hit_pct mide qué porcentaje de los bloques de datos que necesitó leer esa consulta se encontraron ya en memoria (shared_buffers), en lugar de tener que ir a disco.
Cada consulta accede a bloques (páginas de 8KB) de las tablas e índices que toca. Cada acceso puede resolverse de dos formas:

shared_blks_hit — el bloque ya estaba en el caché de PostgreSQL en RAM, lectura prácticamente instantánea.
shared_blks_read — el bloque no estaba en caché y hubo que leerlo del disco, más lento.

La fórmula 100.0 * hit / (hit + read) da el porcentaje de accesos que fueron "gratis" (porque se obtuvieron de memoria) frente al total de accesos.
Esta consulta ordena ASC (ascendente) y filtra por consultas con peor cache hit ratio entre las que más operaciones I/O generan. Son las candidatas más probables a estar ralentizando el sistema por exceso de lecturas a disco.

```sql
-- Un cache_hit_pct < 95% indica que se está leyendo mucho de disco
SELECT
    LEFT(query, 80)                      AS query,
    calls,
    shared_blks_hit + shared_blks_read   AS total_blks,
    ROUND(
        100.0 * shared_blks_hit /
        NULLIF(shared_blks_hit + shared_blks_read, 0), 2
    )                                     AS cache_hit_pct
FROM pg_stat_statements
WHERE shared_blks_hit + shared_blks_read > 1000
ORDER BY cache_hit_pct ASC
LIMIT 10;
```

#### Queries con mayor generación de WAL (escrituras)

```sql
-- PG >= 13: identifica queries con mayor impacto en replicación
SELECT
    LEFT(query, 100)                     AS query,
    calls,
    wal_records,
    ROUND(wal_bytes / 1024.0 / 1024, 2)  AS wal_mb,
    ROUND(mean_exec_time::numeric, 2)     AS media_ms
FROM pg_stat_statements
WHERE wal_bytes > 0
ORDER BY wal_bytes DESC
LIMIT 10;
```

#### Resumen global del sistema

```sql
SELECT
    COUNT(*)                                    AS queries_distintas,
    SUM(calls)                                  AS total_ejecuciones,
    ROUND(SUM(total_exec_time)::numeric / 1000 / 60, 2)
                                                AS minutos_cpu_total,
    ROUND(AVG(mean_exec_time)::numeric, 2)      AS media_global_ms,
    SUM(shared_blks_read)                       AS total_blks_disco,
    SUM(shared_blks_hit)                        AS total_blks_cache,
    ROUND(
        100.0 * SUM(shared_blks_hit) /
        NULLIF(SUM(shared_blks_hit) + SUM(shared_blks_read), 0), 2
    )                                           AS cache_hit_pct_global,
    SUM(temp_blks_written)                      AS total_temp_blks,
    ROUND(SUM(wal_bytes) / 1024.0 / 1024, 2)   AS total_wal_mb
FROM pg_stat_statements
WHERE query NOT ILIKE '%pg_stat_statements%';
```

#### Resetear estadísticas (útil tras optimizaciones)

```sql
-- Resetear todas las estadísticas
SELECT pg_stat_statements_reset();

-- Resetear estadísticas de una query específica (PG >= 12)
SELECT pg_stat_statements_reset(
    userid  := (SELECT oid FROM pg_roles WHERE rolname = 'app_user'),
    dbid    := (SELECT oid FROM pg_database WHERE datname = 'mi_db'),
    queryid := 1234567890  -- queryid de la query a resetear
);
```

### 2.3 Casos de uso

#### Identificar queries sin índice (full scan implícito)

```sql
-- Queries que leen muchos bloques por llamada (indicador de seq scan)
SELECT
    LEFT(query, 120) AS query,
    calls,
    ROUND((shared_blks_read / NULLIF(calls, 0))::numeric, 0)
        AS blks_disco_por_llamada,
    ROUND(mean_exec_time::numeric, 2) AS media_ms
FROM pg_stat_statements
WHERE calls > 5
  AND shared_blks_read / NULLIF(calls, 0) > 1000  -- > 1000 bloques por llamada
ORDER BY blks_disco_por_llamada DESC
LIMIT 10;
```

---

## 3. pg_wait_sampling

### 3.1 Instalación y configuración

A diferencia de `pg_stat_statements`, `pg_wait_sampling` **no viene incluida**
en PostgreSQL y debe compilarse o instalarse desde un paquete.

#### Instalación

```bash
# Ubuntu / Debian
sudo apt-get install postgresql-16-pg-wait-sampling

# Compilar desde fuente
git clone https://github.com/postgrespro/pg_wait_sampling.git
cd pg_wait_sampling
make PG_CONFIG=/usr/bin/pg_config
sudo make install
```

#### Configuración en `postgresql.conf`

```ini
# Añadir a shared_preload_libraries (junto a pg_stat_statements si se usa)
shared_preload_libraries = 'pg_stat_statements, pg_wait_sampling'

# Parámetros de pg_wait_sampling
pg_wait_sampling.history_size    = 5000   # Muestras en el historial circular
pg_wait_sampling.history_period  = 10     # ms entre muestras del historial
pg_wait_sampling.profile_period  = 10     # ms entre muestras del perfil acumulado
pg_wait_sampling.profile_pid     = on     # Perfil por PID de proceso
pg_wait_sampling.profile_queries = on     # Asociar queries a waits (requiere pg_stat_statements)
```

### conectarse mediante plsql

```sql
-- Conectarse a la base de datos postgis_geo_db
PGPASSWORD=postgres_lab
psql -h localhost -p 5432 -U postgres -d postgres

-- Verificar que está activa
SELECT * FROM pg_extension WHERE extname = 'pg_wait_sampling';

-- Obtener esquema de la vista
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'pg_wait_sampling_history'
ORDER BY ordinal_position;

 column_name |        data_type         
-------------+--------------------------
 pid         | integer
 ts          | timestamp with time zone
 event_type  | text
 event       | text
 queryid     | bigint

```

### 3.2 Tipos de Eventos de Espera

PostgreSQL clasifica los eventos de espera en categorías. Conocerlas es
esencial para interpretar correctamente los datos de `pg_wait_sampling`.

| Categoría | Descripción | Causas típicas |
|-----------|-------------|----------------|
| `Lock` | Esperando un lock de tabla, fila o transacción | Conflictos de escritura, deadlocks, `SELECT FOR UPDATE` |
| `LWLock` | Lock ligero interno del motor (shared buffers, WAL, catálogo) | Alta concurrencia, buffers insuficientes |
| `IO` | Esperando operaciones de I/O con el sistema de archivos | Disco lento, índices no cacheados, queries sin índice |
| `IPC` | Comunicación entre procesos PostgreSQL | Esperar resultados de workers paralelos |
| `Timeout` | Esperas programadas (autovacuum, etc.) | Normal en procesos de mantenimiento |
| `CPU` | Procesamiento activo (no aparece como wait) | Normal |
| `Activity` | Proceso de background idle esperando trabajo | Normal (bgwriter, autovacuum, wal sender) |
| `Client` | Esperando datos del cliente | Aplicación lenta en enviar/recibir |
| `Extension` | Evento de espera definido por extensión | Depende de la extensión |

#### Eventos de espera más importantes

```
Lock/relation           → Conflicto en tabla completa
Lock/transactionid      → Esperando que otra transacción termine
Lock/tuple              → Conflicto a nivel de fila (hot row contention)
LWLock/BufferMapping    → Alta presión en shared_buffers
LWLock/WALWrite         → I/O intensivo en WAL (muchas escrituras)
LWLock/CLogControlLock  → Alta concurrencia en commit log
IO/DataFileRead         → Lectura de datos desde disco (falta de caché)
IO/WALWrite             → Escritura en WAL (transacciones intensas)
IO/BufFileRead/Write    → Uso de archivos temporales (work_mem insuficiente)
Client/ClientRead       → Espera al cliente (problema en la aplicación)
IPC/BgWorkerShutdown    → Workers paralelos completando trabajo
```

### 3.3 Consultas de diagnóstico

#### Vista `pg_wait_sampling_profile` — Perfil acumulado

```sql
-- Distribución de eventos de espera por tipo (perfil acumulado)
SELECT
    event_type,
    event,
    SUM(count)                                  AS total_samples,
    ROUND(
        100.0 * SUM(count) /
        SUM(SUM(count)) OVER (), 2
    )                                           AS pct_total
FROM pg_wait_sampling_profile
WHERE event IS NOT NULL
GROUP BY event_type, event
ORDER BY total_samples DESC
LIMIT 20;
```

#### Vista `pg_wait_sampling_history` — Historial reciente

```sql
-- Qué estaba esperando cada proceso en los últimos segundos
SELECT
    pid,
    event_type,
    event,
    queryid,
    COUNT(*) AS muestras
FROM pg_wait_sampling_history
WHERE event IS NOT NULL
GROUP BY pid, event_type, event, queryid
ORDER BY muestras DESC
LIMIT 20;
```

#### Procesos con más esperas en este momento

```sql
-- Combinar con pg_stat_activity para contexto completo
SELECT
    a.pid,
    a.usename,
    a.application_name,
    a.state,
    LEFT(a.query, 80)       AS query_actual,
    a.wait_event_type,
    a.wait_event,
    h.muestras,
    NOW() - a.query_start   AS duracion
FROM pg_stat_activity a
JOIN (
    SELECT pid, COUNT(*) AS muestras
    FROM pg_wait_sampling_history
    WHERE event IS NOT NULL
    GROUP BY pid
) h ON h.pid = a.pid
WHERE a.state != 'idle'
ORDER BY h.muestras DESC;
```

#### Queries con más eventos de espera (requiere `profile_queries = on`)

```sql
-- Las queries que más tiempo pasan esperando (no ejecutando)
SELECT
    p.queryid,
    LEFT(s.query, 100)      AS query,
    p.event_type,
    p.event,
    SUM(p.count)            AS total_waits,
    ROUND(s.mean_exec_time::numeric, 2) AS media_ejecucion_ms
FROM pg_wait_sampling_profile p
JOIN pg_stat_statements s ON s.queryid = p.queryid
WHERE p.event IS NOT NULL
GROUP BY p.queryid, s.query, p.event_type, p.event, s.mean_exec_time
ORDER BY total_waits DESC
LIMIT 15;
```

#### Detectar contención de locks en tiempo real

```sql
-- Procesos bloqueados y quién los bloquea
SELECT
    blocked.pid                     AS pid_bloqueado,
    blocked.usename                 AS usuario_bloqueado,
    LEFT(blocked.query, 80)         AS query_bloqueada,
    blocking.pid                    AS pid_bloqueador,
    blocking.usename                AS usuario_bloqueador,
    LEFT(blocking.query, 80)        AS query_bloqueadora,
    NOW() - blocked.query_start     AS tiempo_esperando,
    blocked.wait_event_type,
    blocked.wait_event
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock'
ORDER BY tiempo_esperando DESC;
```

#### Resetear perfil de esperas

```sql
SELECT pg_wait_sampling_reset_profile();
```

### 3.4 Casos de uso

#### Diagnóstico de Lock Contention

```sql
-- Mapa de calor de locks: qué tablas generan más contención
SELECT
    h.event,
    COUNT(*)                AS total_lock_waits,
    COUNT(DISTINCT h.pid)   AS pids_afectados
FROM pg_wait_sampling_history h
WHERE h.event_type = 'Lock'
GROUP BY h.event
ORDER BY total_lock_waits DESC;
```

#### Diagnóstico de operaciones I/O--muy interesante

```sql
-- ¿Cuánto tiempo pasa el sistema en operaciones I/O vs otras operaciones?
SELECT
    CASE
        WHEN event_type = 'IO'      THEN 'I/O Disco'
        WHEN event_type = 'Lock'    THEN 'Locks'
        WHEN event_type = 'LWLock'  THEN 'Locks Internos'
        WHEN event_type = 'Client'  THEN 'Espera Cliente'
        WHEN event_type IS NULL     THEN 'CPU Activa'
        ELSE event_type
    END                         AS categoria,
    SUM(count)                  AS muestras,
    ROUND(
        100.0 * SUM(count) /
        SUM(SUM(count)) OVER (), 2
    )                           AS porcentaje
FROM pg_wait_sampling_profile
GROUP BY categoria
ORDER BY muestras DESC;

   categoria    | muestras | porcentaje 
----------------+----------+------------
 Activity       |  3893651 |      84.64
 Espera Cliente |   706051 |      15.35
 CPU Activa     |      571 |       0.01
 Timeout        |      136 |       0.00
 I/O Disco      |       23 |       0.00
(5 rows)

```

---

## 4. Análisis Combinado

La potencia real aparece al combinar ambas extensiones:

```sql
-- Queries lentas CON su perfil de eventos de espera
WITH top_queries AS (
    SELECT
        queryid,
        LEFT(query, 100) AS query_text,
        calls,
        ROUND(mean_exec_time::numeric, 2) AS media_ms,
        ROUND(total_exec_time::numeric, 2) AS total_ms
    FROM pg_stat_statements
    WHERE calls > 5
    ORDER BY total_exec_time DESC
    LIMIT 10
),
wait_profile AS (
    SELECT
        queryid,
        event_type,
        event,
        SUM(count) AS waits
    FROM pg_wait_sampling_profile
    WHERE event IS NOT NULL
    GROUP BY queryid, event_type, event
)
SELECT
    q.query_text,
    q.calls,
    q.media_ms,
    q.total_ms,
    w.event_type,
    w.event,
    w.waits
FROM top_queries q
LEFT JOIN wait_profile w ON w.queryid = q.queryid
ORDER BY q.total_ms DESC, w.waits DESC;
```

---

## 5. Dashboard de Monitorización

### Snapshot completo del sistema (una sola consulta)

```sql
-- Vista ejecutiva del estado del sistema
WITH stats AS (
    SELECT
        COUNT(*) FILTER (WHERE state = 'active')       AS activas,
        COUNT(*) FILTER (WHERE state = 'idle')          AS idle,
        COUNT(*) FILTER (WHERE wait_event_type = 'Lock') AS bloqueadas,
        MAX(NOW() - query_start) FILTER (WHERE state = 'active')
            AS query_mas_larga
    FROM pg_stat_activity
    WHERE pid != pg_backend_pid()
),
cache AS (
    SELECT
        ROUND(
            100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2
        ) AS hit_ratio
    FROM pg_stat_database
    WHERE datname = current_database()
),
top_wait AS (
    SELECT event_type || '/' || COALESCE(event, 'none') AS top_wait
    FROM pg_wait_sampling_profile
    WHERE event IS NOT NULL
    GROUP BY event_type, event
    ORDER BY SUM(count) DESC
    LIMIT 1
)
SELECT
    s.activas           AS "Conexiones activas",
    s.idle              AS "Conexiones idle",
    s.bloqueadas        AS "Conexiones bloqueadas",
    s.query_mas_larga   AS "Query más larga",
    c.hit_ratio || '%'  AS "Cache hit ratio",
    tw.top_wait         AS "Principal causa de espera"
FROM stats s, cache c, top_wait tw;
```

---

## 6. Alertas y Umbrales

### Umbrales recomendados

| Métrica | 🟢 OK | 🟡 Atención | 🔴 Crítico |
|---------|-------|-------------|-----------|
| Cache hit ratio | > 99% | 95–99% | < 95% |
| Tiempo medio de query | < 100ms | 100ms–1s | > 1s |
| Queries bloqueadas | 0 | 1–5 | > 5 |
| Archivos temporales (blks) | 0 | > 100 | > 10,000 |
| % tiempo en I/O waits | < 10% | 10–30% | > 30% |
| % tiempo en Lock waits | < 5% | 5–20% | > 20% |
| Stddev / mean exec time | < 1 | 1–3 | > 3 |

### Consulta de alertas automáticas

```sql
-- Generar alertas basadas en umbrales
SELECT
    'QUERY_LENTA'       AS tipo_alerta,
    LEFT(query, 80)      AS detalle,
    ROUND(mean_exec_time::numeric, 0) || 'ms' AS valor,
    CASE
        WHEN mean_exec_time > 1000 THEN 'CRITICO'
        WHEN mean_exec_time > 100  THEN 'ATENCION'
    END                  AS severidad
FROM pg_stat_statements
WHERE mean_exec_time > 100 AND calls > 10

UNION ALL

SELECT
    'LOCK_CONTENTION',
    event_type || '/' || COALESCE(event,'?'),
    SUM(count)::text || ' waits',
    CASE WHEN SUM(count) > 1000 THEN 'CRITICO' ELSE 'ATENCION' END
FROM pg_wait_sampling_profile
WHERE event_type = 'Lock'
GROUP BY event_type, event
HAVING SUM(count) > 100

UNION ALL

SELECT
    'CACHE_HIT_BAJO',
    'Base de datos: ' || datname,
    ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2)::text || '%',
    'ATENCION'
FROM pg_stat_database
WHERE blks_hit + blks_read > 1000
  AND 100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0) < 95

ORDER BY severidad, tipo_alerta;
```

---

## 7. Buenas Prácticas

### ✅ Recomendaciones

1. **Activa `pg_stat_statements` siempre en producción** — el overhead es < 1% y el valor diagnóstico es inmenso.

2. **Resetea las estadísticas periódicamente** (`pg_stat_statements_reset()`) — por ejemplo tras cada deploy, para medir el impacto de los cambios.

3. **Guarda snapshots históricos** — copia `pg_stat_statements` a una tabla propia cada hora/día para análisis de tendencias.

4. **Usa `track = all`** si tienes lógica en stored procedures o funciones PL/pgSQL — de lo contrario las queries internas son invisibles.

5. **Combina siempre** `pg_wait_sampling` con `pg_stat_statements` — los tiempos altos pueden deberse a CPU (optimización de query) o a waits (locks, I/O), y la solución es completamente diferente.

6. **Establece alertas sobre `mean_exec_time`**, no solo sobre `max_exec_time` — los picos puntuales son menos preocupantes que la degradación sostenida.

7. **Monitoriza `temp_blks_written`** — su presencia indica que `work_mem` es insuficiente para los sorts/joins de esa query.

### ⚠️ Errores comunes

```sql
-- ❌ MAL: Olvidar añadir a shared_preload_libraries antes de CREATE EXTENSION
CREATE EXTENSION pg_stat_statements;
-- ERROR: pgss must be loaded via shared_preload_libraries

-- ❌ MAL: Comparar queryid entre distintas versiones de PG
-- El queryid cambia entre versiones mayores de PostgreSQL

-- ❌ MAL: Ignorar el campo stddev_exec_time
-- Alta stddev indica planes de ejecución inestables, no solo queries lentas

-- ✅ BIEN: Filtrar el ruido
WHERE calls > 10                  -- Ignorar ejecuciones únicas
  AND query NOT ILIKE '%vacuum%'  -- Ignorar mantenimiento
  AND query NOT ILIKE '%analyze%'

-- ❌ MAL: Confiar en max_exec_time sin contexto
-- Una sola ejecución lenta puede inflar max_exec_time
-- Usar stddev + percentiles para diagnóstico fiable
```

---

## 9. Referencias

- [pg_stat_statements — Documentación oficial](https://www.postgresql.org/docs/current/pgstatstatements.html)
- [pg_wait_sampling — GitHub](https://github.com/postgrespro/pg_wait_sampling)
- [PostgreSQL Wait Events](https://www.postgresql.org/docs/current/monitoring-stats.html#WAIT-EVENT-TABLE)
- [Postgres Monitoring Cheatsheet](https://severalnines.com/blog/postgresql-performance-monitoring-pg-stat-statements/)
- [pgBadger](https://github.com/darold/pgbadger) — Analizador de logs PostgreSQL
- [postgres_exporter](https://github.com/prometheus-community/postgres_exporter) — Métricas para Prometheus
