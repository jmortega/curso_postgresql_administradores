# 🛠️ Lab: Mantenimiento, Automatización y Sondas de Vida — Docker

> Un único contenedor **PostgreSQL 16 + pg_cron**.
> Ningún comando se lanza en la máquina local: todo usa `docker exec`.

---

## 🗂️ Estructura del proyecto

```
pg-mant-lab/
├── Dockerfile                          # PG 16 + pg_cron + rsync + bc
├── docker-compose.yml
│
├── configs/
│   ├── postgresql.conf                 # pg_cron, WAL archiving, logging, autovacuum
│   └── pg_hba.conf
│
├── scripts/
│   ├── entrypoint.sh                   # Arranque + init_lab.sql
│   ├── init_lab.sql                    # pg_cron, tabla pedidos (100k) con bloat
│   │
│   ├── maintenance_queries.sql         # Diagnóstico: vacuum, bloat, XID, índices
│   ├── pg_cron_setup.sql               # Instalar pg_cron y registrar jobs
│   ├── readiness_check.sql             # Readiness probe en SQL puro
│   ├── postgresql-maintenance.crontab  # Crontab de referencia (solo documentación)
│   │
│   ├── liveness_probe.sh               # Sonda liveness (pg_isready + SELECT 1)
│   ├── readiness_probe.sh              # Sonda readiness (5 checks)
│   ├── maintenance_vacuum.sh           # VACUUM ANALYZE en tablas con bloat
│   ├── backup_logico.sh                # pg_dump → /backup/logico/
│   ├── backup_fisico.sh                # pg_basebackup → /backup/fisico/
│   └── validate_backup.sh             # Valida backup en instancia temporal
│
├── backup/
│   ├── logico/                         # Destino pg_dump  (montado en /backup/logico)
│   ├── fisico/                         # Destino pg_basebackup (montado en /backup/fisico)
│   └── wal_archive/                   # WAL archivados (montado en /backup/wal_archive)
│
└── logs/                               # Logs de scripts (montado en /var/log/pg_lab)
```

---

## ⚡ Inicio rápido

```bash
chmod +x scripts/*.sh
docker compose up --build -d
docker compose logs -f        # esperar: "Laboratorio listo │ Puerto: 5432"
```

---

## Práctica 1 — Vacuum, Autovacuum y Prevención de Bloat

### ¿Qué es el bloat y por qué ocurre?

PostgreSQL usa **MVCC** (Multiversion Concurrency Control): cuando se actualiza o elimina una fila no se borra físicamente, sino que se marca como "muerta" y se crea una versión nueva. Con el tiempo, estas filas muertas acumulan espacio desperdiciado llamado **bloat**.

```
INSERT / UPDATE / DELETE
        │
        ▼
  Fila "muerta" queda en disco
        │
        ▼  sin VACUUM
  Bloat: tabla/índice crece sin datos reales
        │
        ▼  con VACUUM
  Espacio marcado como reutilizable
```

Sin mantenimiento, el bloat puede causar:
- Tablas e índices mucho mayores de lo necesario.
- Degradación progresiva del rendimiento de las consultas.
- **Transaction ID Wraparound**: catástrofe que congela toda la base de datos.

## 1. Vacuum, Autovacuum y Prevención de Bloat



---

$ psql -h localhost -U postgres -d dwh
psql (16.14 (Ubuntu 16.14-0ubuntu0.24.04.1))
Type "help" for help.

dwh=# \dt
           List of relations
 Schema |    Name    | Type  |  Owner 
--------+------------+-------+----------
 public | backup_log | table | postgres
 public | pedidos    | table | postgres
 public | probe_log  | table | postgres
(3 rows)


### 1.1 VACUUM manual

```sql
-- Vacuum básico: marca espacio de filas muertas como reutilizable
-- Vacuum verboso: muestra estadísticas detalladas del proceso
VACUUM VERBOSE pedidos;

-- VACUUM FULL: devuelve espacio al sistema operativo (bloquea la tabla)
-- Usar solo en mantenimiento programado, nunca en producción activa
VACUUM FULL pedidos;

-- VACUUM + ANALYZE: vacía y actualiza estadísticas del planificador
VACUUM ANALYZE pedidos;

-- Ver el estado de vacuum de todas las tablas
SELECT
    schemaname,
    relname                             AS tabla,
    n_dead_tup                          AS filas_muertas,
    n_live_tup                          AS filas_vivas,
    ROUND(n_dead_tup * 100.0
        / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS pct_muertas,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

### Script completo

```bash
docker exec -it pg-maint psql -U postgres -d dwh \
    -f /scripts/maintenance_queries.sql
