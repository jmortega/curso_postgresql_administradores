# Caso de estudio: Dimensionado de PostgreSQL 16 para un nodo con 32 GB de RAM

> Basado en el entorno de laboratorio de Sesión 2:
> PostgreSQL 16 + pgvector + PostGIS + pg_stat_statements + pg_wait_sampling
> corriendo en Docker con la imagen `pg-sesion2:16`.

---

## Índice

1. [Contexto del nodo](#1-contexto-del-nodo)
2. [Principios de dimensionado de memoria](#2-principios-de-dimensionado-de-memoria)
3. [Configuración actual del laboratorio vs. nodo de 32 GB](#3-configuración-actual-vs-nodo-32-gb)
4. [postgresql.conf dimensionado para 32 GB](#4-postgresqlconf-dimensionado-para-32-gb)
5. [Aplicar la nueva configuración en Docker](#5-aplicar-la-nueva-configuración-en-docker)
6. [pg_config — qué es y para qué sirve](#6-pg_config--qué-es-y-para-qué-sirve)
7. [Pruebas con pg_config](#7-pruebas-con-pg_config)
8. [Verificar el dimensionado en PostgreSQL](#8-verificar-el-dimensionado-en-postgresql)
9. [Pruebas de carga con pgbench](#9-pruebas-de-carga-con-pgbench)
10. [Checklist de validación](#10-checklist-de-validación)

---

## 1. Contexto del nodo

| Parámetro | Valor |
|---|---|
| RAM total del nodo | 32 GB |
| PostgreSQL | 16 (imagen `postgres:16-bookworm`) |
| Extensiones con preload | `pg_stat_statements`, `pg_wait_sampling` |
| Extensiones bajo demanda | `pgvector`, `PostGIS` |
| Carga esperada | OLTP + consultas analíticas mixtas |
| Máximo de conexiones | 200 conexiones concurrentes |

### Distribución de memoria recomendada para 32 GB

```
32 GB totales
├── Sistema operativo + procesos del SO          ~  2 GB  (6%)
├── shared_buffers (caché compartida de PG)      ~  8 GB  (25%)
├── Reserva para work_mem × conexiones activas   ~  8 GB
│   └── work_mem = 40 MB × 200 conexiones
├── effective_cache_size (estimación OS + PG)    ~ 20 GB
└── maintenance_work_mem + autovacuum workers    ~  1 GB
```

> La regla clásica es asignar el **25% de la RAM a `shared_buffers`** en servidores
> dedicados a PostgreSQL. El resto lo gestiona el sistema operativo como caché de
> página (page cache), que PostgreSQL también aprovecha a través de `effective_cache_size`.

---

## 2. Principios de dimensionado de memoria

### shared_buffers

Es la caché compartida interna de PostgreSQL. Todas las conexiones comparten este pool
de páginas (bloques de 8 KB) en memoria.

- **Mínimo recomendado:** 128 MB
- **Regla general:** 25% de la RAM en servidores dedicados
- **Para 32 GB:** 8 GB

Un valor demasiado alto puede ser contraproducente: PostgreSQL compite con la caché
del sistema operativo. En Linux, la caché de página del SO también almacena páginas
de PostgreSQL, por lo que superar el 40% rara vez aporta beneficio.

### work_mem

Memoria que puede usar **cada operación de ordenación o hash** (no cada conexión).
Una conexión puede ejecutar varias operaciones simultáneamente.

```
Memoria máxima consumible = max_connections × max_parallel_workers_per_gather × work_mem
```

- **Para 200 conexiones y work_mem = 40 MB:**
  `200 × 2 × 40 MB = 16 GB` (escenario extremo, raramente se alcanza)
- **Valor óptimo para 32 GB:** 32–64 MB

### effective_cache_size

Solo es una **pista para el planificador** — no reserva memoria real. Indica cuánta
memoria total (RAM + caché del SO) estima el planificador disponible. Afecta a la
decisión de usar index scan vs seq scan.

- **Regla:** 50–75% de la RAM total
- **Para 32 GB:** 20–24 GB

### maintenance_work_mem

Memoria para operaciones de mantenimiento: `VACUUM`, `CREATE INDEX`, `ALTER TABLE`.

- **Para 32 GB:** 512 MB – 2 GB (cuanto más, más rápido el vacuuming y la creación de índices)

---

## 3. Configuración actual vs. nodo de 32 GB

| Parámetro | Lab actual (Docker) | Nodo 32 GB |
|---|---|---|
| `max_connections` | 100 | 200 |
| `shared_buffers` | 256 MB | 8 GB |
| `work_mem` | 8 MB | 40 MB |
| `maintenance_work_mem` | 64 MB | 1 GB |
| `effective_cache_size` | 512 MB | 20 GB |
| `wal_keep_size` | 128 MB | 512 MB |
| `max_wal_senders` | 5 | 5 |
| `checkpoint_completion_target` | (defecto 0.9) | 0.9 |
| `default_statistics_target` | (defecto 100) | 200 |

---

## 4. postgresql.conf dimensionado para 32 GB

```ini
# =============================================================
# postgresql.conf — Nodo producción 32 GB RAM
# PostgreSQL 16 + pgvector + PostGIS + pg_stat_statements
#                          + pg_wait_sampling
# =============================================================

# ── Conexiones ────────────────────────────────────────────────
listen_addresses            = '*'
port                        = 5432
max_connections             = 200

# ── Memoria ───────────────────────────────────────────────────
# 25% de 32 GB = 8 GB para caché compartida
shared_buffers              = 8GB

# 40 MB por operación — razonable para 200 conexiones (OLTP mixto)
work_mem                    = 40MB

# Vacuuming e índices — 1 GB permite crear índices grandes en segundos
maintenance_work_mem        = 1GB

# Pista al planificador: SO + shared_buffers ≈ 20 GB disponibles
effective_cache_size        = 20GB

# ── Paralelismo ───────────────────────────────────────────────
max_worker_processes        = 8
max_parallel_workers        = 8
max_parallel_workers_per_gather = 4
max_parallel_maintenance_workers = 4

# ── Extensiones con preload obligatorio ───────────────────────
shared_preload_libraries    = 'pg_stat_statements,pg_wait_sampling'

# ── pg_stat_statements ────────────────────────────────────────
pg_stat_statements.track            = all
pg_stat_statements.track_utility    = on
pg_stat_statements.max              = 10000

# ── pg_wait_sampling ──────────────────────────────────────────
pg_wait_sampling.history_size       = 5000
pg_wait_sampling.profile_period     = 10

# ── WAL y checkpoint ─────────────────────────────────────────
wal_level                   = replica
max_wal_senders             = 5
wal_keep_size               = 512MB
checkpoint_completion_target = 0.9
wal_buffers                 = 64MB
min_wal_size                = 1GB
max_wal_size                = 4GB

# ── Planificador ─────────────────────────────────────────────
# Más muestras por columna = mejores estimaciones de cardinalidad
default_statistics_target   = 200
random_page_cost            = 1.1      # SSD: bajar de 4.0 (HDD) a 1.1
effective_io_concurrency    = 200      # SSD: número de lecturas paralelas

# ── Autovacuum ────────────────────────────────────────────────
autovacuum                  = on
autovacuum_max_workers      = 5
autovacuum_vacuum_cost_delay = 2ms

# ── Logging ───────────────────────────────────────────────────
log_destination             = 'stderr'
logging_collector           = off
log_min_duration_statement  = 500      # consultas lentas > 500 ms
log_connections             = on
log_disconnections          = on
log_lock_waits              = on
log_line_prefix             = '%t [%p] %q%u@%d '

# ── Autenticación ─────────────────────────────────────────────
hba_file                    = '/etc/postgresql/pg_hba.conf'
```

---

## 5. Aplicar la nueva configuración en Docker

Reemplaza `./configs/postgresql.conf` con el contenido anterior y recrea
el contenedor (imprescindible cuando se cambia `shared_buffers` u otras opciones de
`shared_preload_libraries`, que requieren reinicio del proceso):

```bash
# 1. Editar el fichero de configuración
nano ./configs/postgresql.conf

# 2. Destruir el contenedor actual y recrearlo con la nueva config
docker compose down
docker compose up --build -d

# 3. Verificar que arrancó correctamente
docker logs pg-sesion2 --tail 20

# 4. Confirmar que los parámetros se aplicaron
docker exec pg-sesion2 psql -U postgres -c "
SELECT name, setting, unit
FROM pg_settings
WHERE name IN (
    'shared_buffers', 'work_mem', 'effective_cache_size',
    'maintenance_work_mem', 'max_connections',
    'shared_preload_libraries'
)
ORDER BY name;"

# 5. Obtener medidas en GB
docker exec pg-sesion2 psql -U postgres -c "
SELECT
    name,
    CASE unit
        WHEN '8kB' THEN round(setting::numeric * 8 / (1024 * 1024), 2)
        WHEN 'kB'  THEN round(setting::numeric / (1024 * 1024), 2)
        ELSE setting::numeric
    END AS valor_gb,
    CASE unit
        WHEN '8kB' THEN 'GB'
        WHEN 'kB'  THEN 'GB'
        ELSE unit
    END AS unidad
FROM pg_settings
WHERE name IN (
    'shared_buffers', 'work_mem', 'effective_cache_size',
    'maintenance_work_mem', 'max_connections'
)
ORDER BY name;"

# 6. Obtener medidas en GB
docker exec pg-sesion2 psql -U postgres -c "
SELECT
    name,
    pg_size_pretty(
        CASE unit
            WHEN '8kB' THEN setting::bigint * 8 * 1024
            WHEN 'kB'  THEN setting::bigint * 1024
            ELSE setting::bigint
        END
    ) AS valor_legible
FROM pg_settings
WHERE name IN (
    'shared_buffers', 'work_mem', 'effective_cache_size',
    'maintenance_work_mem', 'max_connections'
)
ORDER BY name;"

```

Para parámetros que **no** requieren reinicio (`work_mem`, `log_min_duration_statement`, etc.),
basta con recargar sin reiniciar:

```bash
docker exec pg-sesion2 psql -U postgres -c "SELECT pg_reload_conf();"
```

Para saber si un parámetro requiere reinicio o solo reload:

```bash
docker exec pg-sesion2 psql -U postgres -c "
SELECT name, context
FROM pg_settings
WHERE context IN ('postmaster','sighup')
ORDER BY context, name;"
# context = postmaster → requiere reinicio del proceso
# context = sighup     → basta con pg_reload_conf()
```

---

## 6. pg_config — qué es y para qué sirve

`pg_config` es una utilidad de línea de comandos que se instala junto con PostgreSQL
(paquete `postgresql-server-dev-16` en Debian/Ubuntu, o incluido en la imagen Docker).
Expone las **variables de compilación, rutas de instalación y dependencias** del motor
instalado en ese nodo.

Se usa principalmente para:

- Compilar extensiones de terceros que necesitan saber dónde está PostgreSQL instalado.
- Auditar la configuración de compilación de un nodo en producción.
- Verificar la versión exacta, los flags del compilador y las rutas de librerías.
- Integrar PostgreSQL en pipelines de build y scripts de automatización.

### Acceso a pg_config desde el contenedor

```bash
# Verificar que está disponible
docker exec pg-sesion2 pg_config --version

# O directamente en el host si tienes el cliente PG instalado
pg_config --version
```

---

## 7. Pruebas con pg_config

### 7.1 Información básica de instalación

```bash
# Ruta del binario postgres
docker exec pg-sesion2 pg_config --bindir

# Ruta de las librerías compartidas
docker exec pg-sesion2 pg_config --libdir

# Ruta de los ficheros de extensión (.control, .sql)
docker exec pg-sesion2 pg_config --sharedir

# Directorio de cabeceras (para compilar extensiones en C)
docker exec pg-sesion2 pg_config --includedir

# Versión exacta de PostgreSQL compilada
docker exec pg-sesion2 pg_config --version
```

### 7.2 Flags de compilación y dependencias

```bash
# Flags del compilador C usados al compilar PostgreSQL
docker exec pg-sesion2 pg_config --cflags

# Flags del linker
docker exec pg-sesion2 pg_config --ldflags

# Librerías con las que fue compilado (OpenSSL, readline, zlib, etc.)
docker exec pg-sesion2 pg_config --libs

# Opciones de configuración pasadas a ./configure al compilar
docker exec pg-sesion2 pg_config --configure
```

### 7.3 Volcar toda la información de una vez

```bash
# Todas las variables de pg_config
docker exec pg-sesion2 pg_config

# Guardar la salida para auditoría
docker exec pg-sesion2 pg_config > pg_config_audit_$(date +%Y%m%d).txt
cat pg_config_audit_$(date +%Y%m%d).txt
```

### 7.4 Verificar soporte de características

```bash
# Comprobar si fue compilado con soporte SSL (debe aparecer --with-openssl)
docker exec pg-sesion2 pg_config --configure | grep -o '\-\-with-openssl'

# Comprobar soporte de systemd
docker exec pg-sesion2 pg_config --configure | grep -o '\-\-with-systemd'

# Comprobar versión de OpenSSL enlazada
docker exec pg-sesion2 pg_config --libs | grep -o 'ssl[^ ]*'
```

Dentro del contenedor la extensión ya está instalada vía apt, pero este patrón es
útil en nodos bare-metal donde se compilan extensiones manualmente.

---

## 8. Verificar el dimensionado en PostgreSQL

Una vez aplicada la configuración, ejecuta estas consultas para confirmar que los
parámetros de memoria se aplicaron correctamente:

```bash
# Ver todos los parámetros clave con su fuente
docker exec pg-sesion2 psql -U postgres -c "
SELECT
    name,
    setting,
    unit,
    source,
    pending_restart
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'effective_cache_size',
    'max_connections',
    'max_parallel_workers',
    'checkpoint_completion_target',
    'default_statistics_target',
    'random_page_cost',
    'wal_buffers',
    'max_wal_size'
)
ORDER BY name;"

# Parámetros pendientes de reinicio (pending_restart = true)
docker exec pg-sesion2 psql -U postgres -c "
SELECT name, setting, pending_restart
FROM pg_settings
WHERE pending_restart = true;"

# Verificar que shared_preload_libraries cargó las extensiones
docker exec pg-sesion2 psql -U postgres -c "
SELECT extname, extversion
FROM pg_extension
ORDER BY extname;"

# Calcular shared_buffers en bytes para confirmar
docker exec pg-sesion2 psql -U postgres -c "
SELECT
    name,
    setting::numeric * 8192 / (1024^3) AS valor_gb
FROM pg_settings
WHERE name = 'shared_buffers';"
```

---

## 9. Pruebas de carga con pgbench

`pgbench` es la herramienta de benchmarking incluida con PostgreSQL. Permite medir
el rendimiento con la nueva configuración.

```bash
# Crear la BD de benchmark dentro del contenedor
docker exec pg-sesion2 createdb -U postgres pgbench_test

# Inicializar con factor de escala 100 (≈ 1.5 GB de datos)
# scale=100 → ~100M filas en pgbench_accounts, equivale a ~100k cuentas × 1000
docker exec pg-sesion2 pgbench -U postgres -d pgbench_test \
    -i --scale=100 --foreign-keys

# Benchmark de escritura OLTP — 60 segundos, 50 clientes, 4 hilos, actualizando el progreso cada 10 segundos
docker exec pg-sesion2 pgbench -U postgres -d pgbench_test \
    -c 50 -j 4 -T 60 -P 10 \
    --report-per-command

# Benchmark de solo lectura — 60 segundos, 50 clientes
docker exec pg-sesion2 pgbench -U postgres -d pgbench_test \
    -c 50 -j 4 -T 60 -S \
    --report-per-command

# Ver estadísticas de caché tras el benchmark
docker exec pg-sesion2 psql -U postgres -d pgbench_test -c "
SELECT
    datname,
    blks_hit,
    blks_read,
    round(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    xact_commit,
    xact_rollback,
    deadlocks
FROM pg_stat_database
WHERE datname = 'pgbench_test';"

blks_hit
Número de veces que PostgreSQL necesitó un bloque (página de 8 KB) y lo encontró ya en shared_buffers (caché en RAM). No hubo que ir al disco. Cuanto más alto, mejor.

blks_read
Número de veces que el bloque no estaba en caché y hubo que leerlo desde disco (o desde la caché del sistema operativo, que también cuenta aquí como "lectura")

cache_hit_pct
El ratio resultante: de cada 100 accesos a bloques, 96,69 se resolvieron desde memoria cache y 3,31 fueron a disco.Por debajo del 90% habría que plantearse aumentar shared_buffers.

xact_commit
Transacciones que terminaron con COMMIT exitoso desde que se inició la BD o se hizo el último pg_stat_reset(). En el contexto del benchmark pgbench, cada transacción TPC-B cuenta aquí. Este número dividido entre la duración del benchmark da el TPS real.

xact_rollback
Transacciones que terminaron con ROLLBACK. Solo 2 en más de 1,5 millones es prácticamente cero — indica que no hubo errores ni cancelaciones significativas durante el benchmark.

deadlocks
Número de deadlocks detectados. PostgreSQL detecta automáticamente los ciclos de bloqueo entre transacciones y aborta una de ellas. Cero deadlocks en un benchmark OLTP es el resultado esperado y correcto — confirma que no hay problemas en el acceso a filas entre conexiones concurrentes.

```

**Métricas a interpretar:**

| Métrica | Buena señal | Señal de alerta |
|---|---|---|
| TPS (transacciones/seg) | Estable o creciente | Cae con más clientes |
| `cache_hit_pct` | > 95% | < 90% → `shared_buffers` insuficiente |
| Latencia media | < 10 ms (OLTP) | > 50 ms → buscar cuellos de botella |
| `deadlocks` | 0 | > 0 → revisar orden de bloqueos en la app |

---

## 10. Checklist de validación

```bash
# ── 1. pg_config reporta la versión correcta ─────────────────
docker exec pg-sesion2 pg_config --version
# Esperado: PostgreSQL 16.x

# ── 2. shared_buffers aplicado ────────────────────────────────
docker exec pg-sesion2 psql -U postgres \
    -At -c "SHOW shared_buffers;"
# Esperado: 8GB

# ── 3. Extensiones con preload activas ────────────────────────
docker exec pg-sesion2 psql -U postgres \
    -At -c "SHOW shared_preload_libraries;"
# Esperado: pg_stat_statements,pg_wait_sampling

# ── 4. pg_stat_statements operativa ──────────────────────────
docker exec pg-sesion2 psql -U postgres \
    -At -c "SELECT count(*) FROM pg_stat_statements;"
# Esperado: número > 0

# ── 5. Sin parámetros pendientes de reinicio ──────────────────
docker exec pg-sesion2 psql -U postgres \
    -At -c "SELECT count(*) FROM pg_settings WHERE pending_restart = true;"
# Esperado: 0

# ── 6. Conexiones bajo el límite ─────────────────────────────
docker exec pg-sesion2 psql -U postgres -c "
SELECT count(*) AS activas, max_conn
FROM pg_stat_activity,
     (SELECT setting::int AS max_conn FROM pg_settings WHERE name = 'max_connections') mc
GROUP BY max_conn;"

# ── 7. SSL compilado ─────────────────────────────────────────
docker exec pg-sesion2 pg_config --configure | grep -c 'with-openssl'
# Esperado: 1

# ── 8. Rutas de instalación coherentes ───────────────────────
docker exec pg-sesion2 pg_config --bindir
docker exec pg-sesion2 pg_config --sharedir
docker exec pg-sesion2 pg_config --pkglibdir
```
