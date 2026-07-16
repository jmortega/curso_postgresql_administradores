-- =============================================================
-- scripts/pg/01_seed_pg14.sql
-- Datos de prueba en PostgreSQL 14 (nodo origen)
-- Se ejecuta automáticamente al crear el contenedor pg14.
-- =============================================================

\c tienda_v1

-- ── Extensiones ───────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ── Tipos enumerados ──────────────────────────────────────────
CREATE TYPE estado_pedido AS ENUM
    ('pendiente', 'confirmado', 'enviado', 'entregado', 'cancelado');

CREATE TYPE metodo_pago AS ENUM
    ('tarjeta', 'transferencia', 'paypal', 'efectivo');

-- ── Categorías ────────────────────────────────────────────────
CREATE TABLE categorias (
    id          SERIAL        PRIMARY KEY,
    nombre      VARCHAR(100)  NOT NULL UNIQUE,
    descripcion TEXT,
    activa      BOOLEAN       NOT NULL DEFAULT true,
    creado_en   TIMESTAMPTZ   NOT NULL DEFAULT now()
);

INSERT INTO categorias (nombre, descripcion) VALUES
    ('Electrónica',  'Dispositivos electrónicos y accesorios'),
    ('Ropa',         'Ropa y complementos de moda'),
    ('Hogar',        'Productos para el hogar y decoración'),
    ('Deportes',     'Material deportivo y fitness'),
    ('Libros',       'Libros, revistas y publicaciones');

