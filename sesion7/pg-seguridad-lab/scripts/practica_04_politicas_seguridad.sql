-- =============================================================
-- practica_04_politicas_seguridad.sql
-- Práctica 4: Funciones SECURITY DEFINER, SQL Injection y políticas
--
-- Ejecutar con:
--   docker exec -it pg-security psql -U postgres -d dwh \
--     -f /scripts/practica_04_politicas_seguridad.sql
-- =============================================================

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  PRÁCTICA 4: Políticas de Seguridad y SQL Injection'
\echo '═══════════════════════════════════════════════════════'

-- ── 4.1 Función SECURITY INVOKER vs SECURITY DEFINER ─────────
\echo ''
\echo '▸ 4.1 SECURITY INVOKER — corre con privilegios del llamante:'

CREATE OR REPLACE FUNCTION raw.obtener_mis_pedidos()
RETURNS SETOF raw.pedidos
LANGUAGE sql
SECURITY INVOKER AS $$
    SELECT * FROM raw.pedidos LIMIT 5;
$$;

-- Como reporting_svc puede leer, funciona
SET ROLE reporting_svc;
BEGIN;
SET LOCAL app.current_client_id = '10';
SELECT count(*) AS pedidos_via_invoker FROM raw.obtener_mis_pedidos();
COMMIT;
RESET ROLE;

\echo ''
\echo '▸ 4.1b SECURITY DEFINER — corre con privilegios del propietario (postgres):'
\echo '    La función actualizar_estado_pedido ya existe desde init_lab.sql'

-- Demostrar que app_backend puede actualizar estado SIN tener UPDATE directo
-- (porque la función SECURITY DEFINER lo hace por él)

-- Primero, revocar UPDATE directo a app_backend en pedidos
REVOKE UPDATE ON raw.pedidos FROM role_app_write;

SET ROLE app_backend;

-- Intento directo de UPDATE (debe FALLAR)
DO $$
BEGIN
    BEGIN
        UPDATE raw.pedidos SET estado = 'procesado' WHERE id = 1;
        RAISE NOTICE '⚠ UPDATE directo funcionó (revisar privilegios)';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '✓ UPDATE directo rechazado para app_backend (correcto)';
    END;
END;
$$;

-- Actualización vía función SECURITY DEFINER (debe FUNCIONAR)
DO $$
BEGIN
    BEGIN
        PERFORM raw.actualizar_estado_pedido(1, 'procesado');
        RAISE NOTICE '✓ Actualización vía SECURITY DEFINER funcionó (correcto)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠ Error inesperado: %', SQLERRM;
    END;
END;
$$;

RESET ROLE;

-- Restaurar UPDATE para las demás prácticas
GRANT UPDATE ON ALL TABLES IN SCHEMA raw TO role_app_write;

-- ── 4.2 SQL Injection: función insegura vs segura ─────────────
\echo ''
\echo '▸ 4.2 Demostración de SQL Injection:'

-- Función INSEGURA (concatenación)
CREATE OR REPLACE FUNCTION raw.buscar_inseguro(p_estado TEXT)
RETURNS TABLE(id BIGINT, estado VARCHAR, importe NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT id, estado, importe FROM raw.pedidos WHERE estado = '''
        || p_estado || ''' LIMIT 3';
END;
$$;

-- Función SEGURA (parametrizada)
CREATE OR REPLACE FUNCTION raw.buscar_seguro(p_estado TEXT)
RETURNS TABLE(id BIGINT, estado VARCHAR, importe NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT id, estado, importe FROM raw.pedidos WHERE estado = $1 LIMIT 3'
        USING p_estado;
END;
$$;

-- Función SEGURA estática (aún mejor)
CREATE OR REPLACE FUNCTION raw.buscar_estatico(p_estado TEXT)
RETURNS TABLE(id BIGINT, estado VARCHAR, importe NUMERIC)
LANGUAGE sql AS $$
    SELECT id, estado, importe FROM raw.pedidos WHERE estado = p_estado LIMIT 3;
$$;

\echo '    Búsqueda normal (mismo resultado en las tres):'
SELECT 'inseguro'  AS funcion, count(*) AS filas FROM raw.buscar_inseguro('pendiente')
UNION ALL
SELECT 'seguro',   count(*) FROM raw.buscar_seguro('pendiente')
UNION ALL
SELECT 'estatico', count(*) FROM raw.buscar_estatico('pendiente');

\echo '    Intento de SQL Injection en función INSEGURA:'
\echo '    Input: '' OR ''1''=''1'
DO $$
DECLARE
    injection TEXT := ''' OR ''1''=''1';
    filas_retornadas INT;
BEGIN
    BEGIN
        SELECT count(*) INTO filas_retornadas
        FROM raw.buscar_inseguro(injection);

        IF filas_retornadas > 3 THEN
            RAISE NOTICE '🔴 SQL INJECTION EXITOSA: % filas devueltas (esperadas: 0)', filas_retornadas;
        ELSE
            RAISE NOTICE '    Filas devueltas: % (puede variar)', filas_retornadas;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '    Error con SQL injection (puede ser la forma del error): %', SQLERRM;
    END;
END;
$$;

\echo '    Mismo input en función SEGURA — devuelve 0 filas (estado no válido):'
SELECT count(*) AS filas_con_injection_seguro
FROM raw.buscar_seguro(''' OR ''1''=''1');

-- ── 4.3 Timeouts por sesión ───────────────────────────────────
\echo ''
\echo '▸ 4.3 Configurar timeouts por sesión (ejemplo):'

-- Configurar un statement_timeout muy corto para demostrar
SET statement_timeout = '100ms';

DO $$
BEGIN
    BEGIN
        PERFORM pg_sleep(0.05);
        RAISE NOTICE '✓ Consulta rápida (50ms) completada dentro del timeout de 100ms';
    EXCEPTION WHEN query_canceled THEN
        RAISE NOTICE '⚠ Consulta cancelada por timeout';
    END;
END;
$$;

RESET statement_timeout;
\echo '    Timeout restaurado al valor por defecto'

-- ── 4.4 Ver configuración de seguridad por rol ───────────────
\echo ''
\echo '▸ 4.4 Configuración de seguridad efectiva por rol:'
SELECT
    rolname,
    array_to_string(rolconfig, ' | ') AS configuracion
FROM pg_roles
WHERE rolconfig IS NOT NULL
  AND rolname NOT LIKE 'pg_%'
ORDER BY rolname;

-- ── 4.5 Funciones SECURITY DEFINER existentes ─────────────────
\echo ''
\echo '▸ 4.5 Funciones con SECURITY DEFINER en el laboratorio:'
SELECT
    n.nspname                              AS esquema,
    p.proname                              AS funcion,
    pg_get_function_identity_arguments(p.oid) AS argumentos,
    r.rolname                              AS propietario,
    CASE p.prosecdef WHEN true THEN '⚠ SECURITY DEFINER' ELSE 'SECURITY INVOKER' END AS tipo
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_roles r     ON r.oid = p.proowner
WHERE n.nspname IN ('raw', 'marts', 'public')
  AND p.prokind = 'f'
ORDER BY n.nspname, p.proname;

\echo ''
\echo '✓ Práctica 4 completada'
\echo '═══════════════════════════════════════════════════════'
