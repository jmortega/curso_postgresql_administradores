-- ============================================================================
-- consulta_pg_locks.sql
-- Análisis completo de bloqueos activos usando pg_locks
--
-- Uso: psql -h localhost -U pguser -d appdb -f consulta_pg_locks.sql
-- ============================================================================

\echo ''
\echo '══════════════════════════════════════════════════════════════════'
\echo '  Análisis de bloqueos — pg_locks'
\echo '══════════════════════════════════════════════════════════════════'

-- ── 1. Visión global: todos los bloqueos activos ──────────────────────────────
\echo ''
\echo '▸ 1. Todos los bloqueos activos (granted=true) y en espera (granted=false):'
SELECT
    l.pid,
    a.usename                                   AS usuario,
    a.application_name                          AS aplicacion,
    l.locktype                                  AS tipo_lock,
    CASE l.locktype
        WHEN 'relation'     THEN c.relname
        WHEN 'transactionid'THEN l.transactionid::TEXT
        WHEN 'tuple'        THEN c.relname || ':fila'
        WHEN 'page'         THEN c.relname || ':pag ' || l.page::TEXT
        ELSE coalesce(c.relname, l.locktype)
    END                                         AS objeto,
    l.mode,
    l.granted,
    CASE l.granted
        WHEN true  THEN '✓ obtenido'
        WHEN false THEN '⏳ esperando'
    END                                         AS estado,
    a.state                                     AS estado_sesion,
    round(EXTRACT(EPOCH FROM (now() - a.query_start))::numeric, 1)
                                                AS duracion_s,
    left(a.query, 80)                           AS consulta
FROM pg_locks l
JOIN pg_stat_activity a  ON a.pid = l.pid
LEFT JOIN pg_class c     ON c.oid = l.relation
WHERE a.pid <> pg_backend_pid()
ORDER BY l.granted ASC, duracion_s DESC NULLS LAST;

-- ── 2. Jerarquía de agresividad de modos de bloqueo ──────────────────────────
\echo ''
\echo '▸ 2. Modos de bloqueo presentes (ordenados por agresividad):'
SELECT
    l.mode,
    CASE l.mode
        WHEN 'AccessShareLock'          THEN 1
        WHEN 'RowShareLock'             THEN 2
        WHEN 'RowExclusiveLock'         THEN 3
        WHEN 'ShareUpdateExclusiveLock' THEN 4
        WHEN 'ShareLock'                THEN 5
        WHEN 'ShareRowExclusiveLock'    THEN 6
        WHEN 'ExclusiveLock'            THEN 7
        WHEN 'AccessExclusiveLock'      THEN 8
    END                                         AS nivel_agresividad,
    CASE l.mode
        WHEN 'AccessShareLock'
            THEN 'SELECT — compatible con casi todo'
        WHEN 'RowShareLock'
            THEN 'SELECT FOR UPDATE/SHARE — bloquea la fila seleccionada'
        WHEN 'RowExclusiveLock'
            THEN 'INSERT/UPDATE/DELETE — bloqueo de fila, permite lecturas'
        WHEN 'ShareUpdateExclusiveLock'
            THEN 'VACUUM/ANALYZE — protege schema, permite DML'
        WHEN 'ShareLock'
            THEN 'CREATE INDEX (sin CONCURRENTLY) — bloquea escrituras'
        WHEN 'ShareRowExclusiveLock'
            THEN 'Triggers — más restrictivo que ShareLock'
        WHEN 'ExclusiveLock'
            THEN 'Replicación — bloquea casi todo excepto AccessShare'
        WHEN 'AccessExclusiveLock'
            THEN 'ALTER/DROP/TRUNCATE — bloqueo total, congela lecturas y escrituras'
    END                                         AS descripcion,
    count(*)                                    AS instancias,
    count(*) FILTER (WHERE NOT l.granted)       AS en_espera
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE a.pid <> pg_backend_pid()
GROUP BY l.mode
ORDER BY nivel_agresividad;

