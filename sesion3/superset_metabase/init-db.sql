-- init-db.sql
-- Se ejecuta automáticamente la primera vez que arranca el contenedor db

-- Base de datos interna de Superset (metastore)
-- Nota: la BD 'analytics' ya se crea con POSTGRES_DB,
-- aquí añadimos tablas de ejemplo para explorar con Superset y Metabase

CREATE TABLE IF NOT EXISTS ventas (
    id          SERIAL PRIMARY KEY,
    fecha       DATE NOT NULL,
    producto    VARCHAR(100),
    categoria   VARCHAR(50),
    cantidad    INTEGER,
    precio      NUMERIC(10,2),
    region      VARCHAR(50)
);

INSERT INTO ventas (fecha, producto, categoria, cantidad, precio, region) VALUES
('2025-01-15', 'Laptop Pro',    'Electrónica',  5,  1200.00, 'Norte'),
('2025-01-20', 'Teclado USB',   'Periféricos',  20,   45.00, 'Sur'),
('2025-02-03', 'Monitor 27"',   'Electrónica',  8,   350.00, 'Este'),
('2025-02-14', 'Ratón Inalámbrico', 'Periféricos', 15, 29.99, 'Norte'),
('2025-03-01', 'Laptop Pro',    'Electrónica',  3,  1200.00, 'Oeste'),
('2025-03-10', 'Auriculares BT','Audio',        12,   89.99, 'Sur'),
('2025-04-05', 'Webcam HD',     'Periféricos',  18,   65.00, 'Este'),
('2025-04-22', 'Monitor 27"',   'Electrónica',  4,   350.00, 'Norte'),
('2025-05-11', 'Teclado USB',   'Periféricos',  25,   45.00, 'Oeste'),
('2025-05-30', 'Auriculares BT','Audio',        9,    89.99, 'Norte');

CREATE TABLE IF NOT EXISTS clientes (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100),
    email       VARCHAR(150),
    ciudad      VARCHAR(80),
    fecha_alta  DATE
);

INSERT INTO clientes (nombre, email, ciudad, fecha_alta) VALUES
('Ana García',    'ana@ejemplo.com',    'Madrid',    '2024-01-10'),
('Carlos López',  'carlos@ejemplo.com', 'Barcelona', '2024-03-22'),
('Marta Ruiz',    'marta@ejemplo.com',  'Valencia',  '2024-06-15'),
('Pedro Sánchez', 'pedro@ejemplo.com',  'Sevilla',   '2024-09-01'),
('Laura Martín',  'laura@ejemplo.com',  'Bilbao',    '2025-01-05');