```

### Comandos individuales

```bash
# Ver estado de vacuum y % de bloat por tabla
docker exec -it pg-maint psql -U postgres -d dwh -c "
    SELECT relname,
           n_dead_tup,
           n_live_tup,
           ROUND(n_dead_tup*100.0/NULLIF(n_live_tup+n_dead_tup,0),2) AS pct_bloat,
           last_autovacuum,
           last_vacuum
    FROM pg_stat_user_tables
    ORDER BY n_dead_tup DESC LIMIT 10;"

# Riesgo de XID wraparound
docker exec -it pg-maint psql -U postgres -c "
    SELECT datname,
           age(datfrozenxid)                              AS xid_age,
           ROUND(age(datfrozenxid)*100.0/2100000000, 2)  AS pct_riesgo
    FROM pg_database ORDER BY xid_age DESC;"

# Generar más bloat para ver el efecto
docker exec -it pg-maint psql -U postgres -d dwh -c "
    UPDATE pedidos SET estado='procesado'
    WHERE ctid IN (
        SELECT ctid FROM pedidos WHERE estado='pendiente' LIMIT 10000
    );"

docker exec -it pg-maint psql -U postgres -d dwh -c "
    UPDATE pedidos SET estado='pendiente'
    WHERE ctid IN (
        SELECT ctid FROM pedidos WHERE estado='procesado' LIMIT 10000
    );"

# VACUUM ANALYZE manual
docker exec -it pg-maint psql -U postgres -d dwh \
    -c "VACUUM VERBOSE ANALYZE pedidos;"

# Ajustar autovacuum por tabla
docker exec -it pg-maint psql -U postgres -d dwh -c "
    ALTER TABLE pedidos SET (
        autovacuum_vacuum_scale_factor  = 0.01,
        autovacuum_analyze_scale_factor = 0.005
    );"

# Ejecutar el script de vacuum automático
docker exec -it pg-maint bash /scripts/maintenance_vacuum.sh
docker exec -it pg-maint cat /var/log/pg_lab/maintenance.log
```

### 1.2 Autovacuum: configuración y ajuste fino

El **autovacuum** es el proceso demonio que ejecuta VACUUM y ANALYZE automáticamente. Su configuración por defecto es conservadora; en bases de datos con alta escritura conviene ajustarla.

```ini
# postgresql.conf — parámetros globales de autovacuum

autovacuum = on                          # Nunca deshabilitar en producción

# Cuándo disparar autovacuum en una tabla:
# n_dead_tup > autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor * n_live_tup
autovacuum_vacuum_threshold    = 50      # Mínimo de filas muertas para activar
autovacuum_vacuum_scale_factor = 0.02    # 2% de la tabla (reducir en tablas grandes)
autovacuum_analyze_threshold   = 50
autovacuum_analyze_scale_factor= 0.01   # 1% para analizar más frecuentemente

# Recursos del autovacuum
autovacuum_max_workers         = 4       # Workers simultáneos (default: 3)
autovacuum_naptime             = 30s     # Frecuencia de comprobación (default: 1min)
autovacuum_vacuum_cost_delay   = 2ms     # Pausa entre páginas (reducir = más agresivo)
autovacuum_vacuum_cost_limit   = 400     # Coste por ciclo (default: 200)
```

#### Ajuste por tabla individual (para tablas con alta rotación)

```sql
-- Tabla de logs con millones de inserciones/borrados diarios
ALTER TABLE pedidos SET (
    autovacuum_vacuum_scale_factor   = 0.01,   -- Vacuum al 1% de filas muertas
    autovacuum_vacuum_threshold      = 100,
    autovacuum_analyze_scale_factor  = 0.005,
    autovacuum_vacuum_cost_delay     = 2
);

-- Ver la configuración de almacenamiento por tabla
SELECT relname, reloptions
FROM pg_class
WHERE reloptions IS NOT NULL;
```

---

### 1.3 Detectar y medir el bloat

```sql
-- Detectar tablas con alto bloat (requiere extensión pgstattuple o estimación)
SELECT
    schemaname,
    relname AS tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||relname)) AS tamanio_total,
    pg_size_pretty(pg_relation_size(schemaname||'.'||relname))       AS tamanio_tabla,
    n_dead_tup,
    n_live_tup,
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 1)  AS pct_bloat
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- Ver tablas que llevan más de 24 horas sin vacuum
SELECT relname, last_autovacuum, last_vacuum,
       now() - last_autovacuum AS tiempo_sin_autovacuum
