-- =============================================================
-- init_lab.sql
-- Inicializa el laboratorio de optimización:
--   · extensiones: pg_stat_statements, hypopg, pgcrypto
--   · tabla pedidos (1 M filas) con el esquema exacto del README
--   · tabla clientes (100 k filas) para prácticas de JOIN
--   · tabla pedidos_part (particionada) para §7
--   · base pgbench_test lista para pgbench
-- =============================================================

\c dwh

-- ── Extensiones ───────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS hypopg;
CREATE EXTENSION IF NOT EXISTS pgcrypto;     -- gen_random_uuid()

-- ── Tabla pedidos (caso de estudio del README) ────────────────
CREATE TABLE IF NOT EXISTS pedidos (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id      INTEGER     NOT NULL,
    fecha_creacion  TIMESTAMP   NOT NULL DEFAULT now(),
    estado          VARCHAR(20) NOT NULL
                        CHECK (estado IN ('pendiente','procesado','cancelado')),
    metadatos_pago  JSONB
);

-- Insertar 1 millón de filas (igual que en el README)
DO $$
BEGIN
    IF (SELECT count(*) FROM pedidos) < 100000 THEN
        INSERT INTO pedidos (cliente_id, fecha_creacion, estado, metadatos_pago)
        SELECT
            (random() * 100000)::INT,
            now() - (random() * 730)::INT * INTERVAL '1 day',
            (ARRAY['pendiente','procesado','cancelado'])[ceil(random()*3)],
            jsonb_build_object(
                'pasarela', (ARRAY['stripe','redsys','paypal'])[ceil(random()*3)],
                'tarjeta',  substring(md5(random()::text), 1, 4) || '****',
                'importe',  round((random() * 500 + 10)::numeric, 2),
                'moneda',   (ARRAY['EUR','USD','GBP'])[ceil(random()*3)]
            )
        FROM generate_series(1, 1000000);

        ANALYZE pedidos;
        RAISE NOTICE 'pedidos: 1.000.000 filas insertadas';
    ELSE
        RAISE NOTICE 'pedidos: ya tiene datos, omitiendo INSERT';
    END IF;
END;
$$;

-- ── Tabla clientes (para prácticas de JOIN en §8) ─────────────
CREATE TABLE IF NOT EXISTS clientes (
    id      INTEGER PRIMARY KEY,
    nombre  VARCHAR(100),
    pais    VARCHAR(50)
);

INSERT INTO clientes
SELECT i, 'Cliente ' || i, 'ES'
FROM generate_series(1, 100000) i
ON CONFLICT DO NOTHING;

ANALYZE clientes;
RAISE NOTICE 'clientes: 100.000 filas listas';

-- ── Tabla particionada (para §7) ──────────────────────────────
CREATE TABLE IF NOT EXISTS pedidos_part (
    id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    cliente_id      INTEGER     NOT NULL,
    fecha_creacion  TIMESTAMP   NOT NULL DEFAULT now(),
    estado          VARCHAR(20) NOT NULL
                        CHECK (estado IN ('pendiente','procesado','cancelado')),
    metadatos_pago  JSONB
) PARTITION BY RANGE (fecha_creacion);

-- Particiones trimestrales 2025
DO $$
DECLARE
    q   INT;
    ini DATE;
    fin DATE;
    nom TEXT;
BEGIN
    FOR q IN 1..4 LOOP
        ini := make_date(2025, (q-1)*3+1, 1);
        fin := ini + INTERVAL '3 months';
        nom := format('pedidos_2025_q%s', q);
        IF NOT EXISTS (
            SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE c.relname=nom AND n.nspname='public'
        ) THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF pedidos_part
                 FOR VALUES FROM (%L) TO (%L)', nom, ini, fin);
        END IF;
    END LOOP;
END;
$$;

-- Insertar muestra para prácticas de particionado
INSERT INTO pedidos_part (cliente_id, fecha_creacion, estado, metadatos_pago)
SELECT
    (random() * 100000)::INT,
    make_date(2025, (random()*11+1)::INT, (random()*27+1)::INT)::TIMESTAMP,
    (ARRAY['pendiente','procesado','cancelado'])[ceil(random()*3)],
    jsonb_build_object('importe', round((random()*500+10)::numeric,2))
FROM generate_series(1, 100000)
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS ON pedidos_part(cliente_id);
CREATE INDEX IF NOT EXISTS ON pedidos_part(estado);
ANALYZE pedidos_part;
RAISE NOTICE 'pedidos_part: 100.000 filas distribuidas en 4 particiones';

-- ── BD pgbench_test (para §10) ────────────────────────────────
SELECT 'CREATE DATABASE pgbench_test'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'pgbench_test'
)\gexec

RAISE NOTICE 'BD pgbench_test creada (inicializar con: pgbench -i -s 10 pgbench_test)';

-- ── Resetear pg_stat_statements para empezar limpio ──────────
SELECT pg_stat_statements_reset();

DO $$ BEGIN
    RAISE NOTICE '✓ Laboratorio de optimización listo';
    RAISE NOTICE '  pedidos:      1.000.000 filas';
    RAISE NOTICE '  clientes:       100.000 filas';
    RAISE NOTICE '  pedidos_part:   100.000 filas (4 particiones Q1-Q4 2025)';
END $$;
