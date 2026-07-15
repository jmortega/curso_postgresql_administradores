-- =============================================================
-- practica_01_autenticacion.sql
-- Práctica 1: pg_hba.conf, métodos de autenticación y endurecimiento
--
-- Ejecutar con:
--   docker exec -it pg-security psql -U postgres -d dwh \
--     -f /scripts/practica_01_autenticacion.sql
-- =============================================================

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  PRÁCTICA 1: Autenticación y pg_hba.conf'
\echo '═══════════════════════════════════════════════════════'

-- ── 1.1 Ver la configuración actual de pg_hba ─────────────────
\echo ''
\echo '▸ 1.1 Reglas activas en pg_hba.conf:'
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    auth_method
FROM pg_hba_file_rules
ORDER BY line_number;

-- ── 1.2 Verificar el método de cifrado de contraseñas ─────────
\echo ''
\echo '▸ 1.2 Método de cifrado de contraseñas:'
SHOW password_encryption;

-- ── 1.3 Detectar usuarios con contraseñas MD5 (si las hubiera) ─
\echo ''
\echo '▸ 1.3 Usuarios con hash MD5 (deben migrarse a SCRAM):'
SELECT usename,
       left(passwd, 10) AS tipo_hash,
       CASE
           WHEN passwd LIKE 'md5%'       THEN '⚠ MD5 — migrar a SCRAM'
           WHEN passwd LIKE 'SCRAM-SHA%' THEN '✓ SCRAM-SHA-256'
           WHEN passwd IS NULL           THEN '⚠ sin contraseña'
           ELSE passwd
       END AS estado
FROM pg_shadow
ORDER BY usename;

-- ── 1.4 Estado de expiración de contraseñas ───────────────────
\echo ''
\echo '▸ 1.4 Estado de expiración de contraseñas por rol:'
SELECT
    rolname,
    rolvaliduntil,
    CASE
        WHEN rolvaliduntil IS NULL
            THEN '⚠  SIN EXPIRACIÓN'
        WHEN rolvaliduntil < now()
            THEN '🔴 EXPIRADA'
        WHEN rolvaliduntil < now() + INTERVAL '30 days'
            THEN '🟡 EXPIRA EN < 30 DÍAS'
        ELSE
            '🟢 VÁLIDA hasta ' || rolvaliduntil::DATE::TEXT
    END AS estado
FROM pg_roles
WHERE rolcanlogin
ORDER BY rolvaliduntil NULLS FIRST;

-- ── 1.5 Resetear contraseña a SCRAM (ejemplo) ─────────────────
\echo ''
\echo '▸ 1.5 Actualizando contraseña de app_backend a SCRAM-SHA-256...'
ALTER USER app_backend PASSWORD 'app_pass_2025';
SELECT usename, left(passwd, 12) AS tipo_hash
FROM pg_shadow WHERE usename = 'app_backend';

-- ── 1.6 Ver timeouts de seguridad configurados ────────────────
\echo ''
\echo '▸ 1.6 Timeouts de seguridad activos:'
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'statement_timeout',
    'lock_timeout',
    'idle_in_transaction_session_timeout',
    'idle_session_timeout',
    'authentication_timeout'
)
ORDER BY name;

-- ── 1.7 Ver roles con privilegios excesivos ───────────────────
\echo ''
\echo '▸ 1.7 Roles con superusuario o capacidad de crear roles:'
SELECT
    rolname,
    rolsuper        AS superusuario,
    rolcreaterole   AS puede_crear_roles,
    rolcreatedb     AS puede_crear_bds,
    rolcanlogin     AS puede_login,
    rolconnlimit    AS limite_conexiones
FROM pg_roles
WHERE rolsuper OR rolcreaterole
ORDER BY rolname;

-- ── 1.8 Recargar pg_hba.conf sin reiniciar ────────────────────
\echo ''
\echo '▸ 1.8 Recargando configuración...'
SELECT pg_reload_conf() AS configuracion_recargada;

\echo ''
\echo '✓ Práctica 1 completada'
\echo '═══════════════════════════════════════════════════════'