-- ── 3. Cadena completa de bloqueos (quién bloquea a quién) ───────────────────
\echo ''
\echo '▸ 3. Cadena de bloqueos — árbol bloqueador → bloqueado:'
WITH RECURSIVE cadena_bloqueos AS (
    -- Nodo raíz: procesos que bloquean a otros pero no están bloqueados
    SELECT
        bloqueador.pid                          AS pid_raiz,
        bloqueador.pid                          AS pid_actual,
        bloqueador.usename                      AS usuario,
        bloqueador.query                        AS consulta,
        0                                       AS profundidad,
        ARRAY[bloqueador.pid]                   AS camino
    FROM pg_stat_activity bloqueador
    WHERE bloqueador.pid <> pg_backend_pid()
      AND EXISTS (
          SELECT 1 FROM pg_stat_activity bloqueado
          WHERE bloqueado.pid = ANY(pg_blocking_pids(bloqueador.pid)) IS FALSE
            AND bloqueador.pid = ANY(pg_blocking_pids(bloqueado.pid))
      )

    UNION ALL

    -- Nodo hijo: procesos bloqueados por el nodo padre
    SELECT
        cb.pid_raiz,
        bloqueado.pid,
        bloqueado.usename,
        bloqueado.query,
        cb.profundidad + 1,
        cb.camino || bloqueado.pid
    FROM cadena_bloqueos cb
    JOIN pg_stat_activity bloqueado
        ON cb.pid_actual = ANY(pg_blocking_pids(bloqueado.pid))
    WHERE NOT bloqueado.pid = ANY(cb.camino)   -- evitar ciclos
      AND cb.profundidad < 5
)
SELECT
    repeat('  ', profundidad) ||
    CASE profundidad
        WHEN 0 THEN '🔒 '
        ELSE        '⏳ → '
    END || pid_actual::TEXT                     AS arbol,
    usuario,
    CASE profundidad
        WHEN 0 THEN 'BLOQUEADOR'
        ELSE        'BLOQUEADO'
    END                                         AS rol,
    left(consulta, 80)                          AS consulta
FROM cadena_bloqueos
ORDER BY pid_raiz, profundidad;

-- ── 4. Tablas más contendidas (con más procesos esperando lock) ───────────────
\echo ''
\echo '▸ 4. Tablas con mayor contención de bloqueos:'
SELECT
    c.relname                                   AS tabla,
    l.mode,
    count(*)                                    AS total_locks,
    count(*) FILTER (WHERE NOT l.granted)       AS en_espera,
    count(*) FILTER (WHERE l.granted)           AS obtenidos,
    array_agg(DISTINCT a.usename)               AS usuarios
FROM pg_locks l
JOIN pg_class c         ON c.oid = l.relation
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.locktype = 'relation'
  AND c.relkind = 'r'
  AND a.pid <> pg_backend_pid()
GROUP BY c.relname, l.mode
HAVING count(*) FILTER (WHERE NOT l.granted) > 0
    OR count(*) > 2
ORDER BY en_espera DESC, total_locks DESC;

-- ── 5. Diagnóstico rápido: semáforo de salud de bloqueos ─────────────────────
\echo ''
\echo '▸ 5. Diagnóstico de salud de bloqueos:'
SELECT
    CASE
        WHEN esperando = 0 AND total = 0
            THEN '🟢 Sin bloqueos — sistema en reposo'
        WHEN esperando = 0
            THEN '🟢 ' || total || ' bloqueo(s) activo(s), ninguno en espera'
        WHEN max_espera_s < 5
            THEN '🟡 ' || esperando || ' proceso(s) esperando (< 5s) — normal bajo carga'
        WHEN max_espera_s < 30
            THEN '🟠 ' || esperando || ' proceso(s) esperando ' || max_espera_s || 's — revisar'
        ELSE
            '🔴 ' || esperando || ' proceso(s) esperando ' || max_espera_s || 's — CRÍTICO'
    END                                         AS estado_bloqueos,
    total                                       AS locks_totales,
    esperando                                   AS locks_en_espera,
    max_espera_s                                AS espera_maxima_s
FROM (
    SELECT
        count(*)                                AS total,
        count(*) FILTER (WHERE NOT l.granted)   AS esperando,
        COALESCE(
            round(MAX(
                EXTRACT(EPOCH FROM (now() - a.query_start))
            ) FILTER (WHERE NOT l.granted)::numeric, 1),
            0
        )                                       AS max_espera_s
    FROM pg_locks l
    JOIN pg_stat_activity a ON a.pid = l.pid
    WHERE a.pid <> pg_backend_pid()
) sub;

\echo ''
\echo '══════════════════════════════════════════════════════════════════'
