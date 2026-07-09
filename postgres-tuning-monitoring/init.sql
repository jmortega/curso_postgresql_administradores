-- ============================================================================
-- Configuración inicial de PostgreSQL para monitorización
-- Se ejecuta al crear el contenedor por primera vez (volumen vacío)
-- ============================================================================

-- Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Schema dedicado para vistas de diagnóstico
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Usuario de solo lectura para el exporter
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postgres_exporter') THEN
    CREATE USER postgres_exporter
      WITH PASSWORD 'exporter_password_changeme'
      NOSUPERUSER NOCREATEDB NOCREATEROLE;
  END IF;
END
$$;

-- Permisos de monitorización (rol pg_monitor disponible desde PG 10)
GRANT pg_monitor TO postgres_exporter;
GRANT CONNECT ON DATABASE appdb TO postgres_exporter;
GRANT USAGE ON SCHEMA public TO postgres_exporter;
GRANT USAGE ON SCHEMA monitoring TO postgres_exporter;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres_exporter;
GRANT SELECT ON ALL TABLES IN SCHEMA monitoring TO postgres_exporter;

-- ── Tablas de prueba para métricas Prometheus ─────────────────────────────────

-- Tabla principal de eventos (simula ingesta de telemetría IoT / app)
CREATE TABLE IF NOT EXISTS public.eventos (
    id              BIGSERIAL       PRIMARY KEY,
    tipo            VARCHAR(50)     NOT NULL,           -- 'login','compra','error','alerta'
    severidad       VARCHAR(20)     NOT NULL            -- 'info','warn','error','critical'
                    CHECK (severidad IN ('info','warn','error','critical')),
    origen          VARCHAR(100)    NOT NULL,           -- servicio o sensor que genera el evento
    usuario_id      INTEGER,                            -- NULL si es evento de sistema
    payload         JSONB,                              -- datos adicionales del evento
    procesado       BOOLEAN         NOT NULL DEFAULT false,
    creado_en       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    procesado_en    TIMESTAMPTZ
);

