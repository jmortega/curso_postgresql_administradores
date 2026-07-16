-- =============================================================
-- init.sql
-- Ejecutado automáticamente al crear el contenedor.
-- Activa la extensión pgvector y prepara los esquemas.
-- =============================================================

-- Activar pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Verificar versión instalada
DO $$
DECLARE
    v TEXT;
BEGIN
    SELECT extversion INTO v FROM pg_extension WHERE extname = 'vector';
    RAISE NOTICE 'pgvector activado: v%', v;
END;
$$;

-- Esquemas del laboratorio
CREATE SCHEMA IF NOT EXISTS lab;

-- ── Tabla 1: documentos con embeddings de texto (dim=384) ─────
CREATE TABLE IF NOT EXISTS lab.documentos (
    id          SERIAL PRIMARY KEY,
    titulo      TEXT          NOT NULL,
    contenido   TEXT          NOT NULL,
    categoria   VARCHAR(50),
    embedding   vector(384),
    creado_en   TIMESTAMPTZ   DEFAULT now()
);

-- ── Tabla 2: productos con embeddings semánticos (dim=384) ────
CREATE TABLE IF NOT EXISTS lab.productos (
    id          SERIAL PRIMARY KEY,
    nombre      TEXT          NOT NULL,
    descripcion TEXT          NOT NULL,
    precio      NUMERIC(10,2),
    categoria   VARCHAR(50),
    embedding   vector(384),
    creado_en   TIMESTAMPTZ   DEFAULT now()
);

-- ── Tabla 3: usuarios con embeddings de perfil (dim=128) ──────
CREATE TABLE IF NOT EXISTS lab.usuarios (
    id          SERIAL PRIMARY KEY,
    nombre      TEXT          NOT NULL,
    intereses   TEXT[],
    embedding   vector(128),
    creado_en   TIMESTAMPTZ   DEFAULT now()
);

-- ── Tabla 4: benchmark — distancias y métricas ────────────────
CREATE TABLE IF NOT EXISTS lab.benchmark_resultados (
    id              SERIAL PRIMARY KEY,
    operacion       TEXT,
    n_vectores      INT,
    dimensiones     INT,
    tipo_indice     TEXT,
    tiempo_ms       NUMERIC(12,4),
    ejecutado_en    TIMESTAMPTZ DEFAULT now()
);

RAISE NOTICE '✓ Esquemas y tablas del laboratorio creados';
