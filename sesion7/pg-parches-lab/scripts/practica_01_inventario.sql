-- =============================================================
-- practica_01_inventario.sql
-- Práctica 1: Inventario del clúster y verificación de prerequisitos
-- Equivale a inventory_cluster.sh pero ejecutable con docker exec
--
-- Ejecutar:
--   docker exec -it pg-primary patronictl -c /etc/patroni/patroni.yml list
--   docker exec -it pg-primary psql -U postgres -f /scripts/practica_01_inventario.sql
-- =============================================================

\echo ''
\echo '╔══════════════════════════════════════════════════════╗'
\echo '║   PRÁCTICA 1: Inventario Pre-Parche del Clúster      ║'
\echo '╚══════════════════════════════════════════════════════╝'

-- ── 1.1 Versión PostgreSQL ────────────────────────────────────
\echo ''
\echo '▸ 1.1 Versión de PostgreSQL en este nodo:'
SELECT version() AS version_completa,
       current_setting('server_version')    AS version_corta,
       current_setting('server_version_num') AS version_num;

-- ── 1.2 Extensiones instaladas y si tienen actualización ─────
\echo ''
\echo '▸ 1.2 Extensiones instaladas (y si hay versión nueva disponible):'
SELECT
    name,
    installed_version                        AS instalada,
    default_version                          AS disponible,
    CASE
        WHEN installed_version = default_version THEN '✓ al día'
        WHEN installed_version IS NOT NULL       THEN '⚠ actualización disponible'
        ELSE '—'
    END AS estado
FROM pg_available_extensions
WHERE installed_version IS NOT NULL
ORDER BY name;

-- ── 1.3 Tamaño de bases de datos ─────────────────────────────
\echo ''
\echo '▸ 1.3 Tamaño de bases de datos:'
SELECT
    d.datname,
    pg_size_pretty(pg_database_size(d.datname)) AS tamanio,
    s.numbackends                                AS conexiones_activas
FROM pg_database d
JOIN pg_stat_database s ON s.datid = d.oid
WHERE d.datname NOT IN ('template0','template1')
ORDER BY pg_database_size(d.datname) DESC;

-- ── 1.4 Estado de replicación ─────────────────────────────────
\echo ''
\echo '▸ 1.4 Estado de replicación streaming:'
SELECT
    application_name,
    client_addr,
    state,
    sync_state,
    COALESCE(replay_lag::TEXT, '0') AS replay_lag,
    CASE
        WHEN replay_lag IS NULL             THEN '🔴 sin datos'
        WHEN replay_lag < INTERVAL '5s'    THEN '🟢 OK'
        WHEN replay_lag < INTERVAL '30s'   THEN '🟡 atención'
        ELSE                                    '🔴 crítico'
    END AS estado_lag
FROM pg_stat_replication
ORDER BY application_name;

-- ── 1.5 Verificar prerequisitos de seguridad para parchear ───
\echo ''
\echo '▸ 1.5 Verificación de prerequisitos pre-parche:'

-- Transacciones largas (deben ser 0 para parchear)
SELECT
    '5 min+ transactions' AS check,
    count(*)              AS cantidad,
    CASE WHEN count(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL — cancelar antes de parchear' END AS resultado
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND now() - xact_start > INTERVAL '5 minutes'
  AND state != 'idle'

UNION ALL

-- Vacuums en ejecución
SELECT
    'vacuums activos',
    count(*),
    CASE WHEN count(*) = 0 THEN '✅ PASS' ELSE '⚠ WARN — esperar a que terminen' END
FROM pg_stat_progress_vacuum

UNION ALL

-- Slots reteniendo WAL
SELECT
    'slots reteniendo WAL',
    count(*),
    CASE WHEN count(*) = 0 THEN '✅ PASS' ELSE '⚠ WARN — revisar slots inactivos' END
FROM pg_replication_slots
WHERE NOT active

UNION ALL

-- Réplicas conectadas
SELECT
    'réplicas en streaming',
    count(*),
    CASE WHEN count(*) >= 2 THEN '✅ PASS' ELSE '⚠ WARN — menos réplicas de lo esperado' END
FROM pg_stat_replication
WHERE state = 'streaming';

-- ── 1.6 WAL retenido por slots ────────────────────────────────
\echo ''
\echo '▸ 1.6 Slots de replicación y WAL retenido:'
SELECT
    slot_name,
    slot_type,
    active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS wal_retenido
FROM pg_replication_slots
ORDER BY slot_name;

-- ── 1.7 Conexiones activas por base de datos ─────────────────
\echo ''
\echo '▸ 1.7 Conexiones activas:'
SELECT
    datname,
    count(*)                                    AS total,
    count(*) FILTER (WHERE state = 'active')    AS activas,
    count(*) FILTER (WHERE state = 'idle')      AS idle,
    count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_tx
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY datname
ORDER BY total DESC;

\echo ''
\echo '✓ Inventario completado'
\echo '  Usar: docker exec -it pg-primary patronictl -c /etc/patroni/patroni.yml list'
\echo '  Para ver el estado completo del clúster Patroni'
\echo '╚══════════════════════════════════════════════════════╝'
