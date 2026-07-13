-- =============================================================
-- maintenance_queries.sql
-- Colección de queries SQL para mantenimiento de PostgreSQL:
-- vacuum, bloat, índices, autovacuum, wraparound y estadísticas.
--
-- Uso: psql -U postgres -d dwh -f maintenance_queries.sql
--      O copiar y pegar las secciones que necesites.
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 1: Estado general del vacuum por tabla
-- ─────────────────────────────────────────────────────────────

SELECT
    schemaname,
    relname                                                  AS tabla,
    n_dead_tup                                               AS filas_muertas,
    n_live_tup                                               AS filas_vivas,
    ROUND(n_dead_tup * 100.0
        / NULLIF(n_live_tup + n_dead_tup, 0), 2)            AS pct_muertas,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    vacuum_count,
    autovacuum_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 30;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 2: Tablas con alto bloat (candidatas a VACUUM)
-- ─────────────────────────────────────────────────────────────

SELECT
    schemaname,
    relname,
    pg_size_pretty(pg_total_relation_size(
        schemaname||'.'||relname))                         AS tamanio_total,
    pg_size_pretty(pg_relation_size(
        schemaname||'.'||relname))                         AS tamanio_tabla,
    n_dead_tup                                               AS filas_muertas,
    n_live_tup                                               AS filas_vivas,
    ROUND(n_dead_tup * 100.0
        / NULLIF(n_live_tup + n_dead_tup, 0), 1)            AS pct_bloat
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 3: Tablas sin vacuum reciente (> 24 horas)
-- ─────────────────────────────────────────────────────────────

SELECT
    schemaname,
    relname,
    last_autovacuum,
    last_vacuum,
    now() - COALESCE(last_autovacuum, last_vacuum) AS tiempo_sin_vacuum
FROM pg_stat_user_tables
WHERE COALESCE(last_autovacuum, last_vacuum) < now() - INTERVAL '24 hours'
   OR (last_autovacuum IS NULL AND last_vacuum IS NULL)
ORDER BY tiempo_sin_vacuum DESC NULLS FIRST;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 4: Riesgo de Transaction ID Wraparound
-- Alerta cuando xid_age supera 1.500.000.000
-- Límite absoluto: 2.100.000.000
-- ─────────────────────────────────────────────────────────────

SELECT
    datname,
    age(datfrozenxid)                                        AS xid_age,
    2100000000 - age(datfrozenxid)                           AS xids_restantes,
    ROUND(age(datfrozenxid) * 100.0 / 2100000000, 2)        AS pct_riesgo,
    CASE
        WHEN age(datfrozenxid) > 1800000000 THEN '🔴 CRÍTICO'
        WHEN age(datfrozenxid) > 1500000000 THEN '🟠 ALERTA'
        WHEN age(datfrozenxid) > 1000000000 THEN '🟡 ATENCIÓN'
        ELSE                                     '🟢 OK'
    END                                                      AS estado
FROM pg_database
ORDER BY xid_age DESC;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 5: Estado y tamaño de índices
-- ─────────────────────────────────────────────────────────────

SELECT
    schemaname,
    relname,
    indexrelname                                             AS indice,
    pg_size_pretty(pg_relation_size(indexrelid))             AS tamanio,
    idx_scan                                                 AS veces_usado,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 30;

-- Índices nunca usados (candidatos a eliminar)
SELECT
    schemaname,
    relname,
    indexrelname                                             AS indice,
    pg_size_pretty(pg_relation_size(indexrelid))             AS tamanio_desperdiciado
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 6: Conexiones activas e idle
-- ─────────────────────────────────────────────────────────────

-- Resumen por estado
SELECT
    state,
    count(*)                                                 AS num_conexiones,
    ROUND(count(*) * 100.0
        / current_setting('max_connections')::INT, 1)       AS pct_max
FROM pg_stat_activity
GROUP BY state
ORDER BY num_conexiones DESC;

-- Conexiones activas con duración
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    now() - query_start                                      AS duracion_query,
    wait_event_type,
    wait_event,
    left(query, 100)                                         AS query_truncada
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start IS NOT NULL
ORDER BY duracion_query DESC;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 7: Locks y bloqueos
-- ─────────────────────────────────────────────────────────────

-- Locks en espera
SELECT
    blocked.pid                                              AS pid_bloqueado,
    blocked.usename                                          AS usuario_bloqueado,
    left(blocked.query, 80)                                  AS query_bloqueada,
    blocking.pid                                             AS pid_bloqueante,
    blocking.usename                                         AS usuario_bloqueante,
    left(blocking.query, 80)                                 AS query_bloqueante,
    now() - blocked.query_start                              AS tiempo_esperando
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 8: Queries lentas activas (> 5 segundos)
-- ─────────────────────────────────────────────────────────────

SELECT
    pid,
    usename,
    now() - query_start                                      AS duracion,
    state,
    wait_event_type,
    wait_event,
    left(query, 120)                                         AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > INTERVAL '5 seconds'
ORDER BY duracion DESC;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 9: Estadísticas del archivador WAL
-- ─────────────────────────────────────────────────────────────

SELECT
    archived_count,
    last_archived_wal,
    last_archived_time,
    failed_count,
    last_failed_wal,
    last_failed_time,
    now() - last_archived_time                               AS tiempo_desde_ultimo_archivo
FROM pg_stat_archiver;


-- ─────────────────────────────────────────────────────────────
-- SECCIÓN 10: Tamaño de objetos en la base de datos
-- ─────────────────────────────────────────────────────────────

-- Top 20 tablas más grandes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(
        schemaname||'.'||tablename))                         AS tamanio_total,
    pg_size_pretty(pg_relation_size(
        schemaname||'.'||tablename))                         AS tamanio_datos,
    pg_size_pretty(
        pg_total_relation_size(schemaname||'.'||tablename)
        - pg_relation_size(schemaname||'.'||tablename))      AS tamanio_indices
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog','information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Tamaño por schema
SELECT
    schemaname,
    pg_size_pretty(SUM(
        pg_total_relation_size(schemaname||'.'||tablename))) AS tamanio_total
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog','information_schema')
GROUP BY schemaname
ORDER BY SUM(pg_total_relation_size(schemaname||'.'||tablename)) DESC;
