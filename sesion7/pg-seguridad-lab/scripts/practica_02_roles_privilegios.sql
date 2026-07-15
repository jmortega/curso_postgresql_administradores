-- =============================================================
-- practica_02_roles_privilegios.sql
-- Práctica 2: Gestión de roles, privilegios y separación de funciones
--
-- Ejecutar con:
--   docker exec -it pg-security psql -U postgres -d dwh \
--     -f /scripts/practica_02_roles_privilegios.sql
-- =============================================================

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  PRÁCTICA 2: Roles, Privilegios y Separación de Funciones'
\echo '═══════════════════════════════════════════════════════'

-- ── 2.1 Ver el árbol completo de roles ────────────────────────
\echo ''
\echo '▸ 2.1 Árbol de roles del laboratorio:'
WITH RECURSIVE role_tree AS (
    SELECT
        r.rolname          AS usuario,
        NULL::TEXT COLLATE "C" AS miembro_de,
        0                  AS nivel
    FROM pg_roles r
    WHERE NOT EXISTS (
        SELECT 1 FROM pg_auth_members m WHERE m.member = r.oid
    )
      AND r.rolname NOT LIKE 'pg_%'

    UNION ALL

    SELECT
        r.rolname,
        rt.usuario         AS miembro_de,
        rt.nivel + 1
    FROM pg_roles r
    JOIN pg_auth_members m   ON m.member = r.oid
    JOIN pg_roles parent     ON parent.oid = m.roleid
    JOIN role_tree rt        ON rt.usuario = parent.rolname
    WHERE r.rolname NOT LIKE 'pg_%'
)
SELECT
    repeat('  ', nivel) || usuario AS rol,
    miembro_de,
    nivel
FROM role_tree
ORDER BY nivel, usuario;

-- ── 2.2 Privilegios sobre tablas ─────────────────────────────
\echo ''
\echo '▸ 2.2 Privilegios sobre tablas en schema raw:'
SELECT
    grantee,
    table_name,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.table_privileges
WHERE table_schema = 'raw'
  AND grantee NOT IN ('postgres', 'PUBLIC')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

-- ── 2.3 Detectar accesos PUBLIC inapropiados ──────────────────
\echo ''
\echo '▸ 2.3 Objetos accesibles por PUBLIC (deben ser ninguno en raw/marts):'
SELECT
    table_schema,
    table_name,
    string_agg(privilege_type, ', ') AS privilegios_public
FROM information_schema.table_privileges
WHERE grantee = 'PUBLIC'
  AND table_schema IN ('raw', 'marts')
GROUP BY table_schema, table_name
ORDER BY table_schema, table_name;

SELECT
    CASE WHEN count(*) = 0
         THEN '✓ Sin accesos PUBLIC indebidos en raw/marts'
         ELSE '⚠ ALERTA: hay accesos PUBLIC en raw/marts'
    END AS resultado
FROM information_schema.table_privileges
WHERE grantee = 'PUBLIC'
  AND table_schema IN ('raw', 'marts');

-- ── 2.4 Verificar que app_backend NO puede hacer DDL ─────────
\echo ''
\echo '▸ 2.4 Probando que app_backend NO puede hacer DDL...'
\echo '    (intento de CREATE TABLE que debe FALLAR):'

DO $$
BEGIN
    BEGIN
        -- Simular intento de DDL como app_backend
        EXECUTE 'SET ROLE app_backend';
        EXECUTE 'CREATE TABLE raw.tabla_prohibida (id INT)';
        EXECUTE 'RESET ROLE';
        RAISE NOTICE '⚠ PROBLEMA: app_backend pudo crear la tabla (revisar privilegios)';
    EXCEPTION WHEN insufficient_privilege THEN
        EXECUTE 'RESET ROLE';
        RAISE NOTICE '✓ app_backend NO puede hacer DDL (correcto)';
    END;
END;
$$;

-- ── 2.5 Verificar que reporting_svc NO puede escribir ────────
\echo ''
\echo '▸ 2.5 Probando que reporting_svc NO puede escribir...'

DO $$
BEGIN
    BEGIN
        EXECUTE 'SET ROLE reporting_svc';
        EXECUTE 'INSERT INTO raw.pedidos (cliente_id, estado) VALUES (1, ''pendiente'')';
        EXECUTE 'RESET ROLE';
        RAISE NOTICE '⚠ PROBLEMA: reporting_svc pudo insertar datos (revisar privilegios)';
    EXCEPTION WHEN insufficient_privilege THEN
        EXECUTE 'RESET ROLE';
        RAISE NOTICE '✓ reporting_svc NO puede insertar datos (correcto)';
    END;
END;
$$;

-- ── 2.6 Verificar que reporting_svc SÍ puede leer ────────────
\echo ''
\echo '▸ 2.6 Probando que reporting_svc SÍ puede leer...'

SET ROLE reporting_svc;
SELECT count(*) AS filas_visibles_para_reporting FROM raw.pedidos;
RESET ROLE;

-- ── 2.7 Configuración search_path por rol ────────────────────
\echo ''
\echo '▸ 2.7 Configuración search_path por rol:'
SELECT rolname,
       array_to_string(rolconfig, ', ') AS configuracion
FROM pg_roles
WHERE rolconfig IS NOT NULL
  AND rolname NOT LIKE 'pg_%'
ORDER BY rolname;

-- ── 2.8 Timeouts configurados por rol ────────────────────────
\echo ''
\echo '▸ 2.8 Timeouts de seguridad por rol:'
SELECT
    rolname,
    array_to_string(
        ARRAY(
            SELECT elem FROM unnest(rolconfig) elem
            WHERE elem LIKE '%timeout%' OR elem LIKE '%parallel%'
        ),
        ' | '
    ) AS timeouts_configurados
FROM pg_roles
WHERE rolconfig IS NOT NULL
  AND rolname NOT LIKE 'pg_%'
ORDER BY rolname;

-- ── 2.9 Auditar roles con privilegios excesivos ───────────────
\echo ''
\echo '▸ 2.9 Resumen de límites de conexión por rol:'
SELECT
    rolname,
    rolcanlogin         AS puede_login,
    rolconnlimit        AS limite_conexiones,
    rolvaliduntil       AS expira,
    rolsuper            AS superusuario
FROM pg_roles
WHERE rolcanlogin
  AND rolname NOT LIKE 'pg_%'
ORDER BY rolname;

\echo ''
\echo '✓ Práctica 2 completada'
\echo '═══════════════════════════════════════════════════════'
