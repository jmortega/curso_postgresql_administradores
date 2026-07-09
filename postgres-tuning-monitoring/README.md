# 🐘⚡ PostgreSQL: Optimización, Tuning, Pruebas de Carga y Monitorización

> Guía unificada — combina la teoría de optimización de consultas, índices,
> particionado y benchmarking con el stack práctico de observabilidad
> (Prometheus + Grafana + Loki) para poder **ver en tiempo real** el efecto
> de cada técnica de tuning sobre este mismo laboratorio.

Esta guía sustituye a las dos guías independientes que existían previamente
(`README_pg_optimizacion.md` y el `README.md` del proyecto `postgres-monitoring`),
unificadas para trabajar sobre el **mismo entorno Docker Compose adaptado**.

---

## 📋 Índice

**Parte I — Laboratorio**
1. [Arquitectura del stack](#1-arquitectura-del-stack)
2. [Qué se adaptó respecto al proyecto original](#2-qué-se-adaptó-respecto-al-proyecto-original)
3. [Inicio rápido](#3-inicio-rápido)

**Parte II — Optimización y tuning (teoría + práctica)**
4. [El optimizador y EXPLAIN ANALYZE](#4-el-optimizador-y-explain-analyze)
5. [Estadísticas: dinámicas y acumuladas](#5-estadísticas-dinámicas-y-acumuladas)
6. [Índices: diseño, cobertura, parciales e hipotéticos (hypopg)](#6-índices-diseño-cobertura-parciales-e-hipotéticos-hypopg)
7. [Particionado y pruning](#7-particionado-y-pruning)
8. [Cuellos de botella y bloqueos](#8-cuellos-de-botella-y-bloqueos)

**Parte III — Pruebas de carga y análisis de logs**
9. [pgbench: pruebas de carga sobre `pedidos`](#9-pgbench-pruebas-de-carga-sobre-pedidos)
10. [pgBadger: análisis forense de logs](#10-pgbadger-análisis-forense-de-logs)

**Parte IV — Monitorización continua**
11. [pg_stat_statements, pg_locks y vistas de diagnóstico](#11-pg_stat_statements-pg_locks-y-vistas-de-diagnóstico)
12. [Dashboards de Grafana](#12-dashboards-de-grafana)
13. [Alertas en Prometheus/Alertmanager](#13-alertas-en-prometheusalertmanager)
14. [Logs con Loki](#14-logs-con-loki)

**Parte V — Referencia**
15. [Checklist de verificación](#15-checklist-de-verificación)
16. [Troubleshooting](#16-troubleshooting)
17. [Configuración de tuning aplicada](#17-configuración-de-tuning-aplicada)
18. [Referencias](#18-referencias)

---

## 1. Arquitectura del stack

```
┌───────────────────────────────────────────────────────────────────────┐
│                        Docker Network: monitoring                     │
│                                                                        │
│  ┌────────────────────┐   scrape    ┌─────────────────────────┐      │
│  │  postgres           │◄────────────│  postgres-exporter       │      │
│  │  (custom image:     │             │  :9187                   │      │
│  │  hypopg+pgbadger+   │             └────────────┬─────────────┘      │
│  │  pgbench) :5432     │                          │ metrics            │
│  │                     │  logs (volumen)          ▼                    │
│  │  tablas: pedidos    │──────────┐   ┌─────────────────────────┐      │
│  │  (1M filas),        │          │   │       Prometheus :9090   │      │
│  │  clientes, eventos  │          │   └────────────┬─────────────┘      │
│  └─────────────────────┘          │                │ alertas            │
│           │                       │                ▼                    │
│           │ logs (Docker)         │   ┌─────────────────────────┐      │
│           ▼                       │   │     Alertmanager :9093   │      │
│  ┌──────────────┐   push logs     │   └─────────────────────────┘      │
│  │  Promtail    │────────────►┌───▼───────────┐                        │
│  └──────────────┘             │  Loki :3100    │                        │
│                                └───────┬────────┘                        │
│                                        │ query                           │
│                                        ▼                                 │
│                          ┌───────────────────────────┐                  │
│                          │      Grafana :3000         │                  │
│                          │  Dashboards + Alertas      │                  │
│                          └───────────────────────────┘                  │
└───────────────────────────────────────────────────────────────────────┘

Adicional (dentro del contenedor postgres, vía docker exec):
  pgbench   → genera carga sobre la tabla pedidos
  pgbadger  → analiza el volumen postgres_logs y genera HTML en /pgbadger_reports
  hypopg    → simula índices sin crearlos físicamente
```

| Componente | Puerto | Función |
|---|---|---|
| **postgres** | 5433→5432 | PostgreSQL 16 + hypopg + pgbadger + pgbench (imagen personalizada) |
| postgres-exporter | 9187 | Expone métricas `/metrics` a Prometheus |
| Prometheus | 9090 | Recolección y almacenamiento de métricas |
| Alertmanager | 9093 | Gestión y enrutamiento de alertas |
| Loki | 3100 | Almacenamiento y búsqueda de logs |
| Promtail | 9080 | Agente de recolección de logs |
| Grafana | 3000 | Dashboards y visualización |
| node-exporter | 9100 | Métricas del sistema operativo (CPU/RAM/disco del host) |

---

## 2. Qué se adaptó respecto al proyecto original

El proyecto `postgres-monitoring` original estaba pensado solo para **observabilidad**
(dashboards y alertas sobre datos sintéticos de eventos/sesiones). Para poder ejecutar
también las **prácticas de tuning** de la guía de optimización, se hicieron estos cambios:

| Fichero | Cambio | Motivo |
|---|---|---|
| `Dockerfile.postgres` (nuevo) | Imagen basada en `postgres:16-bookworm` con `hypopg`, `pgbadger` y utilidades | La imagen original `postgres:16-alpine` no permite instalar hypopg/pgbadger fácilmente (repos apt limitados en Alpine) |
| `docker-compose.yml` → servicio `postgres` | `image: postgres:16-alpine` → `build: Dockerfile.postgres`; se monta `configs/postgresql.conf` en vez de pasar parámetros por `command` | Necesario para tener `hypopg`, `pgbadger`, y centralizar el tuning en un fichero editable |
| `configs/postgresql.conf` (nuevo) | `logging_collector=on` + `log_directory` + parámetros de memoria/planificador de la guía | Sin esto pgBadger no tiene logs que analizar, y sin ajustar `work_mem`/`random_page_cost` los planes no reflejan un entorno realista |
| Volumen `postgres_logs` (nuevo) | Persiste `/var/log/postgresql` y se monta también en el propio contenedor `postgres` | pgBadger necesita acceso directo a los ficheros de log, no solo al log de Docker |
| `02_pedidos_lab.sql` (nuevo) | Crea `pedidos` (1M filas), `clientes` (100k filas) y la extensión `hypopg` | Es el caso de estudio central de toda la guía de optimización (índices, particionado, EXPLAIN) |
| `scripts/test_carga_pedidos.sql` (nuevo) | Script de pgbench dirigido a `pedidos` | Permite generar carga realista y verla reflejada en los dashboards de Grafana ya existentes |
| `scripts/pgbadger_report.sh` (nuevo) | Automatiza la generación del reporte HTML | Evita recordar la sintaxis completa de pgbadger cada vez |
| `healthcheck` de `postgres` | `start_period` de 60s → 90s, `retries` 5 → 10 | La carga de 1M de filas añade tiempo al arranque inicial |

> El resto del stack (Prometheus, Grafana, Loki, Alertmanager, node-exporter) **no se modificó** — sigue funcionando igual que en el proyecto original, ahora también con las métricas generadas por las prácticas de tuning.

---

## 3. Inicio rápido

```bash
# 1. Configurar credenciales (igual que antes)
nano .env

# 2. Construir la imagen personalizada de postgres y levantar el stack
docker compose build postgres
docker compose up -d

# 3. Verificar que todo arrancó (la primera vez tarda 1-2 min por la carga de 1M filas)
docker compose ps
docker compose logs -f postgres
```

Salida esperada al final de los logs de `postgres`:

```
NOTICE:  Configuración de monitorización completada correctamente.
NOTICE:  Laboratorio de tuning listo: pedidos (1.000.000 filas), clientes (100.000 filas)
NOTICE:  Extensión hypopg disponible para índices hipotéticos
```

**Accesos:**

| Servicio | URL |
|---|---|
| Grafana | http://localhost:3000 (admin / valor de `GRAFANA_PASSWORD`) |
| Prometheus | http://localhost:9090 |
| Alertmanager | http://localhost:9093 |
| PostgreSQL | `psql -h localhost -p 5433 -U pguser -d appdb` |

---

## 4. El optimizador y EXPLAIN ANALYZE

El planificador de PostgreSQL es un **optimizador basado en coste (CBO)**: genera varios
planes candidatos para resolver una consulta y elige el de menor coste estimado, usando
las estadísticas de `pg_statistic` (actualizadas por `ANALYZE`/autovacuum).


## 1. Optimizador de consultas y `EXPLAIN ANALYZE`

### 1.1 ¿Cómo funciona el optimizador?

El optimizador de PostgreSQL (query planner) es un componente **basado en coste**
que, para cada consulta, genera múltiples planes de ejecución posibles y elige
el de menor coste estimado.

```
Consulta SQL
     │
     ▼
 Parser         → Árbol de sintaxis (AST)
     │
     ▼
 Rewriter       → Aplica reglas y expande vistas
     │
     ▼
 Planner/Optimizer
     │  ├── Genera planes candidatos
     │  ├── Estima coste de cada plan usando estadísticas de pg_statistic
     │  └── Selecciona el plan de menor coste
     ▼
 Executor        → Ejecuta el plan seleccionado
```

**Parámetros de coste configurables:**


# Ver parámetros de coste del planificador
```bash
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT name, setting, unit
    FROM pg_settings
    WHERE name IN (
        'seq_page_cost','random_page_cost',
        'cpu_tuple_cost','effective_cache_size'
    ) ORDER BY name;"
```

```ini
# postgresql.conf
seq_page_cost        = 1.0    # Coste de leer una página en escaneo secuencial (referencia)
random_page_cost     = 4.0    # Coste de acceso aleatorio (ajustar a 1.1 en SSD)
cpu_tuple_cost       = 0.01   # Coste de procesar una fila
cpu_index_tuple_cost = 0.005  # Coste de procesar una entrada de índice
cpu_operator_cost    = 0.0025 # Coste de evaluar un operador
effective_cache_size = 4GB    # RAM disponible para caché (solo informativo)
```

```sql
-- Conéctate al laboratorio
docker exec -it postgres psql -U pguser -d appdb

appdb=# SELECT count(*) FROM pedidos WHERE estado = 'pendiente';
 count  
--------
 334470
(1 row)



-- Plan estimado, sin ejecutar
appdb=# EXPLAIN SELECT * FROM pedidos WHERE estado = 'pendiente';

                            QUERY PLAN                            
------------------------------------------------------------------
 Seq Scan on pedidos  (cost=0.00..32909.00 rows=332267 width=130)
   Filter: ((estado)::text = 'pendiente'::text)
(2 rows)


-- Ejecuta de verdad y compara estimado vs. real
appdb=# EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM pedidos WHERE estado = 'pendiente';

Seq Scan on pedidos  (cost=0.00..32909.00 rows=332267 width=130) (actual time=0.276..296.817 rows=334470 loops=1)
   Filter: ((estado)::text = 'pendiente'::text)
   Rows Removed by Filter: 665530
   Buffers: shared read=20409
   I/O Timings: shared read=114.238
 Planning Time: 0.154 ms
 Execution Time: 326.753 ms
(7 rows)

```

Lectura de un plan:

```
Seq Scan on pedidos  (cost=0.00..28847.00 rows=333333 width=120)
                      (actual time=0.021..312.450 rows=333421 loops=1)
Buffers: shared hit=8192 read=6530
Planning Time: 0.8 ms
Execution Time: 345.2 ms

-- Formato más detallado: buffers, WAL, timing por nodo
appdb=# EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
    SELECT * FROM pedidos WHERE estado = 'pendiente';

-- Formato JSON
appdb=# EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
    SELECT * FROM pedidos WHERE estado = 'pendiente';

```

### 1.2 Lectura de un plan de ejecución

```
Seq Scan on pedidos  (cost=0.00..28847.00 rows=333333 width=120)
                           │       │         │           │
                           │       │         │           └─ Anchura media de fila (bytes)
                           │       │         └─ Filas estimadas devueltas
                           │       └─ Coste total estimado
                           └─ Coste de inicio (antes de devolver la primera fila)
```

**Con ANALYZE:**

```
Seq Scan on pedidos  (cost=0.00..28847.00 rows=333333 width=120)
                      (actual time=0.021..312.450 rows=333421 loops=1)
                                    │              │          │
                                    │              │          └─ Veces que se ejecutó el nodo
                                    │              └─ Tiempo real total (ms)
                                    └─ Tiempo hasta la primera fila (ms)
Buffers: shared hit=8192 read=6530
                    │            └─ Páginas leídas del disco
                    └─ Páginas servidas desde el buffer cache (shared_buffers)
Planning Time: 0.8 ms
Execution Time: 345.2 ms
```

### 1.3 Opciones avanzadas de EXPLAIN

```sql
-- SETTINGS: muestra parámetros modificados que afectan al plan
EXPLAIN (ANALYZE, SETTINGS)
    SELECT * FROM pedidos WHERE cliente_id = 42;

-- GENERIC_PLAN: muestra el plan genérico para consultas preparadas
EXPLAIN (GENERIC_PLAN)
    SELECT * FROM pedidos WHERE estado = $1;

-- Comparar con y sin un índice
DROP INDEX IF EXISTS idx_pedidos_estado;
EXPLAIN ANALYZE SELECT * FROM pedidos WHERE estado = 'pendiente';

 Seq Scan on pedidos  (cost=0.00..32909.00 rows=332267 width=130) (actual time=0.095..259.852 rows=334470 loops=1)
   Filter: ((estado)::text = 'pendiente'::text)
   Rows Removed by Filter: 665530
 Planning Time: 0.130 ms
 Execution Time: 286.888 ms
(5 rows)

CREATE INDEX idx_pedidos_estado ON pedidos(estado);
EXPLAIN ANALYZE SELECT * FROM pedidos WHERE estado = 'pendiente';

 Index Scan using idx_pedidos_estado on pedidos  (cost=0.42..26852.62 rows=332267 width=130) (actual time=0.087..251.260 rows=334470 loops=1)
   Index Cond: ((estado)::text = 'pendiente'::text)
 Planning Time: 0.424 ms
 Execution Time: 264.449 ms
(4 rows)

```

**Verificación:** el ratio `actual rows / estimated rows` debería acercarse a `1.0`;
si se aleja mucho, las estadísticas están desactualizadas → ejecuta `ANALYZE pedidos;`.

---

## 2. Estadísticas: dinámicas y acumuladas

El planificador usa estadísticas sobre la distribución de los datos

**Interpretar `n_distinct`:**

| Valor | Significado |
|---|---|
| `3` | Exactamente 3 valores distintos |
| `-0.33` | ~33% de las filas tienen valores distintos (ej: 333k de 1M) |
| `-1` | Todos los valores son únicos |

```sql
# Ver estadísticas del planificador para pedidos
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT attname, n_distinct, correlation,
           left(most_common_vals::TEXT, 80) AS mcv
    FROM pg_stats
    WHERE tablename = 'pedidos'
    ORDER BY attname;"


# Aumentar target de estadísticas
docker exec -it postgres psql -U pguser -d appdb -c "
    ALTER TABLE pedidos ALTER COLUMN cliente_id SET STATISTICS 500;
    ALTER TABLE pedidos ALTER COLUMN metadatos_pago SET STATISTICS 200;
    ANALYZE pedidos;
    SELECT attname, attstattarget
    FROM pg_attribute
    WHERE attrelid = 'pedidos'::regclass AND attnum > 0;"

# Estadísticas de actividad en tiempo real
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT relname, seq_scan, idx_scan, n_live_tup, n_dead_tup,
           last_analyze, last_autoanalyze
    FROM pg_stat_user_tables
    WHERE relname = 'pedidos';"

# Cache hit ratio
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT relname,
           round(heap_blks_hit*100.0
               /NULLIF(heap_blks_hit+heap_blks_read,0),2) AS cache_hit_pct
    FROM pg_statio_user_tables
    WHERE relname = 'pedidos';"
```
---

### 2.1 Estadísticas dinámicas (vistas del sistema)

Mientras la BD está en uso, PostgreSQL acumula estadísticas de actividad
en tiempo real en las vistas `pg_stat_*`:

```sql
-- Estadísticas de actividad por tabla
SELECT
    relname                         AS tabla,
    seq_scan                        AS escaneos_secuenciales,
    seq_tup_read                    AS filas_leidas_seq,
    idx_scan                        AS escaneos_por_indice,
    idx_tup_fetch                   AS filas_leidas_idx,
    n_tup_ins                       AS inserciones,
    n_tup_upd                       AS actualizaciones,
    n_tup_del                       AS eliminaciones,
    n_live_tup                      AS filas_vivas,
    n_dead_tup                      AS filas_muertas,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE relname = 'pedidos';

-- Estadísticas de uso de índices
SELECT
    indexrelname                    AS indice,
    idx_scan                        AS veces_usado,
    idx_tup_read                    AS entradas_leidas,
    idx_tup_fetch                   AS filas_recuperadas
FROM pg_stat_user_indexes
WHERE relid = 'pedidos'::regclass
ORDER BY idx_scan DESC;

-- Identificar índices nunca usados (candidatos a eliminar)
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio
FROM pg_stat_user_indexes
WHERE relid = 'pedidos'::regclass
  AND idx_scan = 0;

-- Estadísticas de I/O por tabla (hits vs lecturas a disco)
SELECT
    heap_blks_read                  AS paginas_leidas_disco,
    heap_blks_hit                   AS paginas_cache,
    ROUND(heap_blks_hit * 100.0
        / NULLIF(heap_blks_hit + heap_blks_read, 0), 2) AS cache_hit_ratio
FROM pg_statio_user_tables
WHERE relname = 'pedidos';
```
---

## 3. Tipos de escaneo y estrategias de acceso

### 3.1 Sequential Scan (Seq Scan)

Lee **todas las páginas** de la tabla en orden físico. Eficiente cuando se
devuelve un porcentaje alto de filas (> ~5-10%).

```bash
# Sequential Scan (forzado)
docker exec -it postgres psql -U pguser -d appdb -c "
    SET enable_indexscan = off; SET enable_bitmapscan = off;
    EXPLAIN ANALYZE SELECT count(*) FROM pedidos WHERE estado='cancelado';
    RESET ALL;"
```

### 3.2 Index Scan

Recorre el árbol B-tree para encontrar los TIDs (punteros a filas) y luego
hace **accesos aleatorios** al heap. Óptimo para baja selectividad (pocas filas).

```bash
# Index Scan
docker exec -it postgres psql -U pguser -d appdb -c "
    CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON pedidos(cliente_id);
    EXPLAIN ANALYZE SELECT * FROM pedidos WHERE cliente_id = 12345;"
```

### 3.3 Index Only Scan

Si todas las columnas de la consulta están en el índice, PostgreSQL puede
**evitar acceder al heap** completamente. Requiere que la tabla tenga un
`visibility map` actualizado.

La consulta solo necesita las columnas del índice

```bash
# Index Only Scan
docker exec -it postgres psql -U pguser -d appdb -c "
    CREATE INDEX IF NOT EXISTS idx_pedidos_cli_est
        ON pedidos(cliente_id, estado);
    EXPLAIN ANALYZE
        SELECT cliente_id, estado FROM pedidos
        WHERE cliente_id BETWEEN 1000 AND 2000;"
```

```
Index Only Scan using idx_pedidos_cliente_estado on pedidos
  (cost=0.42..58.20 rows=1000 width=12)
  (actual time=0.028..1.234 rows=987 loops=1)
  Heap Fetches: 0   ← No accede al heap
```

---

### 3.4 Bitmap Index Scan + Bitmap Heap Scan

Cuando un índice devuelve muchas filas pero no todas, PostgreSQL construye
un **bitmap en memoria** con las páginas a leer, y luego las lee en orden
físico para minimizar I/O aleatorio.

```sql
EXPLAIN ANALYZE
    SELECT * FROM pedidos WHERE estado = 'pendiente';
```

```
Bitmap Heap Scan on pedidos
  (cost=3821.00..23156.00 rows=333333 width=120)
  (actual time=45.200..312.400 rows=333421 loops=1)
  Recheck Cond: ((estado)::text = 'pendiente')
  Heap Blocks: exact=18456
  ->  Bitmap Index Scan on idx_pedidos_estado
        (cost=0.00..3737.67 rows=333333 width=0)
        (actual time=41.200..41.200 rows=333421 loops=1)
        Index Cond: ((estado)::text = 'pendiente')
```

---

### 3.5 Resumen de estrategias de escaneo

```
┌─────────────────────┬─────────────────────────────────────────────────────┐
│ Tipo de escaneo     │ Cuándo el optimizador lo elige                      │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Seq Scan            │ Alta selectividad (> ~10% de filas)                 │
│ Index Scan          │ Baja selectividad, pocas filas, acceso aleatorio OK │
│ Index Only Scan     │ Todas las columnas en el índice + VM actualizado    │
│ Bitmap Index Scan   │ Selectividad media, muchas filas, I/O ordenado      │
└─────────────────────┴─────────────────────────────────────────────────────┘
```

---

## 4. Tips de optimización de consultas

### 4.1 Usar columnas del índice en el predicado exacto

```sql
-- ❌ Función sobre la columna → el índice no se puede usar
SELECT * FROM pedidos WHERE date_trunc('day', fecha_creacion) = '2025-09-01';

-- ✅ Predicado de rango → el índice sí se usa
SELECT * FROM pedidos
WHERE fecha_creacion >= '2025-09-01'
  AND fecha_creacion <  '2025-09-02';
```
```bash
docker exec -it postgres psql -U pguser -d appdb -c "
    CREATE INDEX IF NOT EXISTS idx_pedidos_fecha ON pedidos(fecha_creacion);
    EXPLAIN SELECT * FROM pedidos
    WHERE date_trunc('day', fecha_creacion) = '2025-09-01';

    EXPLAIN SELECT * FROM pedidos
    WHERE fecha_creacion >= '2025-09-01'
      AND fecha_creacion <  '2025-09-02';"
CREATE INDEX
                                                   QUERY PLAN                                                   
----------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..26747.71 rows=5000 width=130)
   Workers Planned: 3
   ->  Parallel Seq Scan on pedidos  (cost=0.00..25247.71 rows=1613 width=130)
         Filter: (date_trunc('day'::text, fecha_creacion) = '2025-09-01 00:00:00'::timestamp without time zone)
(4 rows)

                                                                               QUERY PLAN                                                                               
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on pedidos  (cost=16.67..1462.02 rows=1370 width=130)
   Recheck Cond: ((fecha_creacion >= '2025-09-01 00:00:00'::timestamp without time zone) AND (fecha_creacion < '2025-09-02 00:00:00'::timestamp without time zone))
   ->  Bitmap Index Scan on idx_pedidos_fecha  (cost=0.00..16.33 rows=1370 width=0)
         Index Cond: ((fecha_creacion >= '2025-09-01 00:00:00'::timestamp without time zone) AND (fecha_creacion < '2025-09-02 00:00:00'::timestamp without time zone))
(4 rows)
```

---

### 4.2 Evitar conversiones de tipo implícitas

```sql
-- ❌ cliente_id es INTEGER pero comparamos con un string
SELECT * FROM pedidos WHERE cliente_id = '12345';

-- ✅ Usar el tipo correcto
SELECT * FROM pedidos WHERE cliente_id = 12345;
```

---

### 4.3 Usar `EXISTS` en lugar de `IN` con subqueries grandes

```sql
-- ❌ IN materializa todo el resultado de la subconsulta
SELECT * FROM pedidos
WHERE cliente_id IN (SELECT id FROM clientes WHERE pais = 'ES');

-- ✅ EXISTS para con la primera coincidencia
SELECT p.* FROM pedidos p
WHERE EXISTS (
    SELECT 1 FROM clientes c
    WHERE c.id = p.cliente_id AND c.pais = 'ES'
);
```

### 4.4 Paginar eficientemente con Keyset en lugar de OFFSET

```sql
-- ❌ OFFSET escanea y descarta filas (O(n))
SELECT * FROM pedidos
ORDER BY fecha_creacion DESC
LIMIT 20 OFFSET 10000;

-- ✅ Keyset Pagination: usa el índice directamente (O(log n))
-- (guardar el valor de fecha_creacion de la última fila devuelta)
SELECT * FROM pedidos
WHERE fecha_creacion < '2025-08-15 10:30:00'   -- último valor de la página anterior
ORDER BY fecha_creacion DESC
LIMIT 20;
```

```bash
$ docker exec -it postgres psql -U pguser -d appdb -c "
    -- Lento: OFFSET
    EXPLAIN ANALYZE
        SELECT * FROM pedidos ORDER BY fecha_creacion DESC LIMIT 20 OFFSET 10000;

    -- Rápido: Keyset
    EXPLAIN ANALYZE
        SELECT * FROM pedidos
        WHERE fecha_creacion < '2025-01-01'
        ORDER BY fecha_creacion DESC LIMIT 20;"
                                                                        QUERY PLAN                                                                         
-----------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=384.75..385.52 rows=20 width=130) (actual time=30.606..30.632 rows=20 loops=1)
   ->  Index Scan Backward using idx_pedidos_fecha on pedidos  (cost=0.42..38432.60 rows=1000000 width=130) (actual time=0.137..29.821 rows=10020 loops=1)
 Planning Time: 1.105 ms
 Execution Time: 30.694 ms
(4 rows)

                                                                      QUERY PLAN                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.42..2.68 rows=20 width=130) (actual time=0.076..0.106 rows=20 loops=1)
   ->  Index Scan Backward using idx_pedidos_fecha on pedidos  (cost=0.42..26850.81 rows=238082 width=130) (actual time=0.075..0.101 rows=20 loops=1)
         Index Cond: (fecha_creacion < '2025-01-01 00:00:00'::timestamp without time zone)
 Planning Time: 0.162 ms
 Execution Time: 0.129 ms
(5 rows)

```

### 4.5 Usar `RETURNING` para evitar un SELECT extra

```sql
-- ❌ UPDATE + SELECT separados → dos round-trips
UPDATE pedidos SET estado = 'procesado' WHERE id = $1;
SELECT * FROM pedidos WHERE id = $1;

-- ✅ RETURNING devuelve la fila actualizada en una sola operación
UPDATE pedidos
SET estado = 'procesado'
WHERE id = $1
RETURNING id, estado, fecha_creacion;
```

## 5. Índices: selección, diseño y mantenimiento

### 5.1 Tipos de índice disponibles

| Tipo | Operadores | Caso de uso |
|---|---|---|
| `B-tree` *(defecto)* | `=`, `<`, `>`, `BETWEEN`, `LIKE 'abc%'` | La mayoría de los casos |
| `Hash` | Solo `=` | Búsquedas exactas (PG10+ WAL-safe) |
| `GIN` | `@>`, `?`, `?|`, `?&`, `@@` | JSONB, arrays, full-text search |
| `GiST` | Geométricos, rangos, full-text | PostGIS, tipos exclusión |
| `BRIN` | Rangos de valores en bloques físicos | Tablas muy grandes con datos ordenados |
| `SP-GiST` | Particionado espacial | Datos jerárquicos, polígonos |

---

### 5.2 Índices sobre la tabla `pedidos`

```sql
-- ── Índice simple en columna de alta selectividad ────────────────
CREATE INDEX idx_pedidos_cliente
    ON pedidos(cliente_id);

-- ── Índice compuesto: el orden importa ───────────────────────────
-- Sirve para: WHERE cliente_id = X
--             WHERE cliente_id = X AND estado = Y
-- NO sirve para: WHERE estado = Y (sin cliente_id)
CREATE INDEX idx_pedidos_cliente_estado
    ON pedidos(cliente_id, estado);

-- ── Índice parcial: solo filas 'pendiente' ───────────────────────
-- Mucho más pequeño que un índice completo sobre estado
CREATE INDEX idx_pedidos_pendientes
    ON pedidos(fecha_creacion)
    WHERE estado = 'pendiente';

-- Uso del índice parcial:
SELECT * FROM pedidos
WHERE estado = 'pendiente'
  AND fecha_creacion > now() - INTERVAL '7 days';

-- ── Índice sobre expresión ────────────────────────────────────────
CREATE INDEX idx_pedidos_fecha_dia
    ON pedidos(date_trunc('day', fecha_creacion));

-- Ahora sí puede usar el índice:
SELECT * FROM pedidos
WHERE date_trunc('day', fecha_creacion) = '2025-09-01';

-- ── Índice GIN para JSONB ─────────────────────────────────────────
CREATE INDEX idx_pedidos_metadatos
    ON pedidos USING GIN (metadatos_pago);

-- Consultas que se benefician:
SELECT * FROM pedidos
WHERE metadatos_pago @> '{"pasarela": "stripe", "moneda": "EUR"}';

-- ── Índice GIN para jsonb_path_ops (más compacto, solo soporta @>) ─
CREATE INDEX idx_pedidos_metadatos_path
    ON pedidos USING GIN (metadatos_pago jsonb_path_ops);

-- ── Índice BRIN para fecha (datos casi-ordenados físicamente) ────
-- Muy pequeño: 1 entrada por rango de páginas
CREATE INDEX idx_pedidos_fecha_brin
    ON pedidos USING BRIN (fecha_creacion)
    WITH (pages_per_range = 128);

-- ── Índice covering (INCLUDE): Index Only Scan sin acceder al heap ─
CREATE INDEX idx_pedidos_cliente_covering
    ON pedidos(cliente_id)
    INCLUDE (estado, fecha_creacion);

-- Esta consulta puede resolverse solo con el índice:
SELECT cliente_id, estado, fecha_creacion
FROM pedidos
WHERE cliente_id = 42;


# Ver tamaño y uso de todos los índices
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT i.indexrelname AS indice,
           pg_size_pretty(pg_relation_size(i.indexrelid)) AS tamanio,
           i.idx_scan AS usos
    FROM pg_stat_user_indexes i
    WHERE i.relid = 'pedidos'::regclass
    ORDER BY i.idx_scan DESC;"

# Índices nunca usados
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT indexrelname,
           pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio_desperdiciado
    FROM pg_stat_user_indexes
    WHERE relid = 'pedidos'::regclass AND idx_scan = 0;"

```

---

### 5.3 Crear índices sin bloquear escrituras

```sql
-- CREATE INDEX bloquea escrituras durante la construcción
-- CREATE INDEX CONCURRENTLY no bloquea pero tarda más y usa más recursos
CREATE INDEX CONCURRENTLY idx_pedidos_estado
    ON pedidos(estado);

-- Reindexar sin bloqueo (PostgreSQL 12+)
REINDEX INDEX CONCURRENTLY idx_pedidos_estado;

# Crear índice sin bloquear escrituras
docker exec -it postgres psql -U pguser -d appdb -c "
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pedidos_estado
        ON pedidos(estado);"
```

---

### 5.4 Mantenimiento y diagnóstico de índices

```sql
-- Tamaño y uso de todos los índices de pedidos
SELECT
    i.indexrelname                                    AS indice,
    pg_size_pretty(pg_relation_size(i.indexrelid))    AS tamanio,
    i.idx_scan                                        AS usos,
    i.idx_tup_read,
    i.idx_tup_fetch,
    ix.indisunique                                    AS es_unico,
    ix.indisprimary                                   AS es_pk
FROM pg_stat_user_indexes i
JOIN pg_index ix ON ix.indexrelid = i.indexrelid
WHERE i.relid = 'pedidos'::regclass
ORDER BY i.idx_scan DESC;

-- Índices duplicados o redundantes
SELECT
    ca.relname AS indice_a,
    cb.relname AS indice_b,
    a.indkey::TEXT AS columnas_a,
    b.indkey::TEXT AS columnas_b
FROM pg_index a
JOIN pg_index b
    ON a.indrelid = b.indrelid
    AND a.indexrelid < b.indexrelid
    AND a.indkey::TEXT = b.indkey::TEXT
JOIN pg_class ca ON ca.oid = a.indexrelid
JOIN pg_class cb ON cb.oid = b.indexrelid
WHERE a.indrelid = 'pedidos'::regclass;

-- Hinchazón de índices: reconstruir si hay mucho bloat
SELECT
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio_actual
FROM pg_stat_user_indexes
WHERE relid = 'pedidos'::regclass
ORDER BY pg_relation_size(indexrelid) DESC;

-- Reconstruir índice hinchado sin bloqueo
REINDEX INDEX CONCURRENTLY idx_pedidos_cliente;
```

---

## 6. Índices hipotéticos con hypopg

Los índices hipotéticos permiten evaluar si un índice sería beneficioso
**sin crearlo realmente** en disco, usando la extensión `hypopg`.

```bash
# hypopg ya está instalado — verificar
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT extname, extversion FROM pg_extension WHERE extname='hypopg';"

# Evaluar un índice compuesto sin crearlo en disco
docker exec -it postgres psql -U pguser -d appdb -c "
    -- Plan SIN el índice
    EXPLAIN SELECT * FROM pedidos
    WHERE estado='pendiente' AND fecha_creacion > now() - INTERVAL '30 days';

    -- Crear índice hipotético
    SELECT * FROM hypopg_create_index(
        'CREATE INDEX ON pedidos(estado, fecha_creacion)');

    -- Plan CON el índice hipotético (coste estimado)
    EXPLAIN SELECT * FROM pedidos
    WHERE estado='pendiente' AND fecha_creacion > now() - INTERVAL '30 days';

    -- Limpiar
    SELECT hypopg_reset();"

# Evaluar 3 candidatos en secuencia
docker exec -it postgres psql -U pguser -d appdb -c "
    -- Candidato 1
    SELECT hypopg_create_index('CREATE INDEX ON pedidos(estado)');
    EXPLAIN SELECT * FROM pedidos WHERE estado='cancelado';
    SELECT hypopg_reset();

    -- Candidato 2: índice parcial
    SELECT hypopg_create_index(
        'CREATE INDEX ON pedidos(fecha_creacion) WHERE estado=''pendiente''');
    EXPLAIN SELECT * FROM pedidos
    WHERE estado='pendiente' AND fecha_creacion > now()-INTERVAL '7 days';
    SELECT hypopg_reset();

    -- Candidato 3: covering
    SELECT hypopg_create_index(
        'CREATE INDEX ON pedidos(cliente_id) INCLUDE (estado, fecha_creacion)');
    EXPLAIN SELECT cliente_id, estado, fecha_creacion
    FROM pedidos WHERE cliente_id=42;
    SELECT hypopg_reset();"
```

---

## 7. Particionado y pruning

### 7.1 Particionado por rango de fecha

```sql
-- Tabla madre (particionada)
CREATE TABLE pedidos_part (
    id              UUID          NOT NULL DEFAULT gen_random_uuid(),
    cliente_id      INTEGER       NOT NULL,
    fecha_creacion  TIMESTAMP     NOT NULL DEFAULT now(),
    estado          VARCHAR(20)   NOT NULL
                        CHECK (estado IN ('pendiente','procesado','cancelado')),
    metadatos_pago  JSONB
) PARTITION BY RANGE (fecha_creacion);

-- Crear particiones trimestrales
CREATE TABLE pedidos_2025_q1
    PARTITION OF pedidos_part
    FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');

CREATE TABLE pedidos_2025_q2
    PARTITION OF pedidos_part
    FOR VALUES FROM ('2025-04-01') TO ('2025-07-01');

CREATE TABLE pedidos_2025_q3
    PARTITION OF pedidos_part
    FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');

CREATE TABLE pedidos_2025_q4
    PARTITION OF pedidos_part
    FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');

-- Índices sobre cada partición (se crean automáticamente en nuevas particiones
-- si se crean sobre la tabla madre en PG11+)
CREATE INDEX ON pedidos_part(cliente_id);
CREATE INDEX ON pedidos_part(estado);

-- Insertar muestra para prácticas de particionado
INSERT INTO pedidos_part (cliente_id, fecha_creacion, estado, metadatos_pago)
SELECT
    (random() * 100000)::INT,
    make_date(2025, (random()*11+1)::INT, (random()*27+1)::INT)::TIMESTAMP,
    (ARRAY['pendiente','procesado','cancelado'])[ceil(random()*3)],
    jsonb_build_object('importe', round((random()*500+10)::numeric,2))
FROM generate_series(1, 100000)
ON CONFLICT DO NOTHING;

```



```bash
# Ver las particiones creadas
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT inhrelid::regclass AS particion,
           pg_size_pretty(pg_relation_size(inhrelid)) AS tamanio
    FROM pg_inherits
    WHERE inhparent = 'pedidos_part'::regclass;"

# Partition pruning: solo debe escanear pedidos_2025_q3
docker exec -it postgres psql -U pguser -d appdb -c "
    SET enable_partition_pruning = on;
    EXPLAIN ANALYZE
        SELECT count(*) FROM pedidos_part
        WHERE fecha_creacion BETWEEN '2025-07-01' AND '2025-09-30';"

Comprueba el *partition pruning* con `EXPLAIN` — solo debería listar la partición
relevante para el filtro de fecha usado en la consulta.
```

### 7.2 Partition Pruning

El planificador elimina automáticamente las particiones que no satisfacen
el predicado de la consulta:

```sql
-- Activar pruning (está ON por defecto)
SET enable_partition_pruning = on;

-- Esta consulta solo escanea pedidos_2025_q3
EXPLAIN ANALYZE
    SELECT count(*) FROM pedidos_part
    WHERE fecha_creacion BETWEEN '2025-07-01' AND '2025-09-30';
```

```
Aggregate
  ->  Append
        ->  Seq Scan on pedidos_2025_q3
              Filter: (fecha_creacion BETWEEN ...)
              -- Las otras 3 particiones fueron eliminadas por pruning
```

```sql
-- Pruning dinámico (con parámetros en tiempo de ejecución)
PREPARE q_part AS
    SELECT * FROM pedidos_part WHERE fecha_creacion > $1;

EXPLAIN EXECUTE q_part('2025-09-01');
-- El pruning ocurre en tiempo de ejecución al conocer $1
```

### 7.3 Ejecución paralela

```sql
-- Configuración de paralelismo (postgresql.conf o por sesión)
SET max_parallel_workers_per_gather = 4;  -- Workers por nodo Gather
SET parallel_tuple_cost    = 0.1;
SET parallel_setup_cost    = 1000;
SET min_parallel_table_scan_size = '8MB';

-- Forzar paralelismo en una consulta
SET max_parallel_workers_per_gather = 4;

EXPLAIN ANALYZE
    SELECT estado, count(*), avg((metadatos_pago->>'importe')::numeric)
    FROM pedidos
    GROUP BY estado;
```

```
Finalize GroupAggregate
  ->  Gather Merge
        Workers Planned: 4
        Workers Launched: 4
        ->  Partial GroupAggregate
              ->  Parallel Seq Scan on pedidos
                    Workers Planned: 4
                    Workers Launched: 4
```

```sql
-- Forzar paralelismo en una tabla específica
ALTER TABLE pedidos SET (parallel_workers = 4);

-- Deshabilitar paralelismo para una consulta específica
SET max_parallel_workers_per_gather = 0;
EXPLAIN ANALYZE SELECT count(*) FROM pedidos;
RESET max_parallel_workers_per_gather;
```

---

## 8. Análisis de planes de ejecución (JOINs)

```bash
# Nested Loop (tabla pequeña)
-- NESTED LOOP: eficiente cuando la tabla interior es pequeña o está indexada
docker exec -it postgres psql -U pguser -d appdb -c "
    EXPLAIN ANALYZE
        SELECT p.id, c.nombre
        FROM pedidos p JOIN clientes c ON c.id = p.cliente_id
        WHERE p.cliente_id < 10;"

# Hash Join
-- HASH JOIN: materializa la tabla menor en memoria → eficiente para tablas grandes
docker exec -it postgres psql -U pguser -d appdb -c "
    SET enable_nestloop = off;
    EXPLAIN ANALYZE
        SELECT p.id, c.nombre
        FROM pedidos p JOIN clientes c ON c.id = p.cliente_id;
    RESET enable_nestloop;"

# Merge Join
-- MERGE JOIN: requiere ambas entradas ordenadas → eficiente con índices
docker exec -it postgres psql -U pguser -d appdb -c "
    SET enable_hashjoin = off;
    EXPLAIN ANALYZE
        SELECT p.id, c.nombre
        FROM pedidos p JOIN clientes c ON c.id = p.cliente_id
        ORDER BY p.cliente_id;
    RESET enable_hashjoin;"

```

### 8.1 Herramientas de visualización de planes

```sql
EXPLAIN (ANALYZE, BUFFERS)
    SELECT p.id, p.estado, c.nombre,
           p.metadatos_pago->>'importe' AS importe
    FROM pedidos p
    JOIN clientes c ON c.id = p.cliente_id
    WHERE p.estado = 'pendiente'
      AND p.fecha_creacion > now() - INTERVAL '30 days'
    ORDER BY p.fecha_creacion DESC
    LIMIT 100;
```

> **Herramientas online:**
> - [explain.depesz.com](https://explain.depesz.com) — colorea nodos por coste
> - [explain.tensor.ru](https://explain.tensor.ru) — visualización en árbol interactivo
> - [pgMustard](https://www.pgmustard.com) — sugerencias de optimización automáticas

---


## 9. Cuellos de botella y bloqueos

El proyecto proporciona vistas de diagnóstico en el schema `monitoring` (creadas por `init.sql`):

```sql
SELECT * FROM monitoring.long_running_queries;
SELECT * FROM monitoring.blocking_queries;
```

También puedes usar el script incluido `consulta_pg_locks.sql`:

```bash
docker exec -it postgres psql -U pguser -d appdb -f /dev/stdin < consulta_pg_locks.sql
```

Y generar bloqueos/actividad de prueba con el simulador ya incluido:

```bash
./simular_carga.sh          # genera actividad para las secciones de diagnóstico
./diagnostico_postgres.sh   # muestra el estado consolidado
./simular_carga.sh --stop   # detiene los procesos de carga
```

---

### 9.1 Detectar queries lentas en tiempo real

```sql
-- Queries activas con duración > 5 segundos
SELECT
    pid,
    now() - query_start                AS duracion,
    state,
    wait_event_type,
    wait_event,
    left(query, 120)                   AS query_truncada,
    client_addr,
    application_name
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > INTERVAL '5 seconds'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duracion DESC;

-- Terminar una query lenta (no mata la sesión)
SELECT pg_cancel_backend(pid);

-- Terminar la sesión completa (más agresivo)
SELECT pg_terminate_backend(pid);
```
---

### 9.2 Detectar bloqueos y cadenas de bloqueo

```sql
-- Ver bloqueos activos con la query bloqueante y la bloqueada
SELECT
    blocked.pid                         AS pid_bloqueado,
    blocked.usename                     AS usuario_bloqueado,
    blocked.application_name,
    left(blocked.query, 80)             AS query_bloqueada,
    blocking.pid                        AS pid_bloqueante,
    blocking.usename                    AS usuario_bloqueante,
    left(blocking.query, 80)            AS query_bloqueante,
    now() - blocked.query_start         AS tiempo_esperando,
    blocked.wait_event_type,
    blocked.wait_event
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;

-- Ver el grafo completo de esperas (cadenas de bloqueo)
WITH RECURSIVE cadena AS (
    SELECT pid, pg_blocking_pids(pid) AS bloqueado_por
    FROM pg_stat_activity
    WHERE cardinality(pg_blocking_pids(pid)) > 0

    UNION ALL

    SELECT a.pid, pg_blocking_pids(a.pid)
    FROM pg_stat_activity a
    JOIN cadena c ON a.pid = ANY(c.bloqueado_por)
)
SELECT DISTINCT pid, bloqueado_por FROM cadena;
```

---

### 9.3 Bloqueos a nivel de tabla y fila

```sql
-- Ver todos los bloqueos activos con el tipo de lock
SELECT
    l.relation::regclass              AS objeto,
    l.locktype,
    l.mode,
    l.granted,
    a.pid,
    a.usename,
    now() - a.query_start             AS duracion,
    left(a.query, 80)                 AS query
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.relation IS NOT NULL
ORDER BY duracion DESC;
```

### 9.4 Estrategias para evitar bloqueos

```sql
-- ── Estrategia 1: SKIP LOCKED (procesar sin bloquear) ────────────
-- Patrón de cola de trabajo: cada worker toma filas no bloqueadas
BEGIN;
SELECT id, cliente_id, metadatos_pago
FROM pedidos
WHERE estado = 'pendiente'
ORDER BY fecha_creacion
LIMIT 10
FOR UPDATE SKIP LOCKED;
-- procesar...
UPDATE pedidos SET estado = 'procesado' WHERE id = ANY(ARRAY[...]);
COMMIT;

-- ── Estrategia 2: Lock Timeout (no esperar más de N ms) ──────────
SET lock_timeout = '2s';
BEGIN;
SELECT * FROM pedidos WHERE id = $1 FOR UPDATE;
COMMIT;
RESET lock_timeout;

-- ── Estrategia 3: deadlock timeout ───────────────────────────────
-- postgresql.conf: deadlock_timeout = 1s (detecta deadlocks en 1s)
-- El deadlock se registra en el log con los PIDs implicados

-- ── Estrategia 4: UPDATE por lotes (evitar locks largos) ─────────
-- En lugar de UPDATE de 1M filas en una sola transacción:
DO $$
DECLARE
    filas_afectadas INT;
BEGIN
    LOOP
        UPDATE pedidos
        SET estado = 'procesado'
        WHERE id IN (
            SELECT id FROM pedidos
            WHERE estado = 'pendiente'
              AND fecha_creacion < now() - INTERVAL '90 days'
            LIMIT 1000
            FOR UPDATE SKIP LOCKED
        );
        GET DIAGNOSTICS filas_afectadas = ROW_COUNT;
        EXIT WHEN filas_afectadas = 0;
        PERFORM pg_sleep(0.01);  -- Mini-pausa entre lotes
    END LOOP;
END;
$$;
```

```bash
# Ver queries activas con duración > 1s
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT pid, now()-query_start AS duracion, state,
           wait_event_type, wait_event, left(query,100) AS query
    FROM pg_stat_activity
    WHERE state='active'
      AND now()-query_start > INTERVAL '1 second'
      AND query NOT LIKE '%pg_stat_activity%'
    ORDER BY duracion DESC;"

# Simular bloqueo en una terminal, detectarlo en otra
# Terminal 1: iniciar transacción larga
docker exec -it postgres psql -U pguser -d appdb -c "
    BEGIN;
    SELECT * FROM pedidos WHERE id=(SELECT id FROM pedidos LIMIT 1) FOR UPDATE;"

# Terminal 2: detectar el bloqueo
docker exec -it postgres psql -U pguser -d appdb -c "
    SELECT blocked.pid AS bloqueado, blocking.pid AS bloqueante,
           left(blocked.query,60) AS query_bloqueada,
           now()-blocked.query_start AS esperando
    FROM pg_stat_activity blocked
    JOIN pg_stat_activity blocking
        ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
    WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;"

# SKIP LOCKED — patrón de cola de trabajo
docker exec -it postgres psql -U pguser -d appdb -c "
    BEGIN;
    SELECT id, cliente_id FROM pedidos
    WHERE estado='pendiente'
    ORDER BY fecha_creacion LIMIT 5
    FOR UPDATE SKIP LOCKED;
    ROLLBACK;"

# UPDATE por lotes (evitar locks largos)
docker exec -it postgres psql -U pguser -d appdb -c "
    DO \$\$
    DECLARE n INT;
    BEGIN
        LOOP
            UPDATE pedidos SET estado='procesado'
            WHERE id IN (
                SELECT id FROM pedidos
                WHERE estado='pendiente'
                  AND fecha_creacion < now()-INTERVAL '700 days'
                LIMIT 500 FOR UPDATE SKIP LOCKED
            );
            GET DIAGNOSTICS n = ROW_COUNT;
            EXIT WHEN n = 0;
            PERFORM pg_sleep(0.01);
        END LOOP;
        RAISE NOTICE 'Actualización por lotes completada';
    END;
    \$\$;"

```

---

### 9.5 Configuración de timeouts

```ini
# postgresql.conf
statement_timeout        = 30s     # Cancelar queries que superen 30s
lock_timeout             = 5s      # No esperar más de 5s por un lock
idle_in_transaction_session_timeout = 60s  # Cerrar sesiones idle en transacción
deadlock_timeout         = 1s      # Tiempo antes de detectar deadlock
```

```sql
-- Por sesión (para una operación específica)
SET statement_timeout = '10s';
SELECT count(*) FROM pedidos;   -- Cancelado si tarda > 10s
RESET statement_timeout;

# Configurar timeouts por sesión
docker exec -it postgres psql -U pguser -d appdb -c "
    SET statement_timeout = '5s';
    SET lock_timeout      = '2s';
    SHOW statement_timeout;
    SHOW lock_timeout;
    RESET ALL;"
```

---

## 10. pgbench: pruebas de carga sobre `pedidos`

**Benchmark estándar de pgbench** (transacciones tipo TPC-B):

```bash
docker exec -it postgres pgbench -i -s 50 -U pguser appdb   # inicializar (scale 50)
docker exec -it postgres pgbench -c 20 -j 4 -T 60 -U pguser appdb

$ docker exec -it postgres pgbench     -c 20 -j 4 -T 120     -f /scripts/test_carga_pedidos.sql     --progress=10 -U pguser appdb

```

# Benchmark TPC-B básico: 10 clientes, 60 segundos
docker exec -it postgres pgbench -c 10 -j 4 -T 60 -P 5 -U pguser appdb

# Solo lectura
docker exec -it postgres pgbench -c 20 -T 60 -S -U pguser appdb

Mientras se ejecuta, observa en Grafana el dashboard **PostgreSQL Overview** (conexiones,
TPS, `cache_hit_ratio`) y en Prometheus la métrica `pg_stat_database_temp_bytes` para
detectar si las consultas están desbordando `work_mem`.


---

## 10. pgBadger: análisis forense de logs

Los logs ya se escriben en el volumen `postgres_logs` gracias a `logging_collector=on`
en `configs/postgresql.conf`. Genera el reporte con el script incluido:

```bash
docker exec -it postgres /scripts/pgbadger_report.sh

# Copiar el reporte HTML al host para abrirlo en el navegador
docker cp postgres:/pgbadger_reports/report_<timestamp>.html ./report.html
```

---

## 11. pg_stat_statements, pg_locks y vistas de diagnóstico

```sql
-- Top 10 consultas más costosas acumuladas
SELECT left(query, 80) AS query, calls,
       round(mean_exec_time::numeric, 2)  AS mean_ms,
       round(total_exec_time::numeric, 2) AS total_ms
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;

-- Cache hit ratio (objetivo: > 99%)
SELECT sum(heap_blks_hit) * 100.0 / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0)
       AS cache_hit_pct
FROM pg_statio_user_tables;
```

Estas mismas queries son las que alimentan `postgres-exporter/queries.yaml` → Prometheus
→ los dashboards de Grafana descritos a continuación.

---

#### Métricas clave a monitorizar

```sql
-- Estas queries alimentan los dashboards de Grafana via postgres_exporter

-- Cache hit ratio (objetivo: > 99%)
SELECT
    sum(heap_blks_hit) * 100.0
    / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) AS cache_hit_pct
FROM pg_statio_user_tables;

-- Conexiones activas vs límite
SELECT count(*),
       current_setting('max_connections')::INT AS limite,
       round(count(*) * 100.0
           / current_setting('max_connections')::INT, 1) AS pct_uso
FROM pg_stat_activity;

-- Tamaño de la base de datos
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Tasa de transacciones (requiere dos muestras con intervalo)
SELECT xact_commit + xact_rollback AS total_tx
FROM pg_stat_database
WHERE datname = current_database();

-- Tiempo medio de queries lentas (pg_stat_statements)
SELECT round(avg(mean_exec_time)::numeric, 2) AS avg_mean_ms,
       round(max(mean_exec_time)::numeric, 2) AS max_mean_ms
FROM pg_stat_statements
WHERE calls > 100;
```

## 12. Dashboards de Grafana

El proyecto ya incluye un dashboard personalizado (`grafana/dashboards/postgres-complete.json`)
aprovisionado automáticamente. Además, puedes importar estos dashboards públicos por ID
desde **Grafana → Dashboards → Import**:

| Dashboard | ID | Utilidad para esta guía |
|---|---|---|
| PostgreSQL Overview | `9628` | TPS, conexiones, cache hit — ideal durante las pruebas de pgbench |
| PostgreSQL Monitoring | `24298` | Bloqueos, locks, replicación, WAL |
| PostgreSQL Bloat | `14114` | Bloat de tablas/índices tras pruebas de carga repetidas |

| Dashboard | ID | Descripción |
|---|---|---|
| PostgreSQL Overview | `9628` | Métricas generales del servidor |
| PostgreSQL Bloat | `14114` | Bloat por tabla e índice |
| pgBadger Metrics | `14544` | Queries lentas desde pg_stat_statements |
| PostgreSQL Details | `12485` | Locks, conexiones, WAL, checkpoints |

---

## 13. Alertas en Prometheus/Alertmanager

Reglas ya definidas en `prometheus/alerts/postgres_alerts.yml` — relevantes durante
las pruebas de carga de esta guía:

- Conexiones cerca del límite (`max_connections`)
- Cache hit ratio por debajo del umbral
- Bloqueos prolongados (`blocking_queries`)
- Replicación con lag alto (si usas `docker-compose.replica.yml`)

Consulta el estado de las alertas en http://localhost:9093.

---

## 14. Logs con Loki

Promtail recoge los logs del contenedor `postgres` vía el socket de Docker y los envía
a Loki. En Grafana, usa **Explore → Loki** con consultas LogQL como:

```logql
{container="postgres"} |= "duration:"
```

para ver en vivo las queries lentas capturadas por `log_min_duration_statement=100`
mientras corre `pgbench`.

---

## 15. Checklist de verificación

| Área | Verificación | Objetivo |
|---|---|---|
| EXPLAIN | `actual rows / estimated rows` | Cercano a 1.0 |
| Índices | `idx_scan > 0` en `pg_stat_user_indexes` | Sin índices sin usar |
| Cache hit | `heap_blks_hit / (hit+read)` | > 99% |
| Locks | `monitoring.blocking_queries` | Vacío en condiciones normales |
| pgbench | `tps` y `latency average` | Establecer línea base antes/después de indexar |
| pgBadger | Reporte HTML generado | Queries > 100ms identificadas |
| Grafana | Dashboard PostgreSQL Overview | Datos visibles durante la prueba de carga |

---

## 16. Troubleshooting

| Síntoma | Causa probable | Solución |
|---|---|---|
| `relation "pedidos" does not exist` | `02_pedidos_lab.sql` no se ejecutó (volumen `postgres_data` ya existía) | `docker compose down -v && docker compose up -d` |
| pgBadger no encuentra logs | `logging_collector=off` o volumen no montado | Verifica `configs/postgresql.conf` y que `postgres_logs` esté montado en `postgres` |
| `hypopg_create_index` falla | Extensión no instalada | Confirma que la imagen se construyó con `Dockerfile.postgres`, no la `postgres:16-alpine` original |
| pgbench muy lento / timeouts | `max_connections` agotado por otros procesos | Revisa `pg_stat_activity` y el dashboard de conexiones en Grafana |
| El contenedor tarda mucho en pasar a `healthy` | Primera carga de 1M filas | Normal la primera vez (~60-90s); revisa `docker compose logs -f postgres` |

---

## 17. Configuración de tuning aplicada

Ver `configs/postgresql.conf` para el detalle completo. Resumen de los valores clave
para este laboratorio (ajustados para un contenedor de ~2-4GB RAM, no producción):

```ini
shared_buffers        = 512MB
effective_cache_size  = 1536MB
work_mem              = 32MB
random_page_cost      = 1.1     # asumiendo almacenamiento SSD/NVMe del host
log_min_duration_statement = 100
logging_collector     = on      # necesario para pgBadger
```

---

## 18. Referencias

- [PostgreSQL — Using EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html)
- [PostgreSQL — Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html)
- [hypopg](https://hypopg.readthedocs.io/)
- [pgBadger](https://pgbadger.darold.net/)
- [pgbench](https://www.postgresql.org/docs/current/pgbench.html)
- [postgres_exporter](https://github.com/prometheus-community/postgres_exporter)
