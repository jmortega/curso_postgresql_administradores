-- ============================================================================
-- 02_pedidos_lab.sql
-- Datos y extensiones para las prácticas de la guía
-- "PostgreSQL: Optimización, Tuning y Pruebas de Carga".
-- Se ejecuta automáticamente tras init.sql (orden alfabético en
-- docker-entrypoint-initdb.d) al crear el contenedor por primera vez.
-- ============================================================================

-- Extensiones necesarias para las prácticas de índices hipotéticos
CREATE EXTENSION IF NOT EXISTS hypopg;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ── Tabla pedidos (caso de estudio de la guía de optimización) ───────────────
CREATE TABLE IF NOT EXISTS public.pedidos (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id      INTEGER       NOT NULL,
    fecha_creacion  TIMESTAMP     NOT NULL DEFAULT now(),
    estado          VARCHAR(20)   NOT NULL
                        CHECK (estado IN ('pendiente','procesado','cancelado')),
    metadatos_pago  JSONB
);

-- Poblar con 1 millón de filas (tarda ~30-60s, ver start_period del healthcheck)
INSERT INTO public.pedidos (cliente_id, fecha_creacion, estado, metadatos_pago)
SELECT
    (random() * 100000)::INT,
    now() - (random() * 730)::INT * INTERVAL '1 day',
    (ARRAY['pendiente','procesado','cancelado'])[ceil(random()*3)],
    jsonb_build_object(
        'pasarela',  (ARRAY['stripe','redsys','paypal'])[ceil(random()*3)],
        'tarjeta',   substring(md5(random()::text), 1, 4) || '****',
        'importe',   round((random() * 500 + 10)::numeric, 2),
        'moneda',    (ARRAY['EUR','USD','GBP'])[ceil(random()*3)]
    )
FROM generate_series(1, 1000000);

ANALYZE public.pedidos;

-- Tabla clientes, usada en las prácticas de joins
CREATE TABLE IF NOT EXISTS public.clientes (
    id      SERIAL PRIMARY KEY,
    nombre  VARCHAR(100) NOT NULL,
    pais    VARCHAR(50)  NOT NULL
);

INSERT INTO public.clientes (nombre, pais)
SELECT
    'Cliente ' || g,
    (ARRAY['España','Francia','Alemania','Portugal','Italia'])[ceil(random()*5)]
FROM generate_series(1, 100000) g;

ANALYZE public.clientes;

-- Acceso de solo lectura para el exporter (reutiliza el rol creado en init.sql)
GRANT SELECT ON public.pedidos  TO postgres_exporter;
GRANT SELECT ON public.clientes TO postgres_exporter;

DO $$
BEGIN
  RAISE NOTICE 'Laboratorio de tuning listo: pedidos (1.000.000 filas), clientes (100.000 filas)';
  RAISE NOTICE 'Extensión hypopg disponible para índices hipotéticos';
END
$$;
