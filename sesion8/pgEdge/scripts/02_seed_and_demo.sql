-- =============================================================
-- scripts/02_seed_and_demo.sql
-- Datos de prueba y demostración activo-activo
--
-- Ejecutar en n1 después del esquema:
--   PGPASSWORD=Admin_Lab_2026 psql \
--     -h localhost -p 6432 -U admin ecommerce_db \
--     -f scripts/02_seed_and_demo.sql
-- =============================================================

-- ── Insertar productos (desde n1, EU) ─────────────────────────
INSERT INTO products (sku, name, price_eur, stock, category_id, origin_region)
SELECT 'TECH-001', 'Laptop Pro 16"', 1299.99, 50,
       (SELECT id FROM categories WHERE name='Electrónica'), 1
WHERE NOT EXISTS (SELECT 1 FROM products WHERE sku='TECH-001');

INSERT INTO products (sku, name, price_eur, stock, category_id, origin_region)
SELECT 'SPORT-01', 'Running Shoes X', 89.99, 120,
       (SELECT id FROM categories WHERE name='Deportes'), 2
WHERE NOT EXISTS (SELECT 1 FROM products WHERE sku='SPORT-01');

INSERT INTO products (sku, name, price_eur, stock, category_id, origin_region)
SELECT 'BOOK-001', 'Distributed PostgreSQL', 49.99, 30,
       (SELECT id FROM categories WHERE name='Libros'), 3
WHERE NOT EXISTS (SELECT 1 FROM products WHERE sku='BOOK-001');

-- ── Insertar clientes por región ─────────────────────────────
INSERT INTO customers (email, name, region_id)
VALUES ('alice@eu.example.com', 'Alice Müller',   1)
ON CONFLICT (email) DO NOTHING;

INSERT INTO customers (email, name, region_id)
VALUES ('bob@us.example.com',   'Bob Johnson',    2)
ON CONFLICT (email) DO NOTHING;

INSERT INTO customers (email, name, region_id)
VALUES ('diana@asia.example.sg','Diana Tan',       3)
ON CONFLICT (email) DO NOTHING;

-- ── Registro en tabla de prueba desde n1 ─────────────────────
INSERT INTO replication_test (node_name, region, msg)
VALUES ('n1', 'eu-west-1',
        'Escritura desde n1 (EU) — ts: ' || now()::text);

\echo ''
\echo '✓ Datos insertados en n1'
\echo '══════════════════════════════════════════════════════════'