-- Índices para consultas de monitorización frecuentes
CREATE INDEX IF NOT EXISTS idx_eventos_tipo        ON public.eventos (tipo);
CREATE INDEX IF NOT EXISTS idx_eventos_severidad   ON public.eventos (severidad);
CREATE INDEX IF NOT EXISTS idx_eventos_creado_en   ON public.eventos (creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_eventos_procesado   ON public.eventos (procesado) WHERE NOT procesado;
CREATE INDEX IF NOT EXISTS idx_eventos_origen      ON public.eventos (origen);

-- Tabla de métricas de rendimiento de consultas (para comparar con pg_stat_statements)
CREATE TABLE IF NOT EXISTS public.metricas_consultas (
    id              BIGSERIAL       PRIMARY KEY,
    endpoint        VARCHAR(200)    NOT NULL,
    duracion_ms     NUMERIC(10,3)   NOT NULL,
    filas_devueltas INTEGER         NOT NULL DEFAULT 0,
    cache_hit       BOOLEAN         NOT NULL DEFAULT false,
    registrado_en   TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_metricas_endpoint    ON public.metricas_consultas (endpoint);
CREATE INDEX IF NOT EXISTS idx_metricas_registrado  ON public.metricas_consultas (registrado_en DESC);

-- Tabla de sesiones de usuario (simula actividad de conexiones)
CREATE TABLE IF NOT EXISTS public.sesiones (
    id              BIGSERIAL       PRIMARY KEY,
    usuario_id      INTEGER         NOT NULL,
    ip_origen       INET            NOT NULL,
    inicio          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    fin             TIMESTAMPTZ,
    activa          BOOLEAN         NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_sesiones_usuario  ON public.sesiones (usuario_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_activa   ON public.sesiones (activa) WHERE activa;

-- ── Datos de prueba ───────────────────────────────────────────────────────────

INSERT INTO public.eventos (tipo, severidad, origen, usuario_id, payload, procesado, creado_en)
SELECT
    (ARRAY['login','compra','error','alerta','logout','timeout','retry'])[ceil(random()*7)],
    (ARRAY['info','info','info','warn','warn','error','critical'])[ceil(random()*7)],
    (ARRAY['api-gateway','auth-service','payment-service','sensor-01','sensor-02','worker-etl'])[ceil(random()*6)],
    CASE WHEN random() > 0.2 THEN (random()*500+1)::INT ELSE NULL END,
    jsonb_build_object(
        'latencia_ms', round((random()*2000)::numeric, 2),
        'codigo',      (ARRAY[200,200,200,400,401,403,500,503])[ceil(random()*8)],
        'region',      (ARRAY['eu-west','us-east','ap-south'])[ceil(random()*3)]
    ),
    random() > 0.3,
    now() - (random() * interval '7 days')
FROM generate_series(1, 2000);

INSERT INTO public.metricas_consultas (endpoint, duracion_ms, filas_devueltas, cache_hit, registrado_en)
SELECT
    (ARRAY[
        '/api/v1/pedidos','/api/v1/usuarios','/api/v1/eventos',
        '/api/v1/dashboard','/api/v1/reportes','/health'
    ])[ceil(random()*6)],
    round((random()*1500 + 5)::numeric, 3),
    (random()*1000)::INT,
    random() > 0.4,
    now() - (random() * interval '24 hours')
FROM generate_series(1, 1000);

INSERT INTO public.sesiones (usuario_id, ip_origen, inicio, fin, activa)
SELECT
    (random()*200+1)::INT,
    ('192.168.' || (random()*255)::INT || '.' || (random()*255)::INT)::INET,
    now() - (random() * interval '2 hours'),
    CASE WHEN random() > 0.3 THEN now() - (random() * interval '30 minutes') ELSE NULL END,
    random() > 0.3
FROM generate_series(1, 300);

-- ── Vistas de diagnóstico ─────────────────────────────────────────────────────

-- Consultas largas activas (más de 5 minutos)
CREATE OR REPLACE VIEW monitoring.long_running_queries AS
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    wait_event_type,
    wait_event,
    query_start,
    EXTRACT(EPOCH FROM (now() - query_start)) AS duration_seconds,
    left(query, 200) AS query_preview
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < now() - interval '5 minutes'
  AND pid <> pg_backend_pid()
ORDER BY duration_seconds DESC;

-- Bloqueos activos: quién bloquea a quién
CREATE OR REPLACE VIEW monitoring.blocking_queries AS
SELECT
    blocked.pid          AS blocked_pid,
    blocked.usename      AS blocked_user,
    blocked.query        AS blocked_query,
    blocking.pid         AS blocking_pid,
    blocking.usename     AS blocking_user,
    blocking.query       AS blocking_query,
    EXTRACT(EPOCH FROM (now() - blocked.query_start)) AS wait_seconds
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock';

-- Vista de resumen de eventos por tipo y severidad (útil en dashboards Grafana)
CREATE OR REPLACE VIEW monitoring.eventos_resumen AS
SELECT
    tipo,
    severidad,
    origen,
    count(*)                                            AS total,
    count(*) FILTER (WHERE NOT procesado)               AS pendientes,
    round(avg((payload->>'latencia_ms')::NUMERIC), 2)   AS latencia_media_ms,
    max(creado_en)                                      AS ultimo_evento
FROM public.eventos
GROUP BY tipo, severidad, origen
ORDER BY total DESC;

-- Vista de tasa de error por origen (para alertas Prometheus/Grafana)
CREATE OR REPLACE VIEW monitoring.tasa_errores_por_origen AS
SELECT
    origen,
    count(*)                                                    AS total_eventos,
    count(*) FILTER (WHERE severidad IN ('error','critical'))   AS total_errores,
    round(
        count(*) FILTER (WHERE severidad IN ('error','critical'))
        * 100.0 / NULLIF(count(*), 0), 2
    )                                                           AS pct_error,
    max(creado_en) FILTER (WHERE severidad IN ('error','critical'))
                                                                AS ultimo_error
FROM public.eventos
GROUP BY origen
ORDER BY pct_error DESC NULLS LAST;

-- Vista de rendimiento de endpoints (latencia percentil)
CREATE OR REPLACE VIEW monitoring.rendimiento_endpoints AS
SELECT
    endpoint,
    count(*)                                            AS peticiones,
    round(avg(duracion_ms)::numeric, 2)                 AS latencia_media_ms,
    round(percentile_cont(0.50) WITHIN GROUP
        (ORDER BY duracion_ms)::numeric, 2)             AS p50_ms,
    round(percentile_cont(0.95) WITHIN GROUP
        (ORDER BY duracion_ms)::numeric, 2)             AS p95_ms,
    round(percentile_cont(0.99) WITHIN GROUP
        (ORDER BY duracion_ms)::numeric, 2)             AS p99_ms,
    count(*) FILTER (WHERE cache_hit)                   AS cache_hits,
    round(count(*) FILTER (WHERE cache_hit)
        * 100.0 / NULLIF(count(*), 0), 1)               AS pct_cache_hit
FROM public.metricas_consultas
GROUP BY endpoint
ORDER BY latencia_media_ms DESC;

-- Dar acceso al exporter a todas las vistas
GRANT SELECT ON monitoring.long_running_queries     TO postgres_exporter;
GRANT SELECT ON monitoring.blocking_queries         TO postgres_exporter;
GRANT SELECT ON monitoring.eventos_resumen          TO postgres_exporter;
GRANT SELECT ON monitoring.tasa_errores_por_origen  TO postgres_exporter;
GRANT SELECT ON monitoring.rendimiento_endpoints    TO postgres_exporter;
GRANT SELECT ON public.eventos                      TO postgres_exporter;
GRANT SELECT ON public.metricas_consultas           TO postgres_exporter;
GRANT SELECT ON public.sesiones                     TO postgres_exporter;

DO $$
BEGIN
  RAISE NOTICE 'Configuración de monitorización completada correctamente.';
  RAISE NOTICE 'Tablas creadas: eventos (2000 filas), metricas_consultas (1000), sesiones (300)';
END
$$;