FROM pg_stat_user_tables
WHERE (now() - last_autovacuum) > INTERVAL '24 hours'
   OR last_autovacuum IS NULL
ORDER BY tiempo_sin_autovacuum DESC NULLS FIRST;

-- Riesgo de Transaction ID Wraparound
-- Alerta si age > 1.500.000.000 (límite ~2.100.000.000)
SELECT datname,
       age(datfrozenxid)                    AS xid_age,
       2100000000 - age(datfrozenxid)       AS xids_restantes,
       ROUND(age(datfrozenxid) * 100.0
             / 2100000000, 2)               AS pct_riesgo
FROM pg_database
ORDER BY xid_age DESC;
```

---

### 1.4 Reconstruir índices

```sql
-- Ver tamaño de índices
SELECT
    indexrelname                          AS indice,
    pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio,
    idx_scan                              AS veces_usado
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;

-- Reconstruir un índice sin bloquear lecturas (PostgreSQL 12+)
--COn esto optimizamos el tamaño del indice
REINDEX INDEX CONCURRENTLY pedidos_pkey;

-- Reconstruir todos los índices de una tabla
REINDEX TABLE CONCURRENTLY pedidos;
```
---

## 2. Logs del Servidor: Configuración y Centralización

### 2.1 Configuración de logging en `postgresql.conf`

```ini
# ── Destino y colector ─────────────────────────────────────────
log_destination          = 'stderr'         # stderr | csvlog | jsonlog | syslog
logging_collector        = on               # Activar colector (escribe ficheros)
log_directory            = 'pg_log'         # Directorio relativo a PGDATA
log_filename             = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age         = 1d               # Rotar cada día
log_rotation_size        = 100MB            # O cuando alcance 100 MB
log_truncate_on_rotation = off              # No truncar al rotar

# ── Formato de cada línea ──────────────────────────────────────
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
# %t = timestamp   %p = PID   %l = línea del log
# %u = usuario     %d = base de datos   %a = app   %h = host cliente

# ── Qué registrar ─────────────────────────────────────────────
log_min_messages         = warning          # Nivel mínimo: debug5..panic
log_min_error_statement  = error            # SQL que causó el error
log_min_duration_statement = 1000           # Queries lentas > 1000 ms (0 = todas)

log_connections          = on               # Registrar nuevas conexiones
log_disconnections       = on               # Registrar desconexiones
log_duration             = off              # Duración de cada query (verboso)
log_statement            = 'ddl'            # none | ddl | mod | all
log_lock_waits           = on               # Esperas de lock > deadlock_timeout
log_checkpoints          = on               # Checkpoints (útil para tuning)
log_autovacuum_min_duration = 250ms         # Autovacuums lentos
log_temp_files           = 10MB             # Ficheros temporales grandes
```

---

### 2.2 Formato JSON para centralización (PostgreSQL 15+)

```ini
# Activar log en formato JSON (ideal para enviar a Loki, Elasticsearch, etc.)
log_destination  = 'jsonlog'
logging_collector = on
log_filename     = 'postgresql-%Y-%m-%d.json'
```

Cada entrada del log queda como un objeto JSON parseable:

```json
{
  "timestamp"  : "2025-09-01 08:32:14.123 CEST",
  "pid"        : 12345,
  "user"       : "dwh_user",
  "dbname"     : "dwh",
  "application_name": "airflow",
  "message"    : "duration: 1523.412 ms  statement: SELECT * FROM ventas",
  "error_severity": "LOG"
}
```

---

### 2.3 Consultar el log desde SQL con `pg_log_backend_memory_contexts`

```sql
-- Ver las queries activas en este momento con su duración
SELECT pid,
       now() - query_start          AS duracion,
       state,
       left(query, 80)              AS query_truncada,
       wait_event_type,
       wait_event
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start IS NOT NULL
ORDER BY duracion DESC;

```

---

## Práctica 2 — Logs del Servidor

```bash
# Log de PostgreSQL en tiempo real
docker logs pg-maint --follow 2>&1 | grep -v "^$"

# Leer el fichero de log directamente
docker exec -it pg-maint bash -c \
    "tail -50 /var/log/pg_lab/postgresql-\$(date +%Y-%m-%d).log"

