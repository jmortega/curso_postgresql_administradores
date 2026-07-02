-- =============================================================
-- init_db.sql
-- Se ejecuta automáticamente al crear el contenedor.
-- Activa todas las extensiones en la BD 'postgres'.
-- Los scripts Python crean sus propias BDs (pgvector_db,
-- postgis_geo_db, app_logs_db) cuando los ejecutas.
-- =============================================================

-- ── Extensiones de monitorización (pgmon_manager) ────────────
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_wait_sampling;

-- ── pgvector (pgvector_manager lo instala en pgvector_db,
--   pero lo activamos también en postgres por si acaso) ───────
CREATE EXTENSION IF NOT EXISTS vector;

-- ── PostGIS (postgis_manager lo instala en postgis_geo_db,
--   pero lo activamos también en postgres) ────────────────────
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Confirmación
DO $$ BEGIN
    RAISE NOTICE '✓ Extensiones activadas: pg_stat_statements, pg_wait_sampling, vector, postgis';
END $$;
