-- =============================================================
-- init_lab.sql
-- Inicialización completa del laboratorio de seguridad:
-- extensiones, esquemas, roles, datos y RLS base
-- =============================================================

-- ── pgAudit ───────────────────────────────────────────────────
\c postgres
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- ── Base de datos principal ───────────────────────────────────
SELECT 'CREATE DATABASE dwh' WHERE NOT EXISTS
    (SELECT FROM pg_database WHERE datname = 'dwh')\gexec

\c dwh

CREATE EXTENSION IF NOT EXISTS pgaudit;
CREATE EXTENSION IF NOT EXISTS pgcrypto;    -- Para gen_random_uuid()

-- ── Esquemas ──────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS marts;

-- Revocar PUBLIC del esquema public
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL    ON DATABASE dwh  FROM PUBLIC;

-- ── Tabla principal del laboratorio ──────────────────────────
CREATE TABLE IF NOT EXISTS raw.pedidos (
    id              BIGSERIAL PRIMARY KEY,
    cliente_id      INTEGER       NOT NULL,
    fecha_creacion  TIMESTAMP     NOT NULL DEFAULT now(),
    estado          VARCHAR(20)   NOT NULL DEFAULT 'pendiente'
                        CHECK (estado IN ('pendiente','procesado','cancelado')),
    importe         NUMERIC(10,2),
    region          VARCHAR(50)   DEFAULT 'Centro',
    metadatos_pago  JSONB
);

-- Tabla de auditoría manual
CREATE TABLE IF NOT EXISTS raw.auditoria_accesos (
    id              BIGSERIAL PRIMARY KEY,
    fecha           TIMESTAMPTZ   DEFAULT now(),
    usuario         TEXT,
    aplicacion      TEXT,
    ip_cliente      INET,
    operacion       TEXT,
    esquema         TEXT,
    objeto          TEXT,
    query           TEXT,
    duracion_ms     NUMERIC,
    rows_afectadas  INTEGER
);

-- Tabla de permisos de agentes (para RLS por región)
CREATE TABLE IF NOT EXISTS raw.permisos_agente (
    agente_id   TEXT    NOT NULL,
    region      TEXT    NOT NULL,
    PRIMARY KEY (agente_id, region)
);

-- ── Datos de prueba ───────────────────────────────────────────
INSERT INTO raw.pedidos (cliente_id, estado, importe, region, metadatos_pago)
SELECT
    (random() * 100 + 1)::INT,
    (ARRAY['pendiente','procesado','cancelado'])[ceil(random()*3)],
    round((random() * 490 + 10)::numeric, 2),
    (ARRAY['Norte','Sur','Este','Oeste','Centro'])[ceil(random()*5)],
    jsonb_build_object(
        'pasarela', (ARRAY['stripe','redsys','paypal'])[ceil(random()*3)],
        'tarjeta',  '****' || (1000 + (random()*8999)::INT)::TEXT,
        'moneda',   'EUR',
        'region',   (ARRAY['Norte','Sur','Este','Oeste','Centro'])[ceil(random()*5)]
    )
FROM generate_series(1, 500)
ON CONFLICT DO NOTHING;

INSERT INTO raw.permisos_agente VALUES
    ('agente_norte', 'Norte'),
    ('agente_norte', 'Este'),
    ('agente_sur',   'Sur'),
    ('agente_sur',   'Oeste'),
    ('agente_full',  'Norte'),
    ('agente_full',  'Sur'),
    ('agente_full',  'Este'),
    ('agente_full',  'Oeste'),
    ('agente_full',  'Centro')
ON CONFLICT DO NOTHING;

-- ── ROLES BASE (sin LOGIN) ────────────────────────────────────
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_dba') THEN
        CREATE ROLE role_dba        NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_app_write') THEN
        CREATE ROLE role_app_write  NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_app_read') THEN
        CREATE ROLE role_app_read   NOLOGIN NOINHERIT;
    END IF;
END $$;

-- ── USUARIOS DE PRÁCTICA ──────────────────────────────────────
DO $$ BEGIN
    -- dba_ana: DBA con privilegios elevados
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dba_ana') THEN
        CREATE ROLE dba_ana LOGIN
            PASSWORD 'dba_ana_pass_2025'
            CONNECTION LIMIT 5
            VALID UNTIL '2027-01-01';
    END IF;

    -- app_backend: usuario de aplicación con escritura
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_backend') THEN
        CREATE ROLE app_backend LOGIN
            PASSWORD 'app_pass_2025'
            CONNECTION LIMIT 20
            NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;

    -- reporting_svc: usuario de solo lectura
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reporting_svc') THEN
        CREATE ROLE reporting_svc LOGIN
            PASSWORD 'report_pass_2025'
            CONNECTION LIMIT 10;
    END IF;

    -- monitor_user: usuario de monitorización
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'monitor_user') THEN
        CREATE ROLE monitor_user LOGIN
            PASSWORD 'monitor_pass_2025'
            CONNECTION LIMIT 5;
    END IF;

    -- agente_norte: agente con acceso a regiones Norte y Este
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_norte') THEN
        CREATE ROLE agente_norte LOGIN
            PASSWORD 'agente_norte_2025'
            CONNECTION LIMIT 5;
    END IF;

    -- agente_sur: agente con acceso a regiones Sur y Oeste
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_sur') THEN
        CREATE ROLE agente_sur LOGIN
            PASSWORD 'agente_sur_2025'
            CONNECTION LIMIT 5;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agente_sur_2026') THEN
        CREATE ROLE agente_sur_2026 LOGIN
            PASSWORD 'agente_sur_2026'
            CONNECTION LIMIT 5
            VALID UNTIL '2026-01-01';
    END IF;