# Filtrar queries lentas (log_min_duration_statement = 500 ms)
docker logs pg-maint 2>&1 | grep "duration:"

# Filtrar conexiones/desconexiones
docker logs pg-maint 2>&1 | grep -E "connection received|connection authorized|disconnection"

# Ver configuración de logging activa
docker exec -it pg-maint psql -U postgres -c "
    SELECT name, setting
    FROM pg_settings
    WHERE name LIKE 'log%'
    ORDER BY name;"
```

---

## Práctica 3 — Configuración y Automatización con pg_cron

### Instalar pg_cron y registrar todos los jobs del lab

```bash
docker exec -it pg-maint psql -U postgres -d postgres \
    -f /scripts/pg_cron_setup.sql
```


### 3.1 Sintaxis de programación (formato cron estándar)

```
┌───────────── minuto     (0 - 59)
│ ┌─────────── hora       (0 - 23)
│ │ ┌───────── día mes    (1 - 31)
│ │ │ ┌─────── mes        (1 - 12)
│ │ │ │ ┌───── día semana (0 - 7, 0 y 7 = domingo)
│ │ │ │ │
* * * * *

Ejemplos:
  0 2 * * *       → Cada día a las 02:00
  */15 * * * *    → Cada 15 minutos
  0 6 * * 1       → Cada lunes a las 06:00
  0 0 1 * *       → El día 1 de cada mes a las 00:00
  30 3 * * 0,6    → Sábados y domingos a las 03:30
```

### Gestión manual de jobs

```bash
# Ver jobs registrados
docker exec -it pg-maint psql -U postgres -d postgres -c "
    SELECT jobid, jobname, schedule, command, active
    FROM cron.job ORDER BY jobid;"

# Registrar un job nuevo
docker exec -it pg-maint psql -U postgres -d postgres -c "
    SELECT cron.schedule(
        'vacuum-pedidos',
        '0 2 * * 0',
        \$\$VACUUM VERBOSE public.pedidos\$\$
    );"

docker exec -it pg-maint psql -U postgres -d postgres -c "
    SELECT cron.schedule(
        'vacuum-pedidos2',
        '0 2 * * 0',
        \$\$SELECT * FROM pedidos\$\$
    );"

# Forzar ejecución ahora: cambiar schedule a cada minuto
docker exec -it pg-maint psql -U postgres -d postgres -c "
    UPDATE cron.job SET schedule='* * * * *'
    WHERE jobname='vacuum-pedidos';"

docker exec -it pg-maint psql -U postgres -d postgres -c "
    UPDATE cron.job SET schedule='* * * * *'
    WHERE jobname='vacuum-pedidos2';"

# Esperar 70 s y ver el historial
sleep 70
docker exec -it pg-maint psql -U postgres -d postgres -c "
    SELECT j.jobname, r.start_time,
           r.end_time - r.start_time AS duracion, r.status
    FROM cron.job_run_details r
    JOIN cron.job j USING (jobid)
    ORDER BY r.start_time DESC LIMIT 10;"

docker exec -it pg-maint psql -U postgres -d postgres -c "
    SELECT 
        j.jobname, 
        r.start_time, 
        r.status, 
        r.return_message
    FROM cron.job_run_details r
    JOIN cron.job j USING (jobid)
    WHERE r.status = 'failed'
    ORDER BY r.start_time DESC 
    LIMIT 10;" --set=tuples_only=off --set=expanded=on

# Restaurar schedule original y desactivar
docker exec -it pg-maint psql -U postgres -d postgres -c "
    UPDATE cron.job SET schedule='0 2 * * 0', active=false
    WHERE jobname='vacuum-pedidos';"

# Eliminar un job
docker exec -it pg-maint psql -U postgres -d postgres -c "
    SELECT cron.unschedule('vacuum-pedidos');"
```

---

## Práctica 4 — Programación de Tareas con SQL

```bash
# Vista consolidada: todos los jobs con su último estado
docker exec -it pg-maint psql -U postgres -d postgres -c "
    SELECT j.jobname, j.schedule, j.active,
           r.start_time        AS ultima_ejecucion,
           r.status,
           LEFT(r.return_message,60) AS mensaje
    FROM cron.job j
    LEFT JOIN LATERAL (
        SELECT * FROM cron.job_run_details
        WHERE jobid = j.jobid
        ORDER BY start_time DESC LIMIT 1
    ) r ON true
    ORDER BY j.jobname;"

