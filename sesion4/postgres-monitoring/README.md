# 🐘 Monitorización de PostgreSQL con Prometheus, Grafana y Loki

> Stack completo de observabilidad para PostgreSQL: métricas, dashboards, alertas y agregación de logs.

---

## 📋 Tabla de Contenidos

1. [Arquitectura del Stack](#1-arquitectura-del-stack)
2. [Requisitos Previos](#2-requisitos-previos)
3. [Estructura del Proyecto](#3-estructura-del-proyecto)
4. [Inicio Rápido](#4-inicio-rápido)
5. [Métricas Esenciales](#5-métricas-esenciales)
6. [pg_stat_activity, pg_locks y Vistas de Diagnóstico](#6-pg_stat_activity-pg_locks-y-vistas-de-diagnóstico)
7. [Integración con Prometheus y PostgreSQL Exporter](#7-integración-con-prometheus-y-postgresql-exporter)
8. [Dashboards en Grafana](#8-dashboards-en-grafana)
9. [Dashboard: PostgreSQL Database (ID 9628)](#9-dashboard-postgresql-database-id-9628)
10. [Estado de la Instancia](#10-estado-de-la-instancia)
11. [Conexiones](#11-conexiones)
12. [Uso de Recursos](#12-uso-de-recursos)
13. [Dashboard: PostgreSQL Monitoring (ID 24298)](#13-dashboard-postgresql-monitoring-id-24298)
14. [Análisis de Bloqueos](#14-análisis-de-bloqueos)
15. [Caché e I/O](#15-caché-e-io)
16. [Mantenimiento y Autovacuum](#16-mantenimiento-y-autovacuum)
17. [Replicación](#17-replicación)
18. [WAL (Write-Ahead Log)](#18-wal-write-ahead-log)
19. [Loki: Agregación de Logs](#19-loki-agregación-de-logs)
20. [Alertas](#20-alertas)
21. [Troubleshooting](#21-troubleshooting)

---

## 1. Arquitectura del Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Network: monitoring               │
│                                                                 │
│  ┌──────────────┐    scrape     ┌─────────────────────────┐    │
│  │  PostgreSQL  │◄──────────────│   postgres-exporter     │    │
│  │  :5432       │               │   :9187                 │    │
│  └──────────────┘               └────────────┬────────────┘    │
│         │ logs                               │ metrics          │
│         ▼                                    ▼                  │
│  ┌──────────────┐  push logs   ┌─────────────────────────┐    │
│  │   Promtail   │─────────────►│         Loki            │    │
│  │   :9080      │               │         :3100           │    │
│  └──────────────┘               └────────────┬────────────┘    │
│                                              │                  │
│                       ┌──────────────────────┤                  │
│                       │ query logs           │ query metrics    │
│                       ▼                      ▼                  │
│               ┌───────────────────────────────────────────┐    │
│               │              Grafana :3000                 │    │
│               │         Dashboards + Alertas               │    │
│               └───────────────────────────────────────────┘    │
│                                    ▲                            │
│  ┌──────────────────────────┐      │ datasource                 │
│  │      Prometheus :9090    │──────┘                           │
│  │   (almacena métricas)    │                                   │
│  └──────────────────────────┘                                   │
│           │ alertas                                             │
│           ▼                                                     │
│  ┌──────────────────────────┐                                   │
│  │  Alertmanager :9093      │                                   │
│  └──────────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────┘
```

| Componente | Puerto | Función |
|---|---|---|
| PostgreSQL | 5432 | Base de datos principal |
| postgres-exporter | 9187 | Exposición de métricas `/metrics` |
| Prometheus | 9090 | Recolección y almacenamiento de métricas |
| Alertmanager | 9093 | Gestión y enrutamiento de alertas |
| Loki | 3100 | Almacenamiento y búsqueda de logs |
| Promtail | 9080 | Agente de recolección de logs |
| Grafana | 3000 | Visualización, dashboards y alertas |

---

## 2. Requisitos Previos

- **Docker** ≥ 24.x y **Docker Compose** ≥ 2.x
- Al menos **4 GB RAM** disponible
- **10 GB disco** libre (para datos de Prometheus y Loki)
- Puertos `3000`, `9090`, `9093`, `3100`, `9187`, `5432` libres

```bash
# Verificar versiones
docker --version
docker compose version
```

---

## 3. Estructura del Proyecto

```
postgres-monitoring/
├── docker-compose.yml              # Stack principal
├── docker-compose.replica.yml      # Extensión: réplica PostgreSQL
├── .env                            # Variables de entorno (credenciales)
│
├── prometheus/
│   ├── prometheus.yml              # Configuración de scraping
│   ├── alertmanager.yml            # Enrutamiento de alertas
│   └── alerts/
│       ├── postgres_alerts.yml     # Reglas de alerta para PostgreSQL
│       └── system_alerts.yml       # Alertas de infraestructura
│
├── postgres-exporter/
│   ├── queries.yaml                # Consultas SQL personalizadas
│   └── init.sql                    # Setup inicial de PostgreSQL
│
├── loki/
│   └── loki-config.yml             # Configuración de Loki
│
├── promtail/
│   └── promtail-config.yml         # Pipeline de recolección de logs
│
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── datasources.yml     # Prometheus + Loki como datasources
    │   └── dashboards/
    │       └── dashboards.yml      # Aprovisionamiento automático
    └── dashboards/
        └── postgres-complete.json  # Dashboard personalizado completo
```

---

## 4. Inicio Rápido

### Paso 1: Clonar o descargar el proyecto

```bash
git clone <repo-url> postgres-monitoring
cd postgres-monitoring
```

### Paso 2: Configurar credenciales

```bash
# Editar .env con tus contraseñas
nano .env
```

```env
POSTGRES_USER=pguser
POSTGRES_PASSWORD=mi_contraseña_segura
POSTGRES_DB=appdb
GRAFANA_USER=admin
GRAFANA_PASSWORD=mi_contraseña_grafana
```

### Paso 3: Levantar el stack

```bash
docker compose up -d
```

### Paso 4: Verificar que todos los servicios están funcionando

```bash
docker compose ps
# Todos deberían aparecer como "healthy" o "running"


$ psql -h localhost -p 5432 -U pguser -d appdb
password:pgpassword

-- Listar bases de datos
\l

-- Listar tablas
\dt

-- Ver conexiones activas
SELECT pid, usename, state, left(query,60) FROM pg_stat_activity;

-- Ver configuración actual
SHOW all;

-- Salir
\q

```

### Paso 5: Acceder a los servicios

| Servicio | URL | Usuario | Contraseña |
|---|---|---|---|
| Grafana | http://localhost:3000 | admin | (del .env) |
| Prometheus | http://localhost:9090 | — | — |
| Alertmanager | http://localhost:9093 | — | — |
| PG Exporter | http://localhost:9187/metrics | — | — |

# Health check
curl http://localhost:3100/ready
# Debe devolver: ready

# Métricas propias de Loki
curl http://localhost:3100/metrics | head -20

# Ver labels disponibles (si ya hay logs ingested)
curl http://localhost:3100/loki/api/v1/labels

# Logs de los últimos 10 minutos
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="postgres"}' \
  --data-urlencode "start=$(date -d '10 minutes ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode 'limit=10' | python3 -m json.tool | head -60

# Solo errores de postgres
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="postgres", level="ERROR"}' \
  --data-urlencode "start=$(date -d '1 hour ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" | python3 -m json.tool

### Paso 6 (opcional): Levantar con réplica

```bash
docker compose -f docker-compose.yml -f docker-compose.replica.yml up -d
```

---

## 5. Métricas Esenciales

### CPU y Sistema

El exporter de PostgreSQL expone métricas de CPU a través de las estadísticas de `pg_stat_activity` y `pg_stat_bgwriter`. Para métricas de CPU del sistema operativo, se recomienda añadir **Node Exporter**:

```yaml
# Añadir a docker-compose.yml
node-exporter:
  image: prom/node-exporter:v1.8.0
  ports:
    - "9100:9100"
  volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
  command:
    - "--path.procfs=/host/proc"
    - "--path.sysfs=/host/sys"
  networks:
    - monitoring
```

Métricas de CPU/sistema:
```promql
# CPU de PostgreSQL (modo user + system del proceso)
rate(process_cpu_seconds_total{job="postgres-exporter"}[5m])

# Tiempo de CPU en background writer
rate(pg_stat_bgwriter_buffers_checkpoint[5m])
```

### Memoria

```promql
# Memoria del proceso exporter (proxy del proceso postgres)
process_resident_memory_bytes{job="postgres-exporter"}

# Buffers compartidos usados
pg_settings_shared_buffers_bytes

# Buffers sucios pendientes de escritura
pg_stat_bgwriter_buffers_clean + pg_stat_bgwriter_buffers_backend
```

### I/O

```promql
# Bloques leídos desde disco (I/O real)
rate(pg_stat_database_blks_read[5m])

# Bloques escritos por checkpoints
rate(pg_stat_bgwriter_buffers_checkpoint[5m])

# Escrituras por backend (costosas)
rate(pg_stat_bgwriter_buffers_backend[5m])

# Sincronizaciones de checkpoint
rate(pg_stat_bgwriter_checkpoints_req[5m])
rate(pg_stat_bgwriter_checkpoints_timed[5m])
```

### WAL

```promql
# Bytes WAL generados por segundo
rate(pg_wal_stats_wal_bytes[5m])

# Registros WAL por segundo
rate(pg_wal_stats_wal_records[5m])

# Full Page Images (indica mucha I/O aleatoria)
rate(pg_wal_stats_wal_fpi[5m])
```

### Replicación y Lag

```promql
# Lag de replicación en segundos
pg_replication_lag

# Lag en bytes (réplica específica)
pg_replication_lag_replay_lag_bytes

# WAL retenido por slots de replicación
pg_replication_slots_detail_retained_bytes
```

---

## 6. pg_stat_activity, pg_locks y Vistas de Diagnóstico

### pg_stat_activity

La vista `pg_stat_activity` muestra la actividad actual de todas las conexiones. Las métricas clave expuestas por el exporter son:

```promql
# Conexiones por estado (active, idle, idle in transaction...)
pg_stat_activity_count{state="active"}
pg_stat_activity_count{state="idle"}
pg_stat_activity_count{state="idle in transaction"}

# Duración máxima de transacción activa
pg_stat_activity_max_tx_duration{state="active"}

# Conexiones esperando un evento
pg_stat_activity_detail_count{wait_event_type="Lock"}
pg_stat_activity_detail_count{wait_event_type="IO"}
pg_stat_activity_detail_count{wait_event_type="Client"}
```

**Consulta SQL directa para diagnóstico:**

$ psql -h localhost -p 5432 -U pguser -d appdb
password:pgpassword

```sql
-- Ver conexiones activas con detalles
SELECT
  pid,
  usename,
  application_name,
  client_addr,
  state,
  wait_event_type,
  wait_event,
  query_start,
  EXTRACT(EPOCH FROM (now() - query_start)) AS duration_s,
  left(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid <> pg_backend_pid()
ORDER BY duration_s DESC NULLS LAST;
```

### pg_locks

```promql
# Total de bloqueos por modo
pg_locks_detail_count{mode="ExclusiveLock"}
pg_locks_detail_count{mode="ShareLock"}
pg_locks_detail_count{mode="RowExclusiveLock"}

# Bloqueos en espera (no concedidos)
pg_locks_detail_count{granted="false"}
```

**Consulta SQL para detectar deadlocks y cuellos de botella:**

```sql
-- Consultas bloqueadas y quién las bloquea
SELECT
  blocked.pid          AS blocked_pid,
  blocked.usename      AS blocked_user,
  blocking.pid         AS blocking_pid,
  blocking.usename     AS blocking_user,
  blocked.query        AS blocked_query,
  blocking.query       AS blocking_query,
  EXTRACT(EPOCH FROM (now() - blocked.query_start)) AS wait_seconds
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock'
ORDER BY wait_seconds DESC;
```

### Vistas de Diagnóstico Personalizadas

Las vistas creadas en `init.sql` están disponibles en la base de datos:

```sql
-- Consultas largas (más de 5 minutos)
SELECT * FROM monitoring.long_running_queries;

-- Ver quién bloquea a quién
SELECT * FROM monitoring.blocking_queries;
```

# Terminal 1 — lanza la carga (dura ~90s automáticamente)
./simular_carga.sh

# Terminal 2 — observa el diagnóstico en tiempo real
./diagnostico_postgres.sh --watch

# Watch con intervalo personalizado
./diagnostico_postgres.sh --watch --interval 10

# Terminal 1 — genera bloqueos
./simular_carga.sh

# Terminal 2 — ejecuta el análisis
psql -h localhost -U pguser -d appdb -f consulta_pg_locks.sql

---

## 7. Integración con Prometheus y PostgreSQL Exporter

### Cómo funciona el exporter

El **postgres_exporter** se conecta a PostgreSQL y:
1. Consulta las vistas del sistema (`pg_stat_*`)
2. Ejecuta las consultas personalizadas de `queries.yaml`
3. Expone todos los resultados como métricas en `/metrics` (formato Prometheus)

### Configurar el exporter para múltiples bases de datos

```yaml
# En docker-compose.yml
postgres-exporter:
  environment:
    DATA_SOURCE_NAME: >
      postgresql://user:pass@host:5432/db1?sslmode=disable,
      postgresql://user:pass@host:5432/db2?sslmode=disable
    PG_EXPORTER_AUTO_DISCOVER_DATABASES: "true"
```

### Verificar métricas disponibles

```bash
# Ver todas las métricas expuestas
curl -s http://localhost:9187/metrics | grep "^pg_" | head -50

# Verificar métricas de replicación
curl -s http://localhost:9187/metrics | grep "pg_replication"

# Verificar WAL
curl -s http://localhost:9187/metrics | grep "pg_wal"
```

### Consultas PromQL fundamentales

```promql
# ─── Disponibilidad ──────────────────────────────────────────────────────────
pg_up                                    # 1 = disponible, 0 = caído

# ─── Conexiones ──────────────────────────────────────────────────────────────
sum(pg_stat_activity_count) by (state)  # por estado
sum(pg_stat_activity_count) / on(instance) pg_settings_max_connections * 100
                                         # % de uso

# ─── Transacciones ───────────────────────────────────────────────────────────
rate(pg_stat_database_xact_commit[5m])  # commits/s
rate(pg_stat_database_xact_rollback[5m]) # rollbacks/s

# ─── Cache ───────────────────────────────────────────────────────────────────
rate(pg_stat_database_blks_hit[5m]) /
(rate(pg_stat_database_blks_hit[5m]) + rate(pg_stat_database_blks_read[5m]))
* 100                                    # hit ratio %

# ─── Tamaño ──────────────────────────────────────────────────────────────────
pg_database_size_bytes                   # tamaño por BD
```

---

## 8. Dashboards en Grafana

### Acceso a Grafana

1. Abrir `http://localhost:3000`
2. Login con las credenciales del `.env`
3. Los datasources (Prometheus y Loki) se aprovisionan automáticamente

### Dashboard personalizado incluido

El dashboard **PostgreSQL — Monitorización Completa** se carga automáticamente en la carpeta "PostgreSQL" y cubre todas las secciones de esta guía.

### Importar dashboards de la comunidad

En Grafana: **Dashboards → Import → Introducir ID**

| ID | Nombre | Descripción |
|---|---|---|
| **9628** | PostgreSQL Database | Dashboard estándar oficial |
| **24298** | PostgreSQL Monitoring | Dashboard avanzado con todas las métricas |
| **14114** | PostgreSQL Exporter | Métricas detalladas del exporter |
| **13659** | Loki Logs | Dashboard para visualización de logs |

---

## 9. Dashboard: PostgreSQL Database (ID 9628)

Este dashboard oficial cubre las métricas fundamentales de PostgreSQL. Para instalarlo:

```
Grafana → Dashboards → Import → ID: 9628 → Datasource: Prometheus → Import
```

### Paneles incluidos en este dashboard

| Panel | Métrica |
|---|---|
| Instance State | `pg_up` |
| Uptime | `time() - pg_postmaster_start_time_seconds` |
| Active Connections | `pg_stat_activity_count{state="active"}` |
| DB Size | `pg_database_size_bytes` |
| Cache Hit Rate | Ratio blks_hit / (blks_hit + blks_read) |
| Transactions/s | `rate(pg_stat_database_xact_commit[5m])` |
| Locks | `pg_locks_count` |
| Deadlocks | `pg_stat_database_deadlocks` |

---

## 10. Estado de la instancia

### Métricas de estado y configuración

```promql
# ─── Uptime (tiempo en segundos desde el inicio) ─────────────────────────────
time() - pg_postmaster_start_time_seconds{instance="postgres-primary:9187"}

# ─── Versión (aparece en etiquetas) ──────────────────────────────────────────
pg_static{instance="postgres-primary:9187"}
# La etiqueta "short_version" contiene la versión, p.ej. "16.2"

# ─── Configuraciones críticas ────────────────────────────────────────────────
pg_settings_max_connections
pg_settings_shared_buffers_bytes
pg_settings_effective_cache_size_bytes
pg_settings_work_mem_bytes
pg_settings_maintenance_work_mem_bytes
pg_settings_wal_buffers_bytes
```

### Verificar configuración desde SQL

```sql
-- Ver configuraciones en tiempo real
SELECT name, setting, unit, context, short_desc
FROM pg_settings
WHERE name IN (
  'max_connections',
  'shared_buffers',
  'effective_cache_size',
  'work_mem',
  'maintenance_work_mem',
  'wal_level',
  'max_wal_senders',
  'synchronous_commit',
  'checkpoint_completion_target',
  'max_wal_size',
  'random_page_cost',
  'effective_io_concurrency'
)
ORDER BY name;

             name             | setting | unit |  context   |                                        short_desc                                        
------------------------------+---------+------+------------+------------------------------------------------------------------------------------------
 checkpoint_completion_target | 0.9     |      | sighup     | Time spent flushing dirty buffers during checkpoint, as fraction of checkpoint interval.
 effective_cache_size         | 524288  | 8kB  | user       | Sets the planner's assumption about the total size of the data caches.
 effective_io_concurrency     | 1       |      | user       | Number of simultaneous requests that can be handled efficiently by the disk subsystem.
 maintenance_work_mem         | 65536   | kB   | user       | Sets the maximum memory to be used for maintenance operations.
 max_connections              | 100     |      | postmaster | Sets the maximum number of concurrent connections.
 max_wal_senders              | 5       |      | postmaster | Sets the maximum number of simultaneously running WAL sender processes.
 max_wal_size                 | 1024    | MB   | sighup     | Sets the WAL size that triggers a checkpoint.
 random_page_cost             | 4       |      | user       | Sets the planner's estimate of the cost of a nonsequentially fetched disk page.
 shared_buffers               | 16384   | 8kB  | postmaster | Sets the number of shared memory buffers used by the server.
 synchronous_commit           | on      |      | user       | Sets the current transaction's synchronization level.
 wal_level                    | replica |      | postmaster | Sets the level of information written to the WAL.
 work_mem                     | 4096    | kB   | user       | Sets the maximum memory to be used for query workspaces.

```

---

## 11. Conexiones

### Métricas de conexiones

```promql
# ─── Conexiones activas totales ───────────────────────────────────────────────
sum(pg_stat_activity_count{instance=~"$instance"})

# ─── Por estado ───────────────────────────────────────────────────────────────
sum(pg_stat_activity_count{state="active"})
sum(pg_stat_activity_count{state="idle"})
sum(pg_stat_activity_count{state="idle in transaction"})
sum(pg_stat_activity_count{state="idle in transaction (aborted)"})

# ─── Uso del límite máximo (%) ────────────────────────────────────────────────
sum(pg_stat_activity_count) / on(instance) pg_settings_max_connections * 100

# ─── Tasa de nuevas conexiones/s (usando commits como proxy) ─────────────────
º

# ─── Conexiones por aplicación ────────────────────────────────────────────────
pg_stat_activity_detail_count
```

### Alerta: Demasiadas conexiones "idle in transaction"

Las conexiones `idle in transaction` bloquean vacuums y consumen recursos. Monitorizar con:

```promql
# Alerta si hay más de 10 conexiones idle in transaction durante 5 minutos
pg_stat_activity_count{state="idle in transaction"} > 10
```

---

## 12. Uso de Recursos

### Tamaño de la base de datos en disco

```promql
# ─── Tamaño por base de datos (bytes) ────────────────────────────────────────
pg_database_size_bytes{datname="appdb"}

# ─── Tamaño total de todas las BDs ───────────────────────────────────────────
sum(pg_database_size_bytes)

# ─── Crecimiento en las últimas 24h ──────────────────────────────────────────
pg_database_size_bytes - pg_database_size_bytes offset 24h
```

### Operaciones de tuplas

```promql
# ─── INSERT por segundo ───────────────────────────────────────────────────────
sum(rate(pg_stat_database_tup_inserted{datname=~"$datname"}[5m]))

# ─── UPDATE por segundo ───────────────────────────────────────────────────────
sum(rate(pg_stat_database_tup_updated{datname=~"$datname"}[5m]))

# ─── DELETE por segundo ───────────────────────────────────────────────────────
sum(rate(pg_stat_database_tup_deleted{datname=~"$datname"}[5m]))

# ─── Consultas SELECT (fetch) ─────────────────────────────────────────────────
sum(rate(pg_stat_database_tup_fetched{datname=~"$datname"}[5m]))

# ─── Ratio de filas devueltas vs. buscadas (eficiencia de índices) ────────────
sum(rate(pg_stat_database_tup_fetched[5m])) /
sum(rate(pg_stat_database_tup_returned[5m])) * 100
```

**Consulta SQL equivalente:**

```sql
SELECT
  datname,
  tup_inserted,
  tup_updated,
  tup_deleted,
  tup_fetched,
  tup_returned,
  xact_commit,
  xact_rollback
FROM pg_stat_database
WHERE datname NOT IN ('template0', 'template1', 'postgres')
ORDER BY tup_inserted + tup_updated + tup_deleted DESC;
 datname | tup_inserted | tup_updated | tup_deleted | tup_fetched | tup_returned | xact_commit | xact_rollback 
---------+--------------+-------------+-------------+-------------+--------------+-------------+---------------
 appdb   |         4069 |          85 |         137 |      773839 |      2150913 |       19903 |             4
(1 row)

```

---

## 13. Dashboard: PostgreSQL Monitoring (ID 24298)

Este dashboard incluye paneles para las métricas más relevantes.

```
Grafana → Dashboards → Import → ID: 24298 → Datasource: Prometheus → Import
```

### Secciones principales del dashboard 24298

| Sección | Paneles |
|---|---|
| Overview | Uptime, versión, conexiones activas |
| Performance | TPS, latencia, cache hit ratio |
| Connections | Distribución por estado y aplicación |
| Database Size | Crecimiento en disco |
| Tuples | INSERT/UPDATE/DELETE rates |
| Locks & Deadlocks | Bloqueos activos y deadlocks |
| Replication | Lag de réplicas |
| Vacuum | Actividad de autovacuum y bloat |
| WAL | Volumen y rendimiento de WAL |

---

## 14. Análisis de bloqueos

### Métricas de locks

```promql
# ─── Total de bloqueos ────────────────────────────────────────────────────────
sum(pg_locks_detail_count)

# ─── Bloqueos exclusivos (los más problemáticos) ─────────────────────────────
pg_locks_detail_count{mode="ExclusiveLock"}
pg_locks_detail_count{mode="AccessExclusiveLock"}

# ─── Bloqueos en espera (no concedidos) ──────────────────────────────────────
pg_locks_detail_count{granted="false"}

# ─── Consultas bloqueadas actualmente ────────────────────────────────────────
pg_blocking_queries_blocked_count

# ─── Tiempo máximo esperando un bloqueo ──────────────────────────────────────
pg_blocking_queries_max_wait_seconds

# ─── Deadlocks por base de datos ─────────────────────────────────────────────
rate(pg_stat_database_deadlocks[5m])
```

### Consultas SQL para análisis de bloqueos

```sql
-- ① Ver árbol completo de bloqueos
WITH RECURSIVE lock_tree AS (
  SELECT
    pid,
    usename,
    pg_blocking_pids(pid) AS blocked_by,
    query,
    wait_event_type,
    wait_event,
    state
  FROM pg_stat_activity
  WHERE cardinality(pg_blocking_pids(pid)) > 0
)
SELECT
  pid,
  usename,
  blocked_by,
  state,
  wait_event_type || ': ' || COALESCE(wait_event, 'N/A') AS wait_info,
  left(query, 120) AS query
FROM lock_tree;

-- ② Ver objetos con bloqueos pendientes
SELECT
  locktype,
  relation::regclass AS table_name,
  mode,
  granted,
  pid,
  pg_stat_activity.usename,
  pg_stat_activity.query_start,
  left(pg_stat_activity.query, 80) AS query
FROM pg_locks
JOIN pg_stat_activity USING (pid)
WHERE NOT granted
ORDER BY pg_stat_activity.query_start;

-- ③ Matar consulta bloqueante (requiere superusuario)
-- SELECT pg_terminate_backend(<pid_bloqueante>);
```

---

## 15. Caché e I/O

### Buffer Cache Hit Ratio

Un valor por debajo del **90%** indica exceso de lecturas de disco.

```promql
# ─── Cache hit ratio global (%) ──────────────────────────────────────────────
(
  sum(rate(pg_stat_database_blks_hit[5m]))
  /
  (
    sum(rate(pg_stat_database_blks_hit[5m])) +
    sum(rate(pg_stat_database_blks_read[5m]))
  )
) * 100

# ─── Por base de datos ────────────────────────────────────────────────────────
rate(pg_stat_database_blks_hit{datname="appdb"}[5m]) /
(
  rate(pg_stat_database_blks_hit{datname="appdb"}[5m]) +
  rate(pg_stat_database_blks_read{datname="appdb"}[5m])
) * 100

# ─── Bloques escritos por checkpoints (I/O planificado) ──────────────────────
rate(pg_stat_bgwriter_buffers_checkpoint[5m])

# ─── Bloques escritos por backends (I/O de emergencia, malo) ─────────────────
rate(pg_stat_bgwriter_buffers_backend[5m])

# ─── Ratio buffers backend vs checkpoint (>0.1 es preocupante) ───────────────
rate(pg_stat_bgwriter_buffers_backend[5m]) /
(rate(pg_stat_bgwriter_buffers_checkpoint[5m]) + 0.001)
```

### Shared Buffers

> **Nota:** Para la consulta de `pg_buffercache` necesitas instalar la extensión:
> ```sql
> CREATE EXTENSION pg_buffercache;
> ```

```sql
-- Verificar uso actual de shared_buffers
SELECT
  count(*) * 8192 AS total_buffer_bytes,
  pg_size_pretty(count(*) * 8192) AS total_buffer_size
FROM pg_buffercache;

-- Top tablas en caché
SELECT
  c.relname,
  count(*) AS buffer_count,
  count(*) * 8192 AS buffer_bytes,
  pg_size_pretty(count(*) * 8192) AS buffer_size
FROM pg_buffercache b
JOIN pg_class c ON c.relfilenode = b.relfilenode
GROUP BY c.relname
ORDER BY buffer_count DESC
LIMIT 20;
```

---

## 16. Mantenimiento y Autovacuum

### Métricas de autovacuum y bloat

```promql
# ─── Tabla con mayor bloat (ratio tuplas muertas) ────────────────────────────
topk(10, pg_autovacuum_activity_dead_tup_ratio)

# ─── Tablas con más de 10k tuplas muertas ────────────────────────────────────
pg_autovacuum_activity_n_dead_tup > 10000

# ─── Tiempo desde el último autovacuum ───────────────────────────────────────
pg_autovacuum_activity_seconds_since_autovacuum > 86400  # > 24h

# ─── Tasa de autovacuum por segundo ──────────────────────────────────────────
rate(pg_stat_user_tables_autovacuum_count[5m])

# ─── Tasa de autoanalyze ─────────────────────────────────────────────────────
rate(pg_stat_user_tables_autoanalyze_count[5m])
```

### Consultas SQL para análisis de bloat

```sql
-- ① Tablas más necesitadas de vacuum
SELECT
  schemaname || '.' || relname AS table_name,
  n_dead_tup,
  n_live_tup,
  ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_ratio_pct,
  last_autovacuum,
  last_autoanalyze,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_ratio_pct DESC NULLS LAST
LIMIT 20;

-- ② Autovacuums activos ahora mismo
SELECT
  pid,
  usename,
  application_name,
  EXTRACT(EPOCH FROM (now() - query_start)) AS runtime_s,
  left(query, 100) AS query
FROM pg_stat_activity
WHERE query LIKE '%autovacuum%'
ORDER BY runtime_s DESC;

-- ③ Forzar vacuum en una tabla específica (mantenimiento manual)
-- VACUUM ANALYZE schema.tablename;
-- VACUUM FULL schema.tablename;  -- bloquea la tabla, usar con precaución
```

---

## 17. Replicación

### Levantar el stack con réplica

```bash
# Iniciar con réplica de prueba
docker compose -f docker-compose.yml -f docker-compose.replica.yml up -d

# El exporter de la réplica estará en :9188
curl http://localhost:9188/metrics | grep pg_replication
```

### Configurar replicación (primario)

```sql
-- En el primario: verificar configuración
SHOW wal_level;       -- debe ser "replica" o "logical"
SHOW max_wal_senders; -- debe ser > 0
SHOW hot_standby;     -- "on" para réplicas de lectura

-- Ver réplicas conectadas
SELECT
  client_addr,
  application_name,
  state,
  sync_state,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;
```

### Métricas de replicación

```promql
# ─── Lag total en segundos (réplica) ─────────────────────────────────────────
pg_replication_lag{instance=~"$instance"}

# ─── Lag de replay en bytes ───────────────────────────────────────────────────
pg_replication_lag_replay_lag_bytes

# ─── Estado de sincronización ─────────────────────────────────────────────────
# La etiqueta sync_state puede ser: async, sync, quorum, potential
pg_replication_lag_replay_lag_seconds

# ─── Bytes WAL retenidos por slots (riesgo de disco lleno) ───────────────────
pg_replication_slots_detail_retained_bytes

# ─── Slots activos vs. inactivos ─────────────────────────────────────────────
pg_replication_slots_active
```



### Añadir réplica al scraping de Prometheus

```yaml
# En prometheus/prometheus.yml, añadir target:
- job_name: "postgres-exporter-replica"
  static_configs:
    - targets: ["postgres-exporter-replica:9187"]
      labels:
        instance: "postgres-replica"
        db_role: "replica"
```

---

## 18. WAL (Write-Ahead Log)

### Métricas WAL

```promql
# ─── Bytes WAL generados por segundo ─────────────────────────────────────────
rate(pg_wal_stats_wal_bytes[5m])

# ─── Registros WAL por segundo ───────────────────────────────────────────────
rate(pg_wal_stats_wal_records[5m])

# ─── Full Page Images por segundo ────────────────────────────────────────────
rate(pg_wal_stats_wal_fpi[5m])

# ─── FPI ratio (FPI/total records) — alto indica mucha I/O aleatoria ─────────
rate(pg_wal_stats_wal_fpi[5m]) /
(rate(pg_wal_stats_wal_records[5m]) + 0.001) * 100

# ─── Buffer WAL lleno (presión) ───────────────────────────────────────────────
rate(pg_wal_stats_wal_buffers_full[5m])

# ─── Tiempo de escritura WAL (ms/s) ──────────────────────────────────────────
rate(pg_wal_stats_wal_write_time[5m])

# ─── Tiempo de sync WAL ───────────────────────────────────────────────────────
rate(pg_wal_stats_wal_sync_time[5m])
```

### Consultas SQL de diagnóstico WAL

```sql
-- ① Estado actual de WAL
SELECT
  wal_records,
  wal_fpi,
  pg_size_pretty(wal_bytes) AS wal_size,
  wal_buffers_full,
  wal_write,
  wal_sync,
  wal_write_time AS write_ms,
  wal_sync_time  AS sync_ms
FROM pg_stat_wal;

-- ② Posición actual del WAL
SELECT
  pg_current_wal_lsn() AS current_lsn,
  pg_walfile_name(pg_current_wal_lsn()) AS current_wal_file,
  pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') AS total_wal_bytes;

-- ③ Archivado WAL
SELECT
  archived_count,
  last_archived_wal,
  last_archived_time,
  failed_count,
  last_failed_wal
FROM pg_stat_archiver;
```

### Optimización WAL

```sql
-- Parámetros clave a monitorizar (también disponibles como métricas)
SHOW wal_buffers;               -- Tamaño del buffer WAL (recomendado: 64MB)
SHOW checkpoint_completion_target; -- Debe ser 0.9
SHOW max_wal_size;              -- Tamaño máximo WAL antes de checkpoint
SHOW min_wal_size;              -- Tamaño mínimo WAL
SHOW synchronous_commit;        -- on/off/local/remote_apply/remote_write
```

---

## 19. Loki: Agregación de Logs

### Configuración del pipeline de logs

Promtail recoge logs de:
- **Logs de PostgreSQL** en `/var/log/postgresql/*.log`
- **Contenedores Docker** via Docker socket
- **Logs del sistema** en `/var/log/syslog`

### Consultas LogQL en Grafana/Loki

```logql
# ─── Ver todos los logs de PostgreSQL ────────────────────────────────────────
{job="postgres"}

# ─── Solo errores y fatales ───────────────────────────────────────────────────
{job="postgres", level=~"ERROR|FATAL|PANIC"}

# ─── Logs que contienen "lock" ────────────────────────────────────────────────
{job="postgres"} |= "lock"

# ─── Consultas lentas (slow queries) ─────────────────────────────────────────
{job="postgres"} |= "duration:"

# ─── Conexiones nuevas ────────────────────────────────────────────────────────
{job="postgres"} |= "connection received"

# ─── Deadlocks ────────────────────────────────────────────────────────────────
{job="postgres"} |= "deadlock detected"

# ─── Replicación ─────────────────────────────────────────────────────────────
{job="postgres"} |= "replication"

# ─── Tasa de errores por minuto (métrica derivada de logs) ───────────────────
sum(rate({job="postgres", level="ERROR"}[1m]))

# ─── Logs de un proceso específico ───────────────────────────────────────────
{job="postgres", pid="12345"}

# ─── Logs de una base de datos específica ────────────────────────────────────
{job="postgres", database="appdb"}
```

### Panel de Logs en Grafana

En el dashboard incluido hay paneles de logs con:
- **Panel tipo "Logs"** — visualización de líneas de log con coloreado por nivel
- **Panel tipo "Time Series"** — tasa de logs por nivel (ERROR, WARNING, LOG)
- **Búsqueda** de patrones específicos (deadlocks, lock waits)

### Configurar alertas basadas en logs (Loki Rules)

Crear el archivo `/loki/rules/postgres-rules.yml`:

```yaml
groups:
  - name: postgres_log_alerts
    rules:
      - alert: PostgresDeadlockInLogs
        expr: |
          sum(rate({job="postgres"} |= "deadlock detected" [5m])) > 0
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "Deadlock detectado en logs de PostgreSQL"

      - alert: PostgresFatalErrorInLogs
        expr: |
          sum(rate({job="postgres", level="FATAL"} [5m])) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Error FATAL en PostgreSQL"
```

### Métricas derivadas de logs en Prometheus

Loki puede exportar métricas derivadas de los logs hacia Prometheus usando **Loki Recording Rules**. Para habilitarlo, verificar que Loki tiene el ruler configurado (ya incluido en `loki-config.yml`).

---

## 20. Alertas

Las alertas definidas en `prometheus/alerts/postgres_alerts.yml` cubren:

| Alerta | Condición | Severidad |
|---|---|---|
| `PostgresDown` | `pg_up == 0` por 1 min | 🔴 critical |
| `PostgresRestarted` | Uptime < 60s | 🟡 warning |
| `PostgresTooManyConnections` | Uso > 80% | 🟡 warning |
| `PostgresConnectionsExhausted` | Uso > 95% | 🔴 critical |
| `PostgresLowCacheHitRatio` | Hit ratio < 90% | 🟡 warning |
| `PostgresDeadlocks` | Tasa deadlocks > 0 | 🟡 warning |
| `PostgresLongRunningQuery` | Consulta activa > 5 min | 🟡 warning |
| `PostgresLocksWaiting` | Locks en espera > 5 | 🟡 warning |
| `PostgresReplicationLagHigh` | Lag > 5 min | 🟡 warning |
| `PostgresReplicationLagCritical` | Lag > 15 min | 🔴 critical |
| `PostgresReplicationSlotInactive` | Slot inactivo | 🟡 warning |
| `PostgresWALBuffersFull` | Buffer WAL lleno | 🟡 warning |
| `PostgresTableBloatHigh` | Bloat > 20% | 🟡 warning |
| `PostgresAutovacuumNotRunning` | Sin vacuum > 24h | 🟡 warning |

### Verificar alertas activas

```bash
# En Prometheus UI (http://localhost:9090/alerts)
# O via API:
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[]'
```

---

## 21. Troubleshooting

### ❌ FATAL: could not open log file — PostgreSQL no arranca

Este error ocurre cuando `logging_collector=on` apunta a un directorio inexistente en Alpine.
La config corregida usa `logging_collector=off`: los logs van a `stderr` y Docker los captura.

Si el volumen ya tiene datos corruptos ("Skipping initialization"):

```bash
# 1. Parar contenedores
docker compose down

# 2. Eliminar el volumen de PostgreSQL (⚠️ borra datos)
docker volume rm postgres-monitoring_postgres_data

# 3. Verificar la corrección en docker-compose.yml
grep "logging_collector" docker-compose.yml
# Debe mostrar: -c logging_collector=off

# 4. Levantar de nuevo
docker compose up -d

# 5. Confirmar arranque correcto
docker compose logs -f postgres
# Debe mostrar: "database system is ready to accept connections"
```

---



### El exporter no se conecta a PostgreSQL

```bash
# Ver logs del exporter
docker compose logs postgres-exporter

# Verificar que PostgreSQL está accesible
docker compose exec postgres-exporter \
  psql "postgresql://pguser:pgpassword@postgres:5432/appdb?sslmode=disable" \
  -c "SELECT version();"

# Verificar variables de entorno
docker compose exec postgres-exporter env | grep DATA_SOURCE
```

### Prometheus no recibe métricas

```bash
# Ver targets activos
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health, lastError}'

# Verificar manualmente el endpoint
curl -s http://localhost:9187/metrics | grep "pg_up"

# Recargar configuración de Prometheus sin reiniciar
curl -X POST http://localhost:9090/-/reload
```

### Grafana no muestra datos

```bash
# Verificar datasources
curl -s -u admin:admin123 http://localhost:3000/api/datasources

# Probar datasource Prometheus
curl -s -u admin:admin123 \
  "http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=pg_up"
```

### Loki no recibe logs

```bash
# Ver logs de Promtail
docker compose logs promtail

# Verificar que Loki está accesible desde Promtail
docker compose exec promtail \
  wget -qO- http://loki:3100/ready

# Ver streams disponibles en Loki
curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.'
```

### Liberar espacio en disco

```bash
# Ver uso de volúmenes
docker system df -v

# Reducir retención de Prometheus (en prometheus.yml)
# --storage.tsdb.retention.time=7d

# Limpiar datos (destructivo)
docker compose down -v  # elimina todos los datos
```

---

## 📚 Referencias

- [PostgreSQL Exporter](https://github.com/prometheus-community/postgres_exporter)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [Loki Docs](https://grafana.com/docs/loki/)
- [Dashboard 9628](https://grafana.com/grafana/dashboards/9628)
- [Dashboard 24298](https://grafana.com/grafana/dashboards/24298)
- [PostgreSQL pg_stat_* Views](https://www.postgresql.org/docs/current/monitoring-stats.html)

