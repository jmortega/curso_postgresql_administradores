-- =============================================================
-- init_v15.sql
-- Inicializa la instancia PostgreSQL 15 con datos de prueba
-- para el laboratorio de major version upgrade
--
-- NOTA: el entrypoint de postgres:15 ejecuta este script con
-- psql conectado a POSTGRES_DB (dwh) pero usando --single-transaction,
-- que no acepta metacomandos psql como \c. No se necesita \c dwh
-- porque ya conecta directamente a dwh. Se eliminó el \c.
-- wal_level=logical se configura en docker-compose via command:.
-- =============================================================

-- Tabla de prueba para la práctica de major upgrade
CREATE TABLE IF NOT EXISTS pedidos_v15 (
    id             BIGSERIAL PRIMARY KEY,
    cliente_id     INTEGER       NOT NULL,
    fecha          TIMESTAMP     NOT NULL DEFAULT now(),
    estado         VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
    importe        NUMERIC(10,2)
);

-- Datos de prueba
INSERT INTO pedidos_v15 (cliente_id, estado, importe)
SELECT
    (random() * 100 + 1)::INT,
    (ARRAY['pendiente','procesado','cancelado'])[ceil(random()*3)],
    round((random() * 490 + 10)::numeric, 2)
FROM generate_series(1, 200);

-- Publicación para replicación lógica hacia v16
-- (wal_level=logical activo desde el arranque via command: en compose)
CREATE PUBLICATION pub_upgrade
    FOR ALL TABLES
    WITH (publish = 'insert, update, delete, truncate');

-- Usuario para replicación lógica
CREATE ROLE logical_repl
    WITH REPLICATION LOGIN
    PASSWORD 'logical_lab_2025';

GRANT SELECT ON ALL TABLES IN SCHEMA public TO logical_repl;
