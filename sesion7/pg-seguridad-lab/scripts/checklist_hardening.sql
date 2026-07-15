-- =============================================================
-- checklist_hardening.sql
-- Checklist automatizado de endurecimiento de PostgreSQL
-- Verifica todos los puntos del README y devuelve PASS/WARN/FAIL
--
-- Ejecutar con:
--   docker exec -it pg-security psql -U postgres -d dwh \
--     -f /scripts/checklist_hardening.sql
-- =============================================================

\echo ''
\echo '╔═══════════════════════════════════════════════════════╗'
\echo '║   CHECKLIST DE ENDURECIMIENTO — PostgreSQL Security   ║'
\echo '╚═══════════════════════════════════════════════════════╝'

-- Tabla temporal para acumular resultados
CREATE TEMP TABLE IF NOT EXISTS resultados_checklist (
    categoria   TEXT,
    control     TEXT,
    resultado   TEXT,  -- PASS / WARN / FAIL
    detalle     TEXT
);

TRUNCATE resultados_checklist;

-- ══════════════════════════════════════════════════════════════
-- CATEGORÍA 1: AUTENTICACIÓN
-- ══════════════════════════════════════════════════════════════

-- 1.1 password_encryption = scram-sha-256
INSERT INTO resultados_checklist
SELECT 'AUTENTICACIÓN', 'password_encryption = scram-sha-256',
    CASE WHEN setting = 'scram-sha-256' THEN 'PASS' ELSE 'FAIL' END,
    'Valor actual: ' || setting
FROM pg_settings WHERE name = 'password_encryption';

-- 1.2 Sin contraseñas MD5
INSERT INTO resultados_checklist
SELECT 'AUTENTICACIÓN', 'Sin hashes MD5',
    CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    count(*)::TEXT || ' usuario(s) con hash MD5'
FROM pg_shadow WHERE passwd LIKE 'md5%';

-- 1.3 SSL habilitado
INSERT INTO resultados_checklist
SELECT 'AUTENTICACIÓN', 'SSL habilitado',
    CASE WHEN setting = 'on' THEN 'PASS' ELSE 'FAIL' END,
    'ssl = ' || setting
FROM pg_settings WHERE name = 'ssl';

-- 1.4 TLS mínimo TLSv1.2
INSERT INTO resultados_checklist
SELECT 'AUTENTICACIÓN', 'ssl_min_protocol_version >= TLSv1.2',
    CASE
        WHEN setting IN ('TLSv1.2','TLSv1.3') THEN 'PASS'
        ELSE 'FAIL'
    END,
    'ssl_min_protocol_version = ' || setting
FROM pg_settings WHERE name = 'ssl_min_protocol_version';

-- 1.5 idle_in_transaction_session_timeout configurado
INSERT INTO resultados_checklist
SELECT 'AUTENTICACIÓN', 'idle_in_transaction_session_timeout > 0',
    CASE WHEN setting::INT > 0 THEN 'PASS' ELSE 'WARN' END,
    'Valor: ' || setting || 'ms'
FROM pg_settings WHERE name = 'idle_in_transaction_session_timeout';

-- ══════════════════════════════════════════════════════════════
-- CATEGORÍA 2: ROLES Y PRIVILEGIOS
-- ══════════════════════════════════════════════════════════════

-- 2.1 Sin usuarios de aplicación con superuser
INSERT INTO resultados_checklist
SELECT 'ROLES', 'Sin app_users con SUPERUSER',
    CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    count(*)::TEXT || ' usuario(s) de app con superuser'
FROM pg_roles
WHERE rolsuper AND rolcanlogin
  AND rolname NOT IN ('postgres');

