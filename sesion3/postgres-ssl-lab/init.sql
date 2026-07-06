-- ============================================================================
-- init.sql — Datos de prueba para el laboratorio SSL + consultas de metadatos
-- ============================================================================

-- Extensión para estadísticas de consultas
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Esquemas
CREATE SCHEMA IF NOT EXISTS ventas;
CREATE SCHEMA IF NOT EXISTS rrhh;

-- ── Tablas de prueba ─────────────────────────────────────────────────────────

CREATE TABLE ventas.clientes (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    email       VARCHAR(150) UNIQUE NOT NULL,
    pais        VARCHAR(50)  NOT NULL DEFAULT 'España',
    segmento    VARCHAR(20)  NOT NULL DEFAULT 'estandar'
                CHECK (segmento IN ('basico','estandar','premium')),
    creado_en   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE ventas.productos (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    categoria   VARCHAR(50)  NOT NULL,
    precio      NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    stock       INTEGER      NOT NULL DEFAULT 0
);

CREATE TABLE ventas.pedidos (
    id          BIGSERIAL PRIMARY KEY,
    cliente_id  INTEGER      NOT NULL REFERENCES ventas.clientes(id),
    producto_id INTEGER      NOT NULL REFERENCES ventas.productos(id),
    cantidad    INTEGER      NOT NULL CHECK (cantidad > 0),
    total       NUMERIC(12,2) NOT NULL,
    estado      VARCHAR(20)  NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente','enviado','entregado','cancelado')),
    fecha       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_pedidos_cliente  ON ventas.pedidos (cliente_id);
CREATE INDEX idx_pedidos_estado   ON ventas.pedidos (estado);
CREATE INDEX idx_pedidos_fecha    ON ventas.pedidos (fecha DESC);

CREATE TABLE rrhh.empleados (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    departamento VARCHAR(50) NOT NULL,
    salario     NUMERIC(10,2) NOT NULL,
    activo      BOOLEAN      NOT NULL DEFAULT true,
    contratado_en DATE       NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE ventas.log_accesos (
    id          BIGSERIAL PRIMARY KEY,
    usuario_pg  VARCHAR(50)  NOT NULL DEFAULT current_user,
    accion      VARCHAR(100) NOT NULL,
    tabla       VARCHAR(100),
    ssl_usado   BOOLEAN,
    registrado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Datos de prueba ───────────────────────────────────────────────────────────

INSERT INTO ventas.clientes (nombre, email, pais, segmento) VALUES
    ('Ana García',      'ana@ejemplo.com',    'España',    'premium'),
    ('Luis Martínez',   'luis@ejemplo.com',   'México',    'estandar'),
    ('Sara López',      'sara@ejemplo.com',   'Argentina', 'basico'),
    ('Carlos Ruiz',     'carlos@ejemplo.com', 'España',    'premium'),
    ('Elena Sánchez',   'elena@ejemplo.com',  'Colombia',  'estandar'),
    ('Pedro Jiménez',   'pedro@ejemplo.com',  'Chile',     'basico'),
    ('Marta Torres',    'marta@ejemplo.com',  'España',    'premium'),
    ('Jorge Díaz',      'jorge@ejemplo.com',  'Perú',      'estandar');

INSERT INTO ventas.productos (nombre, categoria, precio, stock) VALUES
    ('Laptop Pro 15',     'Electrónica',    999.99, 25),
    ('Teclado Mecánico',  'Periféricos',     89.99, 80),
    ('Monitor 27"',       'Electrónica',    349.99, 15),
    ('Ratón Inalámbrico', 'Periféricos',     29.99, 120),
    ('Auriculares BT',    'Audio',          149.99, 50),
    ('SSD 1TB',           'Almacenamiento', 109.99, 60),
    ('Webcam HD',         'Periféricos',     79.99, 40),
    ('Hub USB-C',         'Periféricos',     49.99, 90);

INSERT INTO ventas.pedidos (cliente_id, producto_id, cantidad, total, estado, fecha)
SELECT
    (random()*7+1)::INT,
    (random()*7+1)::INT,
    (random()*4+1)::INT,
    round((random()*900+50)::numeric, 2),
    (ARRAY['pendiente','enviado','entregado','cancelado'])[ceil(random()*4)],
    now() - (random()*90 || ' days')::interval
FROM generate_series(1, 150);

INSERT INTO rrhh.empleados (nombre, departamento, salario, activo, contratado_en)
SELECT
    'Empleado ' || i,
    (ARRAY['Ventas','IT','RRHH','Finanzas','Marketing'])[ceil(random()*5)],
    round((random()*4000+1500)::numeric, 2),
    random() > 0.1,
    CURRENT_DATE - (random()*1000)::INT
FROM generate_series(1, 40) i;

-- Permisos al usuario del lab
GRANT USAGE ON SCHEMA ventas, rrhh TO pguser;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ventas TO pguser;
GRANT SELECT ON ALL TABLES IN SCHEMA rrhh TO pguser;

DO $$ BEGIN
  RAISE NOTICE '✓ Tablas de prueba creadas: ventas.clientes, ventas.productos, ventas.pedidos, rrhh.empleados, ventas.log_accesos';
END $$;
