-- =============================================================
-- scripts/pg/02_create_pg17.sql
-- Preparar la instancia PG17 para recibir la migración
-- Se ejecuta al arrancar pg17 — crea la BD destino vacía.
-- =============================================================

-- La BD tienda_v2 ya existe (creada por POSTGRES_DB en el compose)
\c tienda_v2

-- Crear extensiones que usará el esquema migrado
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Marcar esta BD como destino (metadato de control)
CREATE TABLE IF NOT EXISTS _migracion_control (
    clave   TEXT PRIMARY KEY,
    valor   TEXT,
    ts      TIMESTAMPTZ DEFAULT now()
);

INSERT INTO _migracion_control (clave, valor) VALUES
    ('origen',  'pg14:tienda_v1'),
    ('destino', 'pg17:tienda_v2'),
    ('estado',  'pendiente');

\echo '✓ PG17 — tienda_v2 preparada para recibir migración'