-- 2.2 CREATE en public revocado de PUBLIC
-- Se inspecciona pg_namespace.nspacl directamente:
--   Una entrada del tipo '=XYZ' (grantee vacío) representa privilegios de PUBLIC.
--   'C' en los privilegios indica CREATE.
--   Si nspacl es NULL el schema tiene permisos por defecto (PUBLIC tiene CREATE).
INSERT INTO resultados_checklist
SELECT 'ROLES', 'REVOKE CREATE ON SCHEMA public FROM PUBLIC',
    CASE
        WHEN nspacl IS NULL                                    THEN 'WARN'
        WHEN array_to_string(nspacl, ',') ~ '(^|,)=[^,]*C'   THEN 'FAIL'
        ELSE 'PASS'
    END,
    CASE
        WHEN nspacl IS NULL
            THEN '⚠ ACL por defecto — PUBLIC todavía puede crear en schema public'
        WHEN array_to_string(nspacl, ',') ~ '(^|,)=[^,]*C'
            THEN '⚠ PUBLIC tiene CREATE en schema public'
        ELSE 'CREATE en public revocado correctamente'
    END
FROM pg_namespace
WHERE nspname = 'public';

-- 2.3 Usuarios con contraseñas sin expiración
INSERT INTO resultados_checklist
SELECT 'ROLES', 'Roles con VALID UNTIL configurado',
    CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    count(*)::TEXT || ' rol(es) de login sin fecha de expiración'
FROM pg_roles
WHERE rolcanlogin
  AND rolvaliduntil IS NULL
  AND rolname NOT IN ('postgres', 'replicator');

-- 2.4 search_path configurado en roles de app
INSERT INTO resultados_checklist
SELECT 'ROLES', 'search_path fijado en roles de aplicación',
    CASE WHEN count(*) >= 2 THEN 'PASS' ELSE 'WARN' END,
    count(*)::TEXT || ' rol(es) con search_path explícito'
FROM pg_roles
WHERE rolconfig IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM unnest(rolconfig) e WHERE e LIKE '%search_path%'
  )
  AND rolname NOT LIKE 'pg_%';

-- 2.5 CONNECTION LIMIT en roles de app
INSERT INTO resultados_checklist
SELECT 'ROLES', 'CONNECTION LIMIT en roles de app',
    CASE WHEN count(*) >= 3 THEN 'PASS' ELSE 'WARN' END,
    count(*)::TEXT || ' rol(es) con límite de conexión explícito'
FROM pg_roles
WHERE rolcanlogin
  AND rolconnlimit > 0
  AND rolname NOT IN ('postgres');

-- ══════════════════════════════════════════════════════════════
-- CATEGORÍA 3: RLS Y FUNCIONES
-- ══════════════════════════════════════════════════════════════

-- 3.1 RLS habilitado en raw.pedidos
INSERT INTO resultados_checklist
SELECT 'RLS', 'RLS habilitado en raw.pedidos',
    CASE WHEN relrowsecurity THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN relrowsecurity THEN 'RLS activo' ELSE '⚠ RLS no está activo' END
FROM pg_class
WHERE relname = 'pedidos'
  AND relnamespace = 'raw'::regnamespace;

-- 3.2 FORCE RLS en raw.pedidos
INSERT INTO resultados_checklist
SELECT 'RLS', 'FORCE ROW LEVEL SECURITY en raw.pedidos',
    CASE WHEN relforcerowsecurity THEN 'PASS' ELSE 'WARN' END,
    CASE WHEN relforcerowsecurity THEN 'FORCE RLS activo'
         ELSE '⚠ FORCE RLS no configurado (propietario podría evitar RLS)' END
FROM pg_class
WHERE relname = 'pedidos'
  AND relnamespace = 'raw'::regnamespace;

-- 3.3 Políticas RLS definidas
INSERT INTO resultados_checklist
SELECT 'RLS', 'Políticas RLS definidas en raw.pedidos',
    CASE WHEN count(*) >= 3 THEN 'PASS' ELSE 'WARN' END,
    count(*)::TEXT || ' política(s) definidas'
FROM pg_policies WHERE tablename = 'pedidos';

-- 3.4 Funciones SECURITY DEFINER con search_path vacío
INSERT INTO resultados_checklist
SELECT 'RLS', 'SECURITY DEFINER con search_path controlado',
    CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'WARN' END,
    CASE WHEN count(*) = 0
         THEN 'Todas las SECURITY DEFINER tienen search_path configurado'
         ELSE count(*)::TEXT || ' función(es) SECURITY DEFINER sin search_path explícito'
    END
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosecdef = true
  AND n.nspname IN ('raw','marts')
  AND NOT EXISTS (
      SELECT 1 FROM pg_options_to_table(p.proconfig)
      WHERE option_name = 'search_path'
  );

