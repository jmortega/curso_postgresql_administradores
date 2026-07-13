-- =============================================================
-- init_lab.sql
-- Inicializa el laboratorio de mantenimiento:
--   · pg_cron en postgres y dwh
--   · tabla pedidos con 100 k filas + bloat simulado
--   · tablas de log para backups y sondas
-- =============================================================

\c postgres
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Crear BD dwh si no existe
SELECT 'CREATE DATABASE dwh'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dwh')\gexec

\c dwh
-- NOTA: pg_cron solo puede instalarse en la BD "postgres" (shared_preload_libraries)
-- Se usa desde postgres para programar jobs sobre dwh con database := 'dwh'
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Tabla principal para prácticas de vacuum / bloat ─────────
CREATE TABLE IF NOT EXISTS pedidos (
    id              BIGSERIAL     PRIMARY KEY,
    cliente_id      INTEGER       NOT NULL,
    fecha_creacion  TIMESTAMP     NOT NULL DEFAULT now(),
    estado          VARCHAR(20)   NOT NULL DEFAULT 'pendiente'
                        CHECK (estado IN ('pendiente','procesado','cancelado')),
    importe         NUMERIC(10,2),
    metadatos       JSONB
);

INSERT INTO pedidos (cliente_id, estado, importe, metadatos)
SELECT
    (random() * 10000 + 1)::INT,
    (ARRAY['pendiente','procesado','cancelado'])[ceil(random()*3)],
    round((random() * 990 + 10)::numeric, 2),
    jsonb_build_object('canal', (ARRAY['web','app','tel'])[ceil(random()*3)])
FROM generate_series(1, 100000)
ON CONFLICT DO NOTHING;

-- Simular bloat: actualizar y borrar filas sin vacuum
UPDATE pedidos SET estado = 'procesado'
WHERE ctid IN (SELECT ctid FROM pedidos WHERE estado='pendiente' LIMIT 20000);

DELETE FROM pedidos
WHERE ctid IN (SELECT ctid FROM pedidos WHERE estado='cancelado' LIMIT 15000);

-- ── Índices para las prácticas ────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente   ON pedidos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado    ON pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha     ON pedidos(fecha_creacion);

-- ── Tabla de log de backups ───────────────────────────────────
CREATE TABLE IF NOT EXISTS backup_log (
    id          BIGSERIAL PRIMARY KEY,
    tipo        VARCHAR(20),
    estado      VARCHAR(20),
    base_datos  TEXT,
    destino     TEXT,
    tamanio     TEXT,
    inicio      TIMESTAMPTZ DEFAULT now(),
    fin         TIMESTAMPTZ,
    mensaje     TEXT
);

-- ── Tabla de log de sondas ────────────────────────────────────
CREATE TABLE IF NOT EXISTS probe_log (
    id      BIGSERIAL PRIMARY KEY,
    tipo    VARCHAR(20),
    estado  VARCHAR(10),
    detalle TEXT,
    ts      TIMESTAMPTZ DEFAULT now()
);

DO $$ BEGIN
    RAISE NOTICE '✓ Lab inicializado — pedidos: %', (SELECT count(*) FROM pedidos);
END $$;