# Solo jobs fallidos
docker exec -it pg-maint psql -U postgres -d postgres -c "
    SELECT j.jobname, r.start_time, r.return_message
    FROM cron.job_run_details r
    JOIN cron.job j USING (jobid)
    WHERE r.status = 'failed'
    ORDER BY r.start_time DESC LIMIT 10;"
```

---

## 5. Sonda de Disponibilidad (Liveness Probe)

> **Pregunta clave:** ¿Está PostgreSQL vivo y respondiendo?

### 5.1 `pg_isready` — comprobación básica

`pg_isready` envía una conexión de verificación y devuelve un código de salida:

| Código | Significado |
|---|---|
| `0` | El servidor acepta conexiones normalmente |
| `1` | El servidor existe pero rechaza conexiones (en startup/shutdown) |
| `2` | No hay respuesta del servidor |
| `3` | Error en los parámetros del comando |

```bash
# Comprobación básica
pg_isready -h localhost -p 5432

# Con usuario y base de datos específicos
pg_isready -h localhost -p 5432 -U dwh_user -d dwh

# Silencioso: solo devuelve el código de salida (ideal para scripts)
pg_isready -h localhost -p 5432 -q
echo "Exit code: $?"

# Con timeout (espera máximo 5 segundos)
pg_isready -h localhost -p 5432 --timeout=5
```

---

## Práctica 5 — Sonda de Disponibilidad (Liveness Probe)

```bash
# Ejecutar la sonda DENTRO del contenedor (conexión local)
docker exec -it pg-maint bash /scripts/liveness_probe.sh
# Salida esperada: [...] LIVENESS OK: localhost:5432 responde correctamente

$ ./liveness_probe.sh
[2026-06-25 00:16:00] LIVENESS OK: localhost:5432 responde correctamente
[2026-06-25 00:16:00] LIVENESS OK: localhost:5432 responde correctamente


# Con argumentos explícitos
docker exec -it pg-maint bash /scripts/liveness_probe.sh localhost 5432 postgres dwh

 ./liveness_probe.sh localhost 5432 postgres dwh
[2026-06-25 00:15:33] LIVENESS OK: localhost:5432 responde correctamente
[2026-06-25 00:15:33] LIVENESS OK: localhost:5432 responde correctamente


# Ver el log de la sonda
docker exec -it pg-maint cat /var/log/pg_lab/probes.log

# Simular fallo: detener PostgreSQL y ejecutar la sonda
docker exec -it pg-maint bash -c "
    pg_ctl stop -D \$PGDATA -m fast 2>/dev/null
    sleep 2
    /scripts/liveness_probe.sh localhost 5432 postgres dwh
    echo 'Exit code: '\$?"

# Recuperar el contenedor
docker restart pg-maint

# Ver el healthcheck de Docker
docker inspect pg-maint \
    --format='Status: {{.State.Health.Status}}'
docker inspect pg-maint \
    --format='{{range .State.Health.Log}}{{.Output}}{{end}}' | tail -5
```

### 5.2 Liveness Probe en Docker / Kubernetes

**Docker Compose:**

```yaml
services:
  postgres-dwh:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL",
             "pg_isready -U dwh_user -d dwh -q || exit 1"]
      interval:     10s   # Comprobar cada 10 segundos
      timeout:       5s   # Máximo tiempo de espera por comprobación
      retries:       5    # Marcar unhealthy tras 5 fallos consecutivos
      start_period: 30s   # Tiempo de gracia al arrancar el contenedor
```

**Kubernetes:**

```yaml
livenessProbe:
  exec:
    command:
      - pg_isready
      - -U
      - postgres
      - -d
      - dwh
  initialDelaySeconds: 30
  periodSeconds:       10
  timeoutSeconds:       5
  failureThreshold:     3
```
### 5.3 Monitorización del estado interno

```sql
-- Verificar que el servidor puede ejecutar operaciones internas
    SELECT
        pg_is_in_recovery()           AS es_replica,
        pg_postmaster_start_time()    AS inicio_servidor,
        now() - pg_postmaster_start_time() AS uptime,
        current_setting('server_version') AS version,
        (SELECT count(*) FROM pg_stat_activity) AS conexiones_activas,
        current_setting('max_connections')::INT AS max_conexiones;
