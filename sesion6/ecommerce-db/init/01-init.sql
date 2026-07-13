-- ============================================================
-- ecommercedb — schema + datos de prueba
-- Se ejecuta automáticamente al arrancar el contenedor de Postgres
-- (docker-entrypoint-initdb.d solo corre en la primera inicialización
-- del volumen de datos)
-- ============================================================

-- ── Tablas ────────────────────────────────────────────────────

CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE customers (
    id         SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name  VARCHAR(100) NOT NULL,
    email      VARCHAR(150) NOT NULL UNIQUE,
    phone      VARCHAR(30),
    city       VARCHAR(100),
    country    VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    sku         VARCHAR(50) NOT NULL UNIQUE,
    name        VARCHAR(200) NOT NULL,
    description TEXT,
    category_id INTEGER REFERENCES categories(id),
    price       NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    stock       INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    status      VARCHAR(20) NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','paid','shipped','delivered','cancelled')),
    order_date  TIMESTAMP NOT NULL DEFAULT now(),
    total       NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE TABLE order_items (
    id         SERIAL PRIMARY KEY,
    order_id   INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity   INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL
);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- ── Datos de prueba: categories ──────────────────────────────

INSERT INTO categories (name, description) VALUES
    ('Electronics',  'Phones, laptops, gadgets and accessories'),
    ('Books',        'Fiction, non-fiction and technical books'),
    ('Clothing',     'Apparel for men, women and children'),
    ('Home & Garden','Furniture, decor and gardening tools'),
    ('Sports',       'Sporting goods and outdoor equipment');

-- ── Datos de prueba: customers ───────────────────────────────

INSERT INTO customers (first_name, last_name, email, phone, city, country) VALUES
    ('Maria',   'Garcia',    'maria.garcia@example.com',   '+34600111222', 'Madrid',    'Spain'),
    ('John',    'Smith',     'john.smith@example.com',     '+44700222333', 'London',    'United Kingdom'),
    ('Sophie',  'Martin',    'sophie.martin@example.com',  '+33611333444', 'Paris',     'France'),
    ('Luca',    'Rossi',     'luca.rossi@example.com',     '+39320444555', 'Rome',      'Italy'),
    ('Anna',    'Müller',    'anna.muller@example.com',    '+49150555666', 'Berlin',    'Germany'),
    ('Carlos',  'Fernandez', 'carlos.fernandez@example.com','+34611666777','Barcelona', 'Spain'),
    ('Emma',    'Johnson',   'emma.johnson@example.com',   '+1202777888',  'New York',  'USA'),
    ('Lucas',   'Silva',     'lucas.silva@example.com',    '+5511988999000','Sao Paulo','Brazil'),
    ('Mia',     'Wagner',    'mia.wagner@example.com',     '+49160888999', 'Munich',    'Germany'),
    ('Noah',    'Brown',     'noah.brown@example.com',     '+1305999000',  'Miami',     'USA');

-- ── Datos de prueba: products ─────────────────────────────────

INSERT INTO products (sku, name, description, category_id, price, stock) VALUES
    ('ELEC-001', 'Wireless Mouse',          'Ergonomic 2.4GHz wireless mouse',          1, 19.99,  150),
    ('ELEC-002', 'Mechanical Keyboard',     'RGB backlit mechanical keyboard',          1, 79.99,  80),
    ('ELEC-003', '27" 4K Monitor',          'IPS 4K UHD monitor with HDR',              1, 349.00, 25),
    ('ELEC-004', 'Noise Cancelling Headphones','Over-ear Bluetooth headphones',         1, 129.50, 60),
    ('ELEC-005', 'Smartphone X12',          '128GB, 6.5" AMOLED display',               1, 599.00, 40),
    ('BOOK-001', 'The Pragmatic Programmer','Software craftsmanship classic',           2, 34.90,  100),
    ('BOOK-002', 'Clean Code',              'A Handbook of Agile Software Craftsmanship',2, 29.95, 75),
    ('BOOK-003', 'Dune',                    'Sci-fi novel by Frank Herbert',             2, 14.50,  200),
    ('CLOT-001', 'Cotton T-Shirt',          'Unisex 100% cotton t-shirt',                3, 12.00,  300),
    ('CLOT-002', 'Denim Jacket',            'Classic blue denim jacket',                 3, 59.99,  90),
    ('CLOT-003', 'Running Shoes',           'Lightweight breathable running shoes',      3, 89.00,  120),
    ('HOME-001', 'Office Chair',            'Ergonomic mesh office chair',               4, 149.00, 35),
    ('HOME-002', 'LED Desk Lamp',           'Adjustable LED lamp with USB charging',     4, 24.99,  140),
    ('HOME-003', 'Indoor Plant Pot Set',    'Set of 3 ceramic plant pots',                4, 22.50,  85),
    ('SPRT-001', 'Yoga Mat',                'Non-slip eco-friendly yoga mat',            5, 18.75,  160),
    ('SPRT-002', 'Adjustable Dumbbells',    '2x10kg adjustable dumbbell set',            5, 119.00, 30),
    ('SPRT-003', 'Cycling Helmet',          'Lightweight ventilated cycling helmet',     5, 45.00,  55);

-- ── Datos de prueba: orders + order_items ────────────────────

-- Pedido 1: Maria compra ratón + teclado
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (1, 'delivered', now() - interval '20 days', 99.98);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1, 1, 1, 19.99),
    (1, 2, 1, 79.99);