END $$;

-- ── ASIGNAR ROLES ─────────────────────────────────────────────
GRANT role_dba       TO dba_ana;
GRANT role_app_write TO app_backend;
GRANT role_app_read  TO reporting_svc;
GRANT pg_monitor     TO monitor_user;
GRANT role_app_read  TO agente_norte;
GRANT role_app_read  TO agente_sur;

-- ── PRIVILEGIOS DE CONEXIÓN Y ESQUEMA ────────────────────────
GRANT CONNECT ON DATABASE dwh TO
    role_app_write, role_app_read, role_dba, monitor_user;

GRANT USAGE, CREATE ON SCHEMA raw, marts TO role_app_write, role_dba;
GRANT USAGE          ON SCHEMA raw, marts TO role_app_read;
GRANT ALL            ON SCHEMA raw, marts, public TO role_dba;

-- ── PRIVILEGIOS SOBRE TABLAS ──────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE
    ON ALL TABLES IN SCHEMA raw, marts TO role_app_write;
GRANT SELECT
    ON ALL TABLES IN SCHEMA raw, marts TO role_app_read;
GRANT ALL
    ON ALL TABLES IN SCHEMA raw, marts TO role_dba;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA raw, marts TO role_app_write;

-- Privilegios por defecto para tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA raw
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO role_app_write;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw
    GRANT SELECT ON TABLES TO role_app_read;
ALTER DEFAULT PRIVILEGES IN SCHEMA marts
    GRANT SELECT ON TABLES TO role_app_read;

-- ── CONFIGURAR search_path POR ROL ────────────────────────────
ALTER ROLE app_backend   SET search_path = raw, marts;
ALTER ROLE reporting_svc SET search_path = marts, raw;
ALTER ROLE agente_norte  SET search_path = raw;
ALTER ROLE agente_sur    SET search_path = raw;

-- ── TIMEOUTS POR ROL ──────────────────────────────────────────
ALTER ROLE app_backend   SET statement_timeout = '30s';
ALTER ROLE app_backend   SET lock_timeout = '5s';
ALTER ROLE app_backend   SET idle_in_transaction_session_timeout = '60s';
ALTER ROLE reporting_svc SET max_parallel_workers_per_gather = 1;

-- ── pgAudit POR ROL ───────────────────────────────────────────
ALTER ROLE dba_ana       SET pgaudit.log = 'all';
ALTER ROLE app_backend   SET pgaudit.log = 'ddl, role';
ALTER ROLE reporting_svc SET pgaudit.log = 'write, ddl';

-- ── FUNCIÓN DE AUDITORÍA MANUAL ───────────────────────────────
CREATE OR REPLACE FUNCTION raw.registrar_acceso_sensible(
    p_operacion  TEXT,
    p_objeto     TEXT,
    p_query      TEXT    DEFAULT NULL,
    p_rows       INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = raw, pg_catalog AS $$
BEGIN
    INSERT INTO raw.auditoria_accesos
        (usuario, aplicacion, ip_cliente, operacion, objeto, query, rows_afectadas)
    VALUES (
        current_user,
        current_setting('application_name', true),
        inet_client_addr(),
        p_operacion,
        p_objeto,
        p_query,
        p_rows
    );
END;
$$;

GRANT EXECUTE ON FUNCTION raw.registrar_acceso_sensible TO role_app_write, role_app_read;

-- ── FUNCIÓN SECURITY DEFINER (ejemplo seguro) ─────────────────
CREATE OR REPLACE FUNCTION raw.actualizar_estado_pedido(
    p_id     BIGINT,
    p_estado VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = raw, pg_catalog AS $$
BEGIN
    IF p_estado NOT IN ('pendiente', 'procesado', 'cancelado') THEN
        RAISE EXCEPTION 'Estado no válido: %', p_estado;
    END IF;

    UPDATE raw.pedidos
    SET estado = p_estado
    WHERE id = p_id;

    PERFORM raw.registrar_acceso_sensible(
        'UPDATE_ESTADO',
        'raw.pedidos',
        format('id=%s estado=%s', p_id, p_estado),
        1
    );
END;
$$;

GRANT EXECUTE ON FUNCTION raw.actualizar_estado_pedido TO role_app_write;

-- Mensaje de confirmación
DO $$ BEGIN
    RAISE NOTICE '✓ Laboratorio de seguridad inicializado correctamente';
    RAISE NOTICE '  BD: dwh | Esquemas: raw, marts';
    RAISE NOTICE '  Roles: dba_ana, app_backend, reporting_svc, monitor_user, agente_norte, agente_sur';
    RAISE NOTICE '  Tablas: raw.pedidos (500 filas), raw.auditoria_accesos, raw.permisos_agente';
END $$;