```

---

## 6. Sonda de Preparación (Readiness Probe)

> **Pregunta clave:** ¿Es seguro enviar tráfico de producción a este servidor?  
> Un servidor puede estar *vivo* (Liveness OK) pero no *listo* (réplica rezagada, muchas conexiones, recovery en curso...).

### 6.1 Diferencia conceptual

```
Liveness  → ¿Activo? ¿Contesta?       (pg_isready + SELECT 1)
                │
Readiness → ¿Puede recibir tráfico?    (réplica al día + carga OK + no en recovery)
                │
                ▼
          Solo si ambas pasan → enrutar tráfico de producción
```

## Práctica 6 — Sonda de Preparación (Readiness Probe)

### 6.1 Script de Readiness Probe completo

```bash
#!/bin/bash
# readiness_probe.sh
# Comprueba si PostgreSQL está listo para recibir tráfico de producción.
# Retorna 0 si está listo, 1 si no.

set -euo pipefail

PG_HOST="${1:-localhost}"
PG_PORT="${2:-5432}"
PG_USER="${3:-postgres}"
PG_DB="${4:-postgres}"

MAX_LAG_SEGUNDOS=30        # Lag de réplica aceptable
MAX_CONEXIONES_PCT=85      # % de conexiones máximo admisible
LOG="/var/log/pg_probes.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
FALLO=0

log()  { echo "[$DATE] $1" | tee -a "$LOG"; }
psql_q() { psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -A -c "$1" 2>/dev/null; }

# ── Comprobación 1: Liveness básica ────────────────────────────
if ! pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -q; then
    log "READINESS FAIL: servidor no responde"
    exit 1
fi

# ── Comprobación 2: No debe estar en recovery (solo nodo primario) ──
IN_RECOVERY=$(psql_q "SELECT pg_is_in_recovery()")
if [ "$IN_RECOVERY" = "t" ]; then
    # Es una réplica: comprobar que su lag es aceptable
    LAG=$(psql_q "SELECT COALESCE(
                    EXTRACT(epoch FROM (now() - pg_last_xact_replay_timestamp()))::INT,
                    0)")
    if [ "$LAG" -gt "$MAX_LAG_SEGUNDOS" ]; then
        log "READINESS FAIL: réplica con lag de ${LAG}s (máximo ${MAX_LAG_SEGUNDOS}s)"
        FALLO=1
    else
        log "READINESS INFO: réplica en recovery, lag=${LAG}s — aceptable"
    fi
fi

# ── Comprobación 3: Uso de conexiones ──────────────────────────
CONEXIONES=$(psql_q "SELECT count(*) FROM pg_stat_activity WHERE state != 'idle'")
MAX_CONN=$(psql_q "SELECT current_setting('max_connections')::INT")
PCT=$(echo "scale=1; $CONEXIONES * 100 / $MAX_CONN" | bc)
PCT_INT=${PCT%.*}

if [ "$PCT_INT" -ge "$MAX_CONEXIONES_PCT" ]; then
    log "READINESS FAIL: conexiones al ${PCT}% del límite (${CONEXIONES}/${MAX_CONN})"
    FALLO=1
else
    log "READINESS INFO: conexiones ${CONEXIONES}/${MAX_CONN} (${PCT}%)"
fi

