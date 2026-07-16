-- =============================================================
-- scripts/03_verify_cluster.sql
-- Verificación completa del clúster y del estado de Spock
--
-- Ejecutar en cualquier nodo:
--   PGPASSWORD=Admin_Lab_2026 psql \
--     -h localhost -p 6432 -U admin ecommerce_db \
--     -f scripts/03_verify_cluster.sql
-- =============================================================

\echo '══════════════════════════════════════════════════════════'
\echo '  pgEdge Cluster — Verificación de estado'
\echo '══════════════════════════════════════════════════════════'

-- ── 1. Versión e identificación ───────────────────────────────
\echo ''
\echo '▸ 1. Versión de PostgreSQL y extensiones activas'
SELECT version();

SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('spock','vector','postgis','pgcrypto',
                  'pg_stat_statements','pg_cron','pg_stat_monitor')
ORDER BY extname;

-- ── 2. Nodos Spock registrados ────────────────────────────────
\echo ''
\echo '▸ 2. Nodos del clúster Spock (debe haber 3: n1, n2, n3)'
SELECT node_id, node_name FROM spock.node ORDER BY node_name;

-- ── 3. Suscripciones Spock ────────────────────────────────────
\echo ''
\echo '▸ 3. Suscripciones de replicación (malla completa = 6 en total por clúster)'
SELECT
    sub_name                                AS suscripcion,
    sub_enabled                             AS activa,
    sub_slot_name                           AS slot_wal,
    array_to_string(sub_replication_sets, ',') AS sets_replicados
FROM spock.subscription
ORDER BY sub_name;

-- ── 4. Tablas en el replication set ──────────────────────────
\echo ''
\echo '▸ 4. Tablas incluidas en replication sets de Spock'
SELECT
    COALESCE(set_name, '(sin repset)')  AS repset,
    nspname                             AS esquema,
    relname                             AS tabla
FROM spock.tables
ORDER BY set_name NULLS LAST, relname;

-- ── 5. Slots de replicación WAL ───────────────────────────────
\echo ''
\echo '▸ 5. Slots de replicación WAL (lag acumulado)'
SELECT
    slot_name,
    plugin,
    active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)
    ) AS lag_wal
FROM pg_replication_slots
ORDER BY slot_name;

-- ── 6. Datos replicados ───────────────────────────────────────
\echo ''
\echo '▸ 6. Tabla replication_test — escrituras de todos los nodos'
SELECT node_name, region, msg, ts
FROM replication_test
ORDER BY ts DESC;

\echo ''
\echo '▸ 6b. Conteo por tabla (debe ser idéntico en n1, n2 y n3)'
SELECT 'customers'        AS tabla, count(*) FROM customers
UNION ALL
SELECT 'products',                  count(*) FROM products
UNION ALL
SELECT 'orders',                    count(*) FROM orders
UNION ALL
SELECT 'replication_test',          count(*) FROM replication_test
ORDER BY tabla;

-- ── 7. Conflictos detectados ──────────────────────────────────
\echo ''
\echo '▸ 7. Conflictos detectados y resolución de Spock'
SELECT count(*) AS total_conflictos FROM spock.resolutions;

SELECT
    node_name,
    relname           AS tabla,
    conflict_type,
    conflict_resolution,
    log_time
FROM spock.resolutions
ORDER BY log_time DESC
LIMIT 10;

\echo ''
\echo '══════════════════════════════════════════════════════════'
\echo '  Compara los resultados ejecutando este script en n2/n3:'
\echo '  PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 ...'
\echo '  PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6434 ...'
\echo '══════════════════════════════════════════════════════════'