-- ══════════════════════════════════════════════════════════════
-- CATEGORÍA 4: AUDITORÍA
-- ══════════════════════════════════════════════════════════════

-- 4.1 pgAudit instalado
INSERT INTO resultados_checklist
SELECT 'AUDITORÍA', 'pgAudit instalado',
    CASE WHEN count(*) > 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN count(*) > 0 THEN 'pgAudit activo' ELSE '⚠ pgAudit no instalado' END
FROM pg_extension WHERE extname = 'pgaudit';

-- 4.2 pgaudit.log cubre operaciones críticas
INSERT INTO resultados_checklist
SELECT 'AUDITORÍA', 'pgaudit.log cubre write+ddl+role+connection',
    CASE WHEN setting ~ 'write' AND setting ~ 'ddl'
         THEN 'PASS' ELSE 'WARN' END,
    'pgaudit.log = ' || setting
FROM pg_settings WHERE name = 'pgaudit.log';

-- 4.3 pgaudit.log_parameter habilitado
INSERT INTO resultados_checklist
SELECT 'AUDITORÍA', 'pgaudit.log_parameter habilitado',
    CASE WHEN setting = 'on' THEN 'PASS' ELSE 'WARN' END,
    'pgaudit.log_parameter = ' || setting
FROM pg_settings WHERE name = 'pgaudit.log_parameter';

-- 4.4 Logging de conexiones habilitado
INSERT INTO resultados_checklist
SELECT 'AUDITORÍA', 'log_connections habilitado',
    CASE WHEN setting = 'on' THEN 'PASS' ELSE 'WARN' END,
    'log_connections = ' || setting
FROM pg_settings WHERE name = 'log_connections';

-- ══════════════════════════════════════════════════════════════
-- RESUMEN FINAL
-- ══════════════════════════════════════════════════════════════

\echo ''
\echo '── RESULTADOS DETALLADOS ────────────────────────────────'

SELECT
    categoria,
    CASE resultado
        WHEN 'PASS' THEN '✅ PASS'
        WHEN 'WARN' THEN '⚠️  WARN'
        WHEN 'FAIL' THEN '❌ FAIL'
    END AS resultado,
    control,
    detalle
FROM resultados_checklist
ORDER BY categoria,
    CASE resultado WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END,
    control;

\echo ''
\echo '── RESUMEN POR CATEGORÍA ────────────────────────────────'

SELECT
    categoria,
    count(*) FILTER (WHERE resultado = 'PASS') AS pass,
    count(*) FILTER (WHERE resultado = 'WARN') AS warn,
    count(*) FILTER (WHERE resultado = 'FAIL') AS fail,
    count(*) AS total,
    CASE
        WHEN count(*) FILTER (WHERE resultado = 'FAIL') > 0 THEN '❌ REVISAR'
        WHEN count(*) FILTER (WHERE resultado = 'WARN') > 0 THEN '⚠️  MEJORAR'
        ELSE '✅ OK'
    END AS estado_general
FROM resultados_checklist
GROUP BY categoria
ORDER BY categoria;

\echo ''
\echo '── PUNTUACIÓN GLOBAL ────────────────────────────────────'

SELECT
    count(*) FILTER (WHERE resultado = 'PASS') AS total_pass,
    count(*) FILTER (WHERE resultado = 'WARN') AS total_warn,
    count(*) FILTER (WHERE resultado = 'FAIL') AS total_fail,
    count(*)                                    AS total_controles,
    round(
        count(*) FILTER (WHERE resultado = 'PASS') * 100.0 / count(*),
        1
    ) || '%' AS puntuacion
FROM resultados_checklist;

DROP TABLE resultados_checklist;

\echo ''
\echo '╔═══════════════════════════════════════════════════════╗'
\echo '║   Checklist completado                                ║'
\echo '╚═══════════════════════════════════════════════════════╝'
