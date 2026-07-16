-- =============================================================
-- scripts/01_schema.sql
-- Esquema e-commerce para clúster pgEdge multirregión
--
-- Ejecutar en n1 (se replica a n2 y n3 mediante Spock autoddl):
--   PGPASSWORD=Admin_Lab_2026 psql \
--     -h localhost -p 6432 -U admin ecommerce_db \
--     -f scripts/01_schema.sql
--
-- NOTA sobre IDs distribuidos:
--   Se usa UUID con gen_random_uuid() que funciona en todos los
--   nodos sin configuración extra.  UUID garantiza unicidad global
--   porque cada nodo genera valores en espacios de probabilidad
--   estadísticamente independientes.
--   (snowflake.nextval() requiere configurar snowflake.node por
--   nodo vía ALTER SYSTEM, lo que escapa al alcance de este lab.)
-- =============================================================

-- Activar pgcrypto si gen_random_uuid no está disponible nativamente
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Catálogo de regiones ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS regions (
    id          SMALLINT      PRIMARY KEY,
    code        VARCHAR(30)   NOT NULL UNIQUE,
    name        VARCHAR(100)  NOT NULL,
    pg_node     VARCHAR(10),
    timezone    TEXT          NOT NULL DEFAULT 'UTC'
);

INSERT INTO regions VALUES
    (1, 'eu-west-1',      'Europa (Irlanda)',          'n1', 'Europe/Dublin'),
    (2, 'us-east-1',      'EE.UU. Este (Virginia)',    'n2', 'America/New_York'),
    (3, 'ap-southeast-1', 'Asia-Pacífico (Singapur)',  'n3', 'Asia/Singapore')
ON CONFLICT DO NOTHING;

-- ── Clientes ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
    id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT          NOT NULL UNIQUE,
    name        TEXT          NOT NULL,
    region_id   SMALLINT      NOT NULL REFERENCES regions(id),
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ── Categorías de producto ────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
    id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT          NOT NULL UNIQUE,
    parent_id   UUID          REFERENCES categories(id)
);

INSERT INTO categories (name) VALUES
    ('Electrónica'), ('Ropa'), ('Hogar'), ('Deportes'), ('Libros')
ON CONFLICT DO NOTHING;

-- ── Productos ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    sku             VARCHAR(50)   NOT NULL UNIQUE,
    name            TEXT          NOT NULL,
    price_eur       NUMERIC(12,2) NOT NULL CHECK (price_eur >= 0),
    stock           INT           NOT NULL DEFAULT 0 CHECK (stock >= 0),
    category_id     UUID          REFERENCES categories(id),
    origin_region   SMALLINT      REFERENCES regions(id),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ── Pedidos ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID          NOT NULL REFERENCES customers(id),
    status          VARCHAR(20)   NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','confirmed','shipped',
                                          'delivered','cancelled')),
    total_eur       NUMERIC(12,2) NOT NULL CHECK (total_eur >= 0),
    origin_node     VARCHAR(10)   NOT NULL,
    origin_region   SMALLINT      REFERENCES regions(id),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ── Líneas de pedido ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_items (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID          NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id      UUID          NOT NULL REFERENCES products(id),
    quantity        INT           NOT NULL CHECK (quantity > 0),
    unit_price_eur  NUMERIC(12,2) NOT NULL
);

-- ── Tabla de prueba de replicación ───────────────────────────
CREATE TABLE IF NOT EXISTS replication_test (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    node_name   TEXT        NOT NULL,
    region      TEXT        NOT NULL,
    msg         TEXT        NOT NULL,
    ts          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Índices ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_customers_region   ON customers(region_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer    ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status      ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_node        ON orders(origin_node);
CREATE INDEX IF NOT EXISTS idx_items_order        ON order_items(order_id);

-- ── Permisos para app_user (si existe) ───────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
    GRANT USAGE ON SCHEMA public TO app_user;
    GRANT SELECT, INSERT, UPDATE, DELETE
      ON customers, products, orders, order_items, replication_test TO app_user;
    GRANT SELECT ON regions, categories TO app_user;
  END IF;
END $$;

\echo ''
\echo '✓ Esquema ecommerce_db creado (IDs con gen_random_uuid)'
\echo '  Tablas: regions, categories, customers, products, orders, order_items, replication_test'
\echo ''
\echo 'Espera 10-15 s y verifica que el DDL llegó a n2/n3:'
\echo '  PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db -c "\dt"'