-- Pedido 2: John compra monitor
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (2, 'shipped', now() - interval '10 days', 349.00);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (2, 3, 1, 349.00);

-- Pedido 3: Sophie compra libros
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (3, 'delivered', now() - interval '35 days', 79.35);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (3, 6, 1, 34.90),
    (3, 7, 1, 29.95),
    (3, 8, 1, 14.50);

-- Pedido 4: Luca compra ropa
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (4, 'paid', now() - interval '3 days', 161.99);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (4, 9, 2, 12.00),
    (4, 10, 1, 59.99),
    (4, 11, 1, 89.00);

-- Pedido 5: Anna compra mobiliario
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (5, 'pending', now() - interval '1 days', 196.48);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (5, 12, 1, 149.00),
    (5, 13, 1, 24.99),
    (5, 14, 1, 22.50);

-- Pedido 6: Carlos compra deporte
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (6, 'delivered', now() - interval '50 days', 182.75);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (6, 15, 1, 18.75),
    (6, 16, 1, 119.00),
    (6, 17, 1, 45.00);

-- Pedido 7: Emma compra electronica + ropa
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (7, 'cancelled', now() - interval '15 days', 729.50);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (7, 5, 1, 599.00),
    (7, 4, 1, 129.50),
    (7, 9, 1, 12.00);

-- Pedido 8: Lucas compra accesorios
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (8, 'delivered', now() - interval '7 days', 39.99);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (8, 1, 2, 19.99);

-- Pedido 9: Mia compra mas libros + plantas
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (9, 'shipped', now() - interval '4 days', 51.95);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (9, 7, 1, 29.95),
    (9, 14, 1, 22.50);

-- Pedido 10: Noah compra deporte
INSERT INTO orders (customer_id, status, order_date, total) VALUES
    (10, 'pending', now(), 163.75);
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (10, 15, 1, 18.75),
    (10, 16, 1, 119.00),
    (10, 9, 2, 12.00);

-- ── Verificación rápida ───────────────────────────────────────
-- (solo informativo, no afecta a la carga de datos)
DO $$
BEGIN
    RAISE NOTICE 'ecommercedb inicializada: % categorías, % clientes, % productos, % pedidos',
        (SELECT count(*) FROM categories),
        (SELECT count(*) FROM customers),
        (SELECT count(*) FROM products),
        (SELECT count(*) FROM orders);
END $$;
