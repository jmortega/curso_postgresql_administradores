-- =============================================================
-- scripts/mysql/01_seed_mysql.sql
-- Esquema y datos de prueba en MySQL 8.0
-- Representa una aplicación legacy que migramos a PostgreSQL
-- =============================================================

USE tienda_mysql;

-- pgloader 3.6 no soporta caching_sha2_password (defecto en MySQL 8).
-- Cambiar el usuario a mysql_native_password para compatibilidad.
ALTER USER 'mysql_user'@'%' IDENTIFIED WITH mysql_native_password BY 'mysql_pass';
FLUSH PRIVILEGES;

-- ── Forzar autenticación compatible con pgloader 3.6 ─────────
-- pgloader no soporta caching_sha2_password (plugin por defecto
-- en MySQL 8). Se cambia a mysql_native_password.
ALTER USER 'mysql_user'@'%'
    IDENTIFIED WITH mysql_native_password BY 'mysql_pass';
ALTER USER 'root'@'%'
    IDENTIFIED WITH mysql_native_password BY 'root_lab';
FLUSH PRIVILEGES;

-- ── Categorías ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categorias (
    id          INT             NOT NULL AUTO_INCREMENT PRIMARY KEY,
    nombre      VARCHAR(100)    NOT NULL UNIQUE,
    descripcion TEXT,
    activa      TINYINT(1)      NOT NULL DEFAULT 1,
    creado_en   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO categorias (nombre, descripcion) VALUES
    ('Electrónica',  'Dispositivos electrónicos'),
    ('Ropa',         'Moda y complementos'),
    ('Hogar',        'Artículos para el hogar'),
    ('Deportes',     'Material deportivo'),
    ('Libros',       'Libros y publicaciones');

-- ── Clientes ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clientes (
    id              INT             NOT NULL AUTO_INCREMENT PRIMARY KEY,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    nombre          VARCHAR(100)    NOT NULL,
    apellidos       VARCHAR(150),
    telefono        VARCHAR(20),
    fecha_nacimiento DATE,
    calle           VARCHAR(200),
    ciudad          VARCHAR(100),
    codigo_postal   VARCHAR(10),
    pais            CHAR(2)         NOT NULL DEFAULT 'ES',
    saldo_puntos    INT             NOT NULL DEFAULT 0,
    activo          TINYINT(1)      NOT NULL DEFAULT 1,
    creado_en       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO clientes
    (email, nombre, apellidos, telefono, fecha_nacimiento, calle, ciudad, codigo_postal, saldo_puntos)
VALUES
    ('alice.my@ejemplo.es', 'Alice',  'García López',    '+34600222001', '1990-03-15',
     'Gran Vía 1',   'Madrid',    '28013', 150),
    ('bob.my@ejemplo.es',   'Bob',    'Martínez Ruiz',   '+34600222002', '1985-07-22',
     'Las Ramblas 50','Barcelona', '08002', 320),
    ('carol.my@ejemplo.es', 'Carol',  'Sánchez Pérez',   '+34600222003', '1995-11-08',
     'Sierpes 10',   'Sevilla',   '41001', 80),
    ('david.my@ejemplo.es', 'David',  'López Fernández',  NULL,           '1988-05-30',
     'Paseo Colón 5','Málaga',    '29001', 0),
    ('eva.my@ejemplo.es',   'Eva',    'Torres Moreno',   '+34600222005', '1992-09-14',
     'Calle Mayor 22','Zaragoza', '50001', 500);

-- ── Productos ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS productos (
    id              INT             NOT NULL AUTO_INCREMENT PRIMARY KEY,
    sku             VARCHAR(50)     NOT NULL UNIQUE,
    nombre          VARCHAR(200)    NOT NULL,
    descripcion     TEXT,
    precio          DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    precio_coste    DECIMAL(10,2)   DEFAULT NULL,
    stock           INT             NOT NULL DEFAULT 0,
    categoria_id    INT             REFERENCES categorias(id),
    activo          TINYINT(1)      NOT NULL DEFAULT 1,
    creado_en       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO productos (sku, nombre, precio, precio_coste, stock, categoria_id) VALUES
    ('MY-TECH-001', 'Laptop Gaming Pro',         1499.99,  950.00, 20, 1),
    ('MY-TECH-002', 'Teclado Mecánico RGB',         79.99,   28.00, 80, 1),
    ('MY-TECH-003', 'Monitor 27" 4K IPS',          399.99,  180.00, 35, 1),
    ('MY-ROPA-001', 'Sudadera Oversize',             39.99,   12.00,200, 2),
    ('MY-ROPA-002', 'Leggings Deportivos',           29.99,    9.00,150, 2),
    ('MY-HOGAR-001','Cafetera Espresso Automática', 299.99,  120.00, 25, 3),
    ('MY-HOGAR-002','Set Sábanas Algodón 500H',     89.99,   32.00, 60, 3),
    ('MY-DEPO-001', 'Bicicleta Estática Plegable', 349.99,  140.00, 15, 4),
    ('MY-LIBRO-001','MySQL para Desarrolladores',   34.99,   10.00, 50, 5),
    ('MY-LIBRO-002','Migraciones de Bases de Datos',29.99,    8.00, 45, 5);

-- ── Pedidos ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pedidos (
    id              INT             NOT NULL AUTO_INCREMENT PRIMARY KEY,
    numero          VARCHAR(20)     NOT NULL UNIQUE,
    cliente_id      INT             NOT NULL REFERENCES clientes(id),
    -- MySQL no tiene ENUM con los mismos valores: se usa VARCHAR
    estado          VARCHAR(20)     NOT NULL DEFAULT 'pendiente',
    metodo_pago     VARCHAR(20)     NOT NULL DEFAULT 'tarjeta',
    total           DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    descuento       DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    impuestos       DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    notas           TEXT,
    creado_en       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO pedidos (numero, cliente_id, estado, metodo_pago, total, impuestos) VALUES
    ('MY-PED-0001', 1, 'entregado',  'tarjeta',      1579.98, 276.50),
    ('MY-PED-0002', 2, 'enviado',    'paypal',         429.98,  75.25),
    ('MY-PED-0003', 3, 'pendiente',  'transferencia',  299.99,  52.50),
    ('MY-PED-0004', 1, 'confirmado', 'tarjeta',         79.99,  14.00),
    ('MY-PED-0005', 5, 'pendiente',  'tarjeta',         59.98,  10.50);

-- ── Líneas de pedido ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lineas_pedido (
    id              INT             NOT NULL AUTO_INCREMENT PRIMARY KEY,
    pedido_id       INT             NOT NULL REFERENCES pedidos(id),
    producto_id     INT             NOT NULL REFERENCES productos(id),
    cantidad        INT             NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    descuento_linea DECIMAL(10,2)   NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO lineas_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
    (1, 1, 1, 1499.99), (1, 2, 1,   79.99),
    (2, 3, 1,  399.99), (2, 5, 1,   29.99),
    (3, 6, 1,  299.99),
    (4, 2, 1,   79.99),
    (5, 4, 1,   39.99), (5, 5, 1,   29.99);

-- ── Vista de resumen (también se migra) ──────────────────────
CREATE OR REPLACE VIEW resumen_pedidos AS
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
