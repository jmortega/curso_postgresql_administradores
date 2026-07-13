-- =============================================================
-- readiness_check.sql
-- Readiness probe completa ejecutable directamente desde psql.
-- Devuelve una fila por comprobación con estado PASS/WARN/FAIL.
--
-- Uso: psql -U postgres -d dwh -f readiness_check.sql
--      psql -U postgres -d dwh -c "\i readiness_check.sql"
-- =============================================================

\echo '==================================================='
\echo 'READINESS CHECK — PostgreSQL'
\echo '==================================================='

-- ── Resumen del nodo ─────────────────────────────────────────────
SELECT
    'nodo'                                                   AS check,
    CASE
        WHEN pg_is_in_recovery() THEN 'REPLICA'
        ELSE 'PRIMARY'
    END                                                      AS estado,
    pg_is_in_recovery()                                      AS en_recovery,
    current_setting('server_version')                        AS version,
    now() - pg_postmaster_start_time()                       AS uptime;

-- ── Lag de réplica ────────────────────────────────────────────────
SELECT
    'lag_replica'                                            AS check,
    CASE
        WHEN NOT pg_is_in_recovery()
            THEN 'N/A (es primario)'
        WHEN EXTRACT(epoch FROM
                now() - pg_last_xact_replay_timestamp()) <= 30
            THEN 'PASS'
        ELSE 'FAIL'
    END                                                      AS estado,
    COALESCE(
        EXTRACT(epoch FROM
            now() - pg_last_xact_replay_timestamp())::INT::TEXT || 's',
        'N/A'
    )                                                        AS lag_segundos;

-- ── Uso de conexiones ─────────────────────────────────────────────
SELECT
    'conexiones'                                             AS check,
    CASE
        WHEN ROUND(
            (SELECT count(*) FROM pg_stat_activity
             WHERE state != 'idle') * 100.0
            / current_setting('max_connections')::INT
        ) < 85 THEN 'PASS'
        WHEN ROUND(
            (SELECT count(*) FROM pg_stat_activity
             WHERE state != 'idle') * 100.0
            / current_setting('max_connections')::INT
        ) < 95 THEN 'WARN'
        ELSE 'FAIL'
    END                                                      AS estado,
    (SELECT count(*) FROM pg_stat_activity
     WHERE state != 'idle')::TEXT
        || ' / '
        || current_setting('max_connections')                AS detalle,
    ROUND(
        (SELECT count(*) FROM pg_stat_activity
         WHERE state != 'idle') * 100.0
        / current_setting('max_connections')::INT
    )::TEXT || '%'                                           AS pct;

-- ── Locks bloqueantes ─────────────────────────────────────────────
SELECT
    'locks'                                                  AS check,
    CASE
        WHEN (
            SELECT count(*) FROM pg_locks l
            JOIN pg_stat_activity a ON a.pid = l.pid
            WHERE NOT l.granted
              AND now() - a.query_start > INTERVAL '30 seconds'
        ) = 0 THEN 'PASS'
        ELSE 'WARN'
    END                                                      AS estado,
    (
        SELECT count(*) FROM pg_locks
        WHERE NOT granted
    )::TEXT || ' locks en espera'                            AS detalle;

-- ── Autovacuum ────────────────────────────────────────────────────
SELECT
    'autovacuum'                                             AS check,
    CASE
        WHEN (
            SELECT count(*) FROM pg_stat_activity
            WHERE query LIKE 'autovacuum:%'
        ) < current_setting('autovacuum_max_workers')::INT
        THEN 'PASS'
        ELSE 'WARN'
    END                                                      AS estado,
    (SELECT count(*) FROM pg_stat_activity
     WHERE query LIKE 'autovacuum:%')::TEXT
        || ' / '
        || current_setting('autovacuum_max_workers')
        || ' workers'                                        AS detalle;

-- ── Archivado WAL ─────────────────────────────────────────────────
SELECT
    'wal_archiver'                                           AS check,
    CASE
        WHEN failed_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END                                                      AS estado,
    'archivados: ' || archived_count::TEXT
        || ', fallidos: ' || failed_count::TEXT              AS detalle,
    last_archived_time                                       AS ultimo_archivo
FROM pg_stat_archiver;

-- ── Riesgo de XID Wraparound ──────────────────────────────────────
SELECT
    'xid_wraparound'                                         AS check,
    CASE
        WHEN MAX(age(datfrozenxid)) < 1000000000 THEN 'PASS'
        WHEN MAX(age(datfrozenxid)) < 1500000000 THEN 'WARN'
        ELSE 'FAIL'
    END                                                      AS estado,
    MAX(age(datfrozenxid))::TEXT || ' / 2100000000'         AS detalle,
    ROUND(MAX(age(datfrozenxid)) * 100.0 / 2100000000, 1)::TEXT
        || '%'                                               AS pct_riesgo
FROM pg_database;

\echo '==================================================='
\echo 'Fin del readiness check'
\echo '==================================================='