# ── Comprobación 4: No hay locks de larga duración (> 30 s) ────
LOCKS_LARGOS=$(psql_q "
    SELECT count(*)
    FROM pg_locks l
    JOIN pg_stat_activity a ON a.pid = l.pid
    WHERE NOT l.granted
      AND now() - a.query_start > INTERVAL '30 seconds'")

if [ "$LOCKS_LARGOS" -gt "0" ]; then
    log "READINESS WARN: $LOCKS_LARGOS lock(s) en espera > 30s"
    # No bloqueante: warning, pero no fallo (ajustar según política)
fi

# ── Comprobación 5: Autovacuum no está saturado ─────────────────
WORKERS_VACUUM=$(psql_q "
    SELECT count(*) FROM pg_stat_activity
    WHERE query LIKE 'autovacuum:%'")
MAX_WORKERS=$(psql_q "SELECT current_setting('autovacuum_max_workers')::INT")

if [ "$WORKERS_VACUUM" -ge "$MAX_WORKERS" ]; then
    log "READINESS WARN: autovacuum al límite (${WORKERS_VACUUM}/${MAX_WORKERS} workers)"
fi

# ── Resultado final ─────────────────────────────────────────────
if [ "$FALLO" -eq 0 ]; then
    log "READINESS OK: $PG_HOST:$PG_PORT listo para tráfico de producción"
    exit 0
else
    log "READINESS FAIL: $PG_HOST:$PG_PORT NO está listo"
    exit 1
fi
```

---

```bash
# Sonda readiness completa (5 checks) — versión bash
$ ./scripts/readiness_probe.sh
[2026-06-25 00:19:23] READINESS OK: liveness básica superada
[2026-06-25 00:19:23] READINESS OK: liveness básica superada
[2026-06-25 00:19:23] READINESS OK: nodo primario (no en recovery)
[2026-06-25 00:19:23] READINESS OK: nodo primario (no en recovery)
[2026-06-25 00:19:23] READINESS OK: conexiones 1/100 (1%)
[2026-06-25 00:19:23] READINESS OK: conexiones 1/100 (1%)
[2026-06-25 00:19:23] READINESS OK: sin locks bloqueantes de larga duración
[2026-06-25 00:19:23] READINESS OK: sin locks bloqueantes de larga duración
[2026-06-25 00:19:23] READINESS OK: autovacuum 0/3 workers
[2026-06-25 00:19:23] READINESS OK: autovacuum 0/3 workers
[2026-06-25 00:19:23] READINESS RESULT: localhost:5432 LISTO para tráfico de producción
[2026-06-25 00:19:23] READINESS RESULT: localhost:5432 LISTO para tráfico de producción


# Sonda readiness — versión SQL con PASS/WARN/FAIL por check
docker exec -it pg-maint psql -U postgres -d dwh \
    -f /scripts/readiness_check.sql
===================================================
READINESS CHECK — PostgreSQL
===================================================
 check | estado  | en_recovery |             version             |     uptime      
-------+---------+-------------+---------------------------------+-----------------
 nodo  | PRIMARY | f           | 16.14 (Debian 16.14-1.pgdg12+1) | 00:38:29.425198
(1 row)

    check    |      estado       | lag_segundos 
-------------+-------------------+--------------
 lag_replica | N/A (es primario) | N/A
(1 row)

   check    | estado | detalle | pct 
------------+--------+---------+-----
 conexiones | PASS   | 1 / 100 | 1%
(1 row)

 check | estado |      detalle      
-------+--------+-------------------
 locks | PASS   | 0 locks en espera
(1 row)

   check    | estado |    detalle    
------------+--------+---------------
 autovacuum | PASS   | 0 / 3 workers
(1 row)

    check     | estado |           detalle            | ultimo_archivo 
--------------+--------+------------------------------+----------------
 wal_archiver | FAIL   | archivados: 0, fallidos: 407 | 
(1 row)

     check      | estado |     detalle      | pct_riesgo 
----------------+--------+------------------+------------
 xid_wraparound | PASS   | 441 / 2100000000 | 0.0%
(1 row)

===================================================
Fin del readiness check
===================================================


# Ver el log de sondas
docker exec -it pg-maint cat /var/log/pg_lab/probes.log

# Checks individuales:

# Check 1 — pg_isready
docker exec -it pg-maint pg_isready -U postgres -d dwh -q && \
    echo "✓ pg_isready OK" || echo "✗ pg_isready FAIL"

# Check 2 — lag de réplica (en standalone es N/A)
docker exec -it pg-maint psql -U postgres -c "
    SELECT pg_is_in_recovery() AS es_replica,
           EXTRACT(epoch FROM (now()-pg_last_xact_replay_timestamp()))::INT
               AS lag_seg;"

# Check 3 — uso de conexiones
docker exec -it pg-maint psql -U postgres -c "
    SELECT count(*) AS activas,
           current_setting('max_connections')::INT AS maximo,
           ROUND(count(*)*100.0
               /current_setting('max_connections')::INT,1) AS pct_uso
    FROM pg_stat_activity WHERE state != 'idle';"

# Check 4 — locks bloqueantes
docker exec -it pg-maint psql -U postgres -c "
    SELECT count(*) AS locks_en_espera FROM pg_locks WHERE NOT granted;"

# Check 5 — saturación autovacuum
docker exec -it pg-maint psql -U postgres -c "
    SELECT count(*) AS workers_activos,
           current_setting('autovacuum_max_workers') AS max_workers
    FROM pg_stat_activity WHERE query LIKE 'autovacuum:%';"

```

---

### 6.2 Queries de Readiness desde SQL

```sql
-- Vista resumen del estado de preparación (ejecutar antes de enrutar tráfico)
SELECT
    -- Identidad del nodo
    pg_is_in_recovery()                          AS es_replica,

    -- Lag de replicación (null en primario)
    EXTRACT(epoch FROM (
        now() - pg_last_xact_replay_timestamp()
    ))::INT                                      AS lag_replica_segundos,

    -- Conexiones
    (SELECT count(*) FROM pg_stat_activity
     WHERE state != 'idle')                      AS conexiones_activas,
    current_setting('max_connections')::INT      AS max_conexiones,
    ROUND(
        (SELECT count(*) FROM pg_stat_activity WHERE state != 'idle')
        * 100.0 / current_setting('max_connections')::INT
    , 1)                                         AS pct_conexiones,

    -- Locks bloqueantes
    (SELECT count(*) FROM pg_locks WHERE NOT granted) AS locks_en_espera,

    -- Workers de autovacuum activos
    (SELECT count(*) FROM pg_stat_activity
     WHERE query LIKE 'autovacuum:%')            AS autovacuum_workers,

    -- Uptime
    now() - pg_postmaster_start_time()           AS uptime;
```

---



---

## 🛠️ Comandos de gestión

```bash
# Levantar el laboratorio
docker compose up --build -d

# Acceso interactivo a psql
docker exec -it pg-maint psql -U postgres -d dwh

# Shell dentro del contenedor
docker exec -it pg-maint bash

# Ver todos los logs de scripts
docker exec -it pg-maint ls -lh /var/log/pg_lab/
docker exec -it pg-maint tail -f /var/log/pg_lab/backup.log
docker exec -it pg-maint tail -f /var/log/pg_lab/probes.log
docker exec -it pg-maint tail -f /var/log/pg_lab/maintenance.log

# Log de PostgreSQL
docker exec -it pg-maint bash -c \
    "tail -f /var/log/pg_lab/postgresql-\$(date +%Y-%m-%d).log"

# Estado de pg_cron
docker exec -it pg-maint psql -U postgres -d postgres \
    -c "SELECT jobname, schedule, active FROM cron.job ORDER BY jobid;"

# Reiniciar desde cero (borra todos los datos)
docker compose down -v && docker compose up --build -d
```
---

## ⚠️ Errores comunes y soluciones

### Autovacuum no se dispara
```sql
-- Verificar que está activo
SHOW autovacuum;

-- Ver el umbral actual para una tabla específica
SELECT relname,
       n_dead_tup,
       current_setting('autovacuum_vacuum_threshold')::INT +
       current_setting('autovacuum_vacuum_scale_factor')::NUMERIC * n_live_tup
       AS umbral_vacuum
FROM pg_stat_user_tables
WHERE relname = 'pedidos';
```

### pg_cron no ejecuta los jobs
```sql
-- Verificar que la extensión está cargada
SHOW shared_preload_libraries;

-- Ver errores en el log de pg_cron
SELECT * FROM cron.job_run_details
WHERE status = 'failed'
ORDER BY start_time DESC LIMIT 10;
```

### Readiness Probe falla por lag de réplica
```sql
-- Ver el lag actual en la réplica
SELECT
    now() - pg_last_xact_replay_timestamp() AS lag,
    pg_last_wal_replay_lsn()                AS ultimo_lsn_aplicado,
    pg_last_wal_receive_lsn()               AS ultimo_lsn_recibido;
```

---

## 📋 Credenciales y rutas

| Recurso            | Valor                          |
|--------------------|--------------------------------|
| Usuario PG         | `postgres`                     |
| Contraseña         | `postgres_lab`                 |
| Usuario replicación| `replicator` / `repl_lab_2025` |
| Base de datos      | `dwh`                          |
| Puerto host        | `5432`                         |
| Backups lógicos    | `./backup/logico/`             |
| Backups físicos    | `./backup/fisico/`             |
| WAL archive        | `./backup/wal_archive/`        |
| Logs de scripts    | `./logs/`                      |



## 📚 Referencias

- [PostgreSQL — VACUUM](https://www.postgresql.org/docs/current/sql-vacuum.html)
- [PostgreSQL — Autovacuum](https://www.postgresql.org/docs/current/routine-vacuuming.html)
- [pg_cron — GitHub](https://github.com/citusdata/pg_cron)
- [pg_isready — Documentación](https://www.postgresql.org/docs/current/app-pg-isready.html)
- [PostgreSQL — Logging](https://www.postgresql.org/docs/current/runtime-config-logging.html)
- [pg_basebackup](https://www.postgresql.org/docs/current/app-pgbasebackup.html)