-- ── Clientes ──────────────────────────────────────────────────
CREATE TABLE clientes (
    id              SERIAL        PRIMARY KEY,
    email           VARCHAR(255)  NOT NULL UNIQUE,
    nombre          VARCHAR(100)  NOT NULL,
    apellidos       VARCHAR(150),
    telefono        VARCHAR(20),
    fecha_nacimiento DATE,
    direccion       JSONB,
    saldo_puntos    INT           NOT NULL DEFAULT 0,
    activo          BOOLEAN       NOT NULL DEFAULT true,
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

INSERT INTO clientes (email, nombre, apellidos, telefono, fecha_nacimiento, direccion, saldo_puntos)
VALUES
    ('alice@ejemplo.es', 'Alice',   'García López',    '+34600111001', '1990-03-15',
     '{"calle":"Gran Vía 1","ciudad":"Madrid","cp":"28013","pais":"ES"}'::jsonb, 150),
    ('bob@ejemplo.es',   'Bob',     'Martínez Ruiz',   '+34600111002', '1985-07-22',
     '{"calle":"Las Ramblas 50","ciudad":"Barcelona","cp":"08002","pais":"ES"}'::jsonb, 320),
    ('carol@ejemplo.es', 'Carol',   'Sánchez Pérez',   '+34600111003', '1995-11-08',
     '{"calle":"Sierpes 10","ciudad":"Sevilla","cp":"41001","pais":"ES"}'::jsonb, 80),
    ('david@ejemplo.es', 'David',   'López Fernández',  NULL,           '1988-05-30',
     '{"calle":"Paseo Colón 5","ciudad":"Málaga","cp":"29001","pais":"ES"}'::jsonb, 0),
    ('eva@ejemplo.es',   'Eva',     'Torres Moreno',    '+34600111005', '1992-09-14',
     '{"calle":"Calle Mayor 22","ciudad":"Zaragoza","cp":"50001","pais":"ES"}'::jsonb, 500);

-- ── Productos ─────────────────────────────────────────────────
CREATE TABLE productos (
    id              SERIAL          PRIMARY KEY,
    sku             VARCHAR(50)     NOT NULL UNIQUE,
    nombre          VARCHAR(200)    NOT NULL,
    descripcion     TEXT,
    precio          NUMERIC(10,2)   NOT NULL CHECK (precio >= 0),
    precio_coste    NUMERIC(10,2)   CHECK (precio_coste >= 0),
    stock           INT             NOT NULL DEFAULT 0 CHECK (stock >= 0),
    categoria_id    INT             REFERENCES categorias(id),
    imagen_url      TEXT,
    atributos       JSONB,
    activo          BOOLEAN         NOT NULL DEFAULT true,
    creado_en       TIMESTAMPTZ     NOT NULL DEFAULT now()
);

INSERT INTO productos (sku, nombre, precio, precio_coste, stock, categoria_id, atributos) VALUES
    ('TECH-001', 'Laptop UltraBook 15"', 1299.99,  850.00, 25, 1,
     '{"marca":"TechBrand","ram":"16GB","ssd":"512GB","color":"plata"}'::jsonb),
    ('TECH-002', 'Ratón Inalámbrico Pro', 49.99,   18.00, 150, 1,
     '{"marca":"LogiPro","dpi":2400,"botones":6,"color":"negro"}'::jsonb),
    ('ROPA-001', 'Camiseta Básica Algodón', 19.99,   6.50, 300, 2,
     '{"tallas":["XS","S","M","L","XL"],"colores":["blanco","negro","azul"]}'::jsonb),
    ('ROPA-002', 'Pantalón Vaquero Slim',   59.99,  22.00, 120, 2,
     '{"tallas":["36","38","40","42","44"],"colores":["azul oscuro","negro"]}'::jsonb),
    ('HOGAR-001', 'Lámpara LED de Escritorio', 34.99, 12.00,  80, 3,
     '{"potencia":"12W","kelvin":4000,"dimmer":true}'::jsonb),
    ('DEPO-001', 'Zapatillas Running X400',  89.99,  38.00,  60, 4,
     '{"marca":"SportRun","tallas":["38","39","40","41","42","43","44"]}'::jsonb),
    ('LIBRO-001', 'PostgreSQL: La Guía Definitiva', 39.99,  12.00,  45, 5,
     '{"autor":"P. Eisentraut","paginas":650,"isbn":"978-1-xxxx"}'::jsonb),
    ('LIBRO-002', 'Docker en Producción', 34.99,  10.00,  38, 5,
     '{"autor":"S. Mann","paginas":420,"isbn":"978-1-yyyy"}'::jsonb);

-- ── Pedidos ───────────────────────────────────────────────────
CREATE TABLE pedidos (
    id              SERIAL          PRIMARY KEY,
    numero          VARCHAR(20)     NOT NULL UNIQUE DEFAULT 'PED-' || nextval('pedidos_id_seq'),
    cliente_id      INT             NOT NULL REFERENCES clientes(id),
    estado          estado_pedido   NOT NULL DEFAULT 'pendiente',
    metodo_pago     metodo_pago     NOT NULL DEFAULT 'tarjeta',
    total           NUMERIC(10,2)   NOT NULL CHECK (total >= 0),
    descuento       NUMERIC(10,2)   NOT NULL DEFAULT 0,
    impuestos       NUMERIC(10,2)   NOT NULL DEFAULT 0,
    direccion_envio JSONB,
    notas           TEXT,
    creado_en       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ── Líneas de pedido ──────────────────────────────────────────
CREATE TABLE lineas_pedido (
    id              SERIAL          PRIMARY KEY,
    pedido_id       INT             NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    producto_id     INT             NOT NULL REFERENCES productos(id),
    cantidad        INT             NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2)   NOT NULL CHECK (precio_unitario >= 0),
    descuento_linea NUMERIC(10,2)   NOT NULL DEFAULT 0
);

-- Insertar pedidos de prueba
INSERT INTO pedidos (cliente_id, estado, metodo_pago, total, impuestos, direccion_envio) VALUES
    (1, 'entregado', 'tarjeta',      1349.98, 236.20,
     '{"calle":"Gran Vía 1","ciudad":"Madrid","cp":"28013"}'::jsonb),
    (2, 'enviado',   'paypal',        109.98,  19.25,
     '{"calle":"Las Ramblas 50","ciudad":"Barcelona","cp":"08002"}'::jsonb),
    (3, 'pendiente', 'transferencia',  39.99,   6.99,
     '{"calle":"Sierpes 10","ciudad":"Sevilla","cp":"41001"}'::jsonb),
    (1, 'confirmado','tarjeta',         89.99,  15.75,
     '{"calle":"Gran Vía 1","ciudad":"Madrid","cp":"28013"}'::jsonb),
    (5, 'pendiente', 'tarjeta',         74.98,  13.12,
     '{"calle":"Calle Mayor 22","ciudad":"Zaragoza","cp":"50001"}'::jsonb);

INSERT INTO lineas_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
    (1, 1, 1, 1299.99), (1, 2, 1, 49.99),
    (2, 3, 2,   19.99), (2, 5, 2, 34.99),
    (3, 7, 1,   39.99),
    (4, 6, 1,   89.99),
    (5, 3, 2,   19.99), (5, 5, 1, 34.99);

-- ── Índices ───────────────────────────────────────────────────
CREATE INDEX idx_clientes_email     ON clientes(email);
CREATE INDEX idx_productos_sku      ON productos(sku);
CREATE INDEX idx_productos_cat      ON productos(categoria_id);
CREATE INDEX idx_pedidos_cliente    ON pedidos(cliente_id);
CREATE INDEX idx_pedidos_estado     ON pedidos(estado);
CREATE INDEX idx_lineas_pedido      ON lineas_pedido(pedido_id);
CREATE INDEX idx_productos_attrs    ON productos USING GIN(atributos);
CREATE INDEX idx_clientes_dir       ON clientes USING GIN(direccion);

-- ── Vista de resumen ──────────────────────────────────────────
CREATE VIEW resumen_pedidos AS
SELECT
    p.id,
    p.numero,
    c.email          AS cliente,
    p.estado,
    p.metodo_pago,
    p.total,
    p.creado_en
FROM pedidos p
JOIN clientes c ON c.id = p.cliente_id;

-- ── Función de auditoría ──────────────────────────────────────
CREATE TABLE auditoria (
    id          BIGSERIAL     PRIMARY KEY,
    tabla       TEXT          NOT NULL,
    operacion   CHAR(1)       NOT NULL,
    usuario     TEXT          NOT NULL DEFAULT current_user,
    ts          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    datos_old   JSONB,
    datos_new   JSONB
);

CREATE OR REPLACE FUNCTION fn_auditoria()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO auditoria(tabla, operacion, datos_old, datos_new)
    VALUES (
        TG_TABLE_NAME,
        LEFT(TG_OP, 1),
        CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD)::jsonb ELSE NULL END,
        CASE WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE'
             THEN row_to_json(NEW)::jsonb ELSE NULL END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_auditoria_pedidos
AFTER INSERT OR UPDATE OR DELETE ON pedidos
FOR EACH ROW EXECUTE FUNCTION fn_auditoria();

\echo '✓ PG14 — tienda_v1 inicializada con esquema y datos de prueba'
\echo '  Tablas: categorias, clientes, productos, pedidos, lineas_pedido, auditoria'
