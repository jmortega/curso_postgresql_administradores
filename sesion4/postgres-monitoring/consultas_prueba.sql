-- ============================================================================
-- consultas_prueba.sql
-- Consultas de prueba sobre appdb para generar actividad visible
-- en Prometheus (pg_stat_statements) y dashboards Grafana/Loki
--
-- Uso: psql -h localhost -U pguser -d appdb -f consultas_prueba.sql
-- ============================================================================

\echo ''
\echo '══════════════════════════════════════════════════════════'
\echo '  Consultas de prueba — appdb'
\echo '══════════════════════════════════════════════════════════'

-- ── 1. Volumen de eventos ─────────────────────────────────────────────────────
\echo ''
\echo '▸ 1. Volumen total de eventos por severidad:'
SELECT
    severidad,
    count(*)                                AS total,
    round(count(*) * 100.0 / sum(count(*)) OVER (), 1) AS pct
FROM public.eventos
GROUP BY severidad
ORDER BY total DESC;

-- ── 2. Eventos pendientes de procesar ─────────────────────────────────────────
\echo ''
\echo '▸ 2. Backlog de eventos sin procesar por origen:'
SELECT
    origen,
    count(*)    AS pendientes,
    min(creado_en)::TIMESTAMP(0) AS mas_antiguo
FROM public.eventos
WHERE NOT procesado
GROUP BY origen
ORDER BY pendientes DESC;

-- ── 3. Tasa de error por servicio (vista monitoring) ─────────────────────────
\echo ''
\echo '▸ 3. Tasa de error por origen (via monitoring.tasa_errores_por_origen):'
SELECT
    origen,
    total_eventos,
    total_errores,
    pct_error,
    ultimo_error::TIMESTAMP(0)
FROM monitoring.tasa_errores_por_origen;

-- ── 4. Latencia de endpoints (percentiles) ────────────────────────────────────
\echo ''
\echo '▸ 4. Rendimiento de endpoints — p50/p95/p99 (via monitoring.rendimiento_endpoints):'
SELECT
    endpoint,
    peticiones,
    latencia_media_ms,
    p50_ms,
    p95_ms,
    p99_ms,
    pct_cache_hit || '%' AS cache_hit_ratio
FROM monitoring.rendimiento_endpoints;

-- ── 5. Eventos de las últimas 2 horas agrupados por minuto ───────────────────
\echo ''
\echo '▸ 5. Tasa de ingesta de eventos — últimas 2 horas (por intervalos de 10 min):'
SELECT
    date_trunc('hour', creado_en)
        + (EXTRACT(MINUTE FROM creado_en)::INT / 10) * interval '10 minutes'
                        AS bucket,
    severidad,
    count(*)            AS eventos
FROM public.eventos
WHERE creado_en > now() - interval '2 hours'
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- ── 6. Sesiones activas ahora mismo ──────────────────────────────────────────
\echo ''
\echo '▸ 6. Sesiones activas por subred:'
SELECT
    network(ip_origen)  AS subred,
    count(*)            AS sesiones_activas,
    min(inicio)::TIMESTAMP(0) AS sesion_mas_antigua
FROM public.sesiones
WHERE activa
GROUP BY subred
ORDER BY sesiones_activas DESC;

-- ── 7. Consulta pesada intencional (genera actividad en pg_stat_statements) ───
\echo ''
\echo '▸ 7. Join eventos × metricas_consultas (consulta intencional costosa):'
SELECT
    e.origen,
    e.tipo,
    count(e.id)                             AS num_eventos,
    round(avg(m.duracion_ms)::numeric, 2)   AS latencia_media_ms,
    round(avg((e.payload->>'latencia_ms')::numeric), 2) AS latencia_payload_ms
FROM public.eventos e
JOIN public.metricas_consultas m
    ON m.endpoint LIKE '%' || split_part(e.origen, '-', 1) || '%'
WHERE e.creado_en > now() - interval '7 days'
GROUP BY e.origen, e.tipo
ORDER BY num_eventos DESC
LIMIT 20;

-- ── 8. Consultas más lentas según pg_stat_statements ─────────────────────────
\echo ''
\echo '▸ 8. Top 5 consultas más lentas (pg_stat_statements):'
SELECT
    left(query, 80)                                     AS consulta,
    calls,
    round(mean_exec_time::numeric, 2)                   AS media_ms,
    round(max_exec_time::numeric, 2)                    AS max_ms,
    round(total_exec_time::numeric, 2)                  AS total_ms,
    round(rows::numeric / NULLIF(calls, 0), 1)          AS filas_por_llamada
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
  AND calls > 1
ORDER BY mean_exec_time DESC
LIMIT 5;

-- ── 9. Cache hit ratio de la base de datos ────────────────────────────────────
\echo ''
\echo '▸ 9. Cache hit ratio de appdb:'
SELECT
    datname,
    blks_read,
    blks_hit,
    round(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    tup_returned,
    tup_fetched,
    xact_commit,
    xact_rollback
FROM pg_stat_database
WHERE datname = 'appdb';

-- ── 10. Tamaño de tablas del esquema public ───────────────────────────────────
\echo ''
\echo '▸ 10. Tamaño de tablas en appdb.public:'
SELECT
    relname                                             AS tabla,
    pg_size_pretty(pg_total_relation_size(oid))         AS tamanio_total,
    pg_size_pretty(pg_relation_size(oid))               AS tamanio_datos,
    pg_size_pretty(pg_indexes_size(oid))                AS tamanio_indices,
    reltuples::BIGINT                                   AS filas_estimadas
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC;

\echo ''
\echo '══════════════════════════════════════════════════════════'
\echo '  Fin de consultas de prueba'
\echo '══════════════════════════════════════════════════════════'
