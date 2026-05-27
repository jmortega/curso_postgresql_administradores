-- =============================================
-- Script de inicialización del laboratorio
-- Se ejecuta automáticamente al crear el volumen
-- =============================================

-- Activar extensiones útiles para el curso
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Base de datos de prácticas ─────────────────────────────
-- (ya creada por POSTGRES_DB; añadimos objetos de práctica)

-- Usuario de solo lectura para monitorización
CREATE USER monitor WITH PASSWORD 'monitor123';
GRANT pg_monitor TO monitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitor;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO monitor;

-- Usuario de aplicación
CREATE USER appuser WITH PASSWORD 'app123';
GRANT CONNECT ON DATABASE labdb TO appuser;

-- ── Esquema de ejemplo: tienda online ─────────────────────
CREATE SCHEMA IF NOT EXISTS shop;
GRANT USAGE ON SCHEMA shop TO appuser;

CREATE TABLE shop.customers (
    id          BIGSERIAL PRIMARY KEY,
    email       TEXT UNIQUE NOT NULL,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE shop.products (
    id          BIGSERIAL PRIMARY KEY,
    sku         TEXT UNIQUE NOT NULL,
    name        TEXT NOT NULL,
    price       NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    stock       INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE shop.orders (
    id           BIGSERIAL PRIMARY KEY,
    customer_id  BIGINT NOT NULL REFERENCES shop.customers(id),
    status       TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','paid','shipped','cancelled')),
    total        NUMERIC(12,2),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE shop.order_items (
    id          BIGSERIAL PRIMARY KEY,
    order_id    BIGINT NOT NULL REFERENCES shop.orders(id) ON DELETE CASCADE,
    product_id  BIGINT NOT NULL REFERENCES shop.products(id),
    qty         INT NOT NULL CHECK (qty > 0),
    unit_price  NUMERIC(10,2) NOT NULL
);

CREATE INDEX idx_orders_customer   ON shop.orders(customer_id);
CREATE INDEX idx_orders_status     ON shop.orders(status);
CREATE INDEX idx_order_items_order ON shop.order_items(order_id);

-- Datos de ejemplo
INSERT INTO shop.customers (email, name)
SELECT
    'user' || n || '@example.com',
    'Customer ' || n
FROM generate_series(1, 500) AS n;

INSERT INTO shop.products (sku, name, price, stock)
SELECT
    'SKU-' || lpad(n::text, 5, '0'),
    'Product ' || n,
    round((random() * 200 + 5)::numeric, 2),
    floor(random() * 1000)::int
FROM generate_series(1, 200) AS n;

INSERT INTO shop.orders (customer_id, status, total, created_at)
SELECT
    floor(random() * 500 + 1)::bigint,
    (ARRAY['pending','paid','shipped','cancelled'])[floor(random()*4+1)],
    round((random()*500+10)::numeric, 2),
    now() - (random() * interval '365 days')
FROM generate_series(1, 2000);

INSERT INTO shop.order_items (order_id, product_id, qty, unit_price)
SELECT
    o.id,
    floor(random() * 200 + 1)::bigint,
    floor(random() * 5 + 1)::int,
    round((random() * 200 + 5)::numeric, 2)
FROM shop.orders o
CROSS JOIN generate_series(1, floor(random()*4+1)::int);

-- Estadísticas actualizadas
ANALYZE shop.customers, shop.products, shop.orders, shop.order_items;

-- Mensaje final
DO $$
BEGIN
    RAISE NOTICE '✅ Laboratorio PostgreSQL inicializado correctamente.';
END $$;
