-- =============================================================
-- pg_cron_setup.sql
-- Instalación, configuración y registro de todos los jobs
-- de mantenimiento con pg_cron adaptados a la tabla 'pedidos'.
--
-- Prerequisito en postgresql.conf:
--   shared_preload_libraries = 'pg_cron'
--   cron.database_name = 'postgres'
--   cron.timezone = 'Europe/Madrid'
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- INSTALACIÓN
-- ─────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Verificar que la extensión quedó activa
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_cron';


-- ─────────────────────────────────────────────────────────────
-- FUNCIÓN: mantenimiento integral de tablas
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION mantenimiento_tablas(
    p_schema        TEXT    DEFAULT 'public',
    p_bloat_umbral  NUMERIC DEFAULT 20.0
)
RETURNS TABLE (tabla TEXT, accion TEXT, resultado TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    rec         RECORD;
    v_inicio    TIMESTAMPTZ;
    v_duracion INTERVAL;
BEGIN
    FOR rec IN
        SELECT schemaname, relname,
               n_dead_tup,
               ROUND(n_dead_tup * 100.0
                   / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS pct_bloat
        FROM pg_stat_user_tables
        WHERE schemaname = p_schema
          AND n_dead_tup > 100
          AND ROUND(n_dead_tup * 100.0
                  / NULLIF(n_live_tup + n_dead_tup, 0), 1) >= p_bloat_umbral
        ORDER BY n_dead_tup DESC
    LOOP
        v_inicio := clock_timestamp();
        EXECUTE format('VACUUM ANALYZE %I.%I', rec.schemaname, rec.relname);
        v_duracion := clock_timestamp() - v_inicio;

        tabla     := rec.schemaname || '.' || rec.relname;
        accion    := 'VACUUM ANALYZE';
        resultado := format('%s filas muertas, %.0f ms',
                            rec.n_dead_tup,
                            EXTRACT(milliseconds FROM v_duracion));
        RETURN NEXT;
    END LOOP;
END;
$$;


-- ─────────────────────────────────────────────────────────────
-- REGISTRO DE JOBS (IDEMPOTENTE)
-- ─────────────────────────────────────────────────────────────

-- Eliminar jobs anteriores para evitar duplicados al re-ejecutar el script
DO $$
DECLARE
    job_names TEXT[] := ARRAY[
        'vacuum-pedidos-semanal',
        'purga-pedidos-cancelados',
        'mantenimiento-automatizado-public',
        'reindex-pedidos-mensual'
    ];
    jname TEXT;
BEGIN
    FOREACH jname IN ARRAY job_names LOOP
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = jname) THEN
            PERFORM cron.unschedule(jname);
            RAISE NOTICE 'Job eliminado: %', jname;
        END IF;
    END LOOP;
END;
$$;


-- ── Job 1: Vacuum semanal de la tabla pedidos ──────────────────────────
-- Ejecuta un VACUUM ANALYZE optimizado todos los domingos a las 02:00 en la BD dwh
SELECT cron.schedule(
    'vacuum-pedidos-semanal',
    '0 2 * * 0',  
    $$VACUUM ANALYZE public.pedidos$$
);

-- ── Job 2: Purga periódica de pedidos obsoletos ────────────────────────
-- Elimina de forma automática los pedidos con estado 'cancelado' que tengan más de 1 año.
-- Se ejecuta el día 1 de cada mes a la medianoche (00:00) en la BD dwh
SELECT cron.schedule(
    'purga-pedidos-cancelados',
    '0 0 1 * *',  
    $$DELETE FROM public.pedidos 
      WHERE estado = 'cancelado' 
        AND fecha_creacion < now() - INTERVAL '1 year'$$
);

-- ── Job 3: Mantenimiento analítico condicional por Bloat ───────────────
-- Todos los domingos a las 03:00, analiza el esquema 'public'.
-- Si la tabla pedidos (u otra) supera el 15% de filas muertas, le aplica un VACUUM.
SELECT cron.schedule(
    'mantenimiento-automatizado-public',
    '0 3 * * 0',  
    $$SELECT * FROM mantenimiento_tablas('public', 15.0)$$
);

-- ── Job 4: Reindexación concurrente periódica ──────────────────────────
-- Reconstruye los índices de la tabla (incluyendo la clave primaria y el índice GIN de metadatos)
-- de forma segura en producción el día 1 de cada mes a las 04:00 AM para evitar degradación.
SELECT cron.schedule(
    'reindex-pedidos-mensual',
    '0 4 1 * *',  
    $$REINDEX TABLE CONCURRENTLY public.pedidos$$
);


-- ─────────────────────────────────────────────────────────────
-- VERIFICACIÓN: listar todos los jobs registrados
-- ─────────────────────────────────────────────────────────────

SELECT
    jobid,
    jobname,
    schedule,
    command,
    active,
    database,
    username
FROM cron.job
ORDER BY jobid;


-- ─────────────────────────────────────────────────────────────
-- MONITORIZACIÓN: estado de ejecuciones
-- ─────────────────────────────────────────────────────────────

-- Historial de las últimas 20 ejecuciones globales
SELECT
    j.jobname,
    r.start_time,
    r.end_time,
    r.end_time - r.start_time   AS duracion,
    r.status,
    LEFT(r.return_message, 80)  AS mensaje
FROM cron.job_run_details r
JOIN cron.job j USING (jobid)
ORDER BY r.start_time DESC
LIMIT 20;

-- Vista consolidada: último estado de cada Job del sistema
SELECT
    j.jobname,
    j.schedule,
    j.database,
    j.active,
    r.start_time                AS ultima_ejecucion,
    r.end_time - r.start_time   AS duracion,
    r.status,
    LEFT(r.return_message, 60) AS mensaje
FROM cron.job j
LEFT JOIN LATERAL (
    SELECT *
    FROM cron.job_run_details
    WHERE jobid = j.jobid
    ORDER BY start_time DESC
    LIMIT 1
) r ON true
ORDER BY j.jobname;
