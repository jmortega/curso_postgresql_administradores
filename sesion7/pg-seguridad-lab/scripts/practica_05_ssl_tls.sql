-- =============================================================
-- practica_05_ssl_tls.sql
-- Práctica 5: Verificación de SSL/TLS desde dentro del contenedor
--
-- Ejecutar con:
--   docker exec -it pg-security psql -U postgres -d dwh \
--     -f /scripts/practica_05_ssl_tls.sql
-- =============================================================

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  PRÁCTICA 5: Cifrado en Tránsito SSL/TLS'
\echo '═══════════════════════════════════════════════════════'

-- ── 5.1 Estado SSL del servidor ───────────────────────────────
\echo ''
\echo '▸ 5.1 Configuración SSL activa en el servidor:'
SELECT name, setting
FROM pg_settings
WHERE name IN (
    'ssl',
    'ssl_min_protocol_version',
    'ssl_ciphers',
    'ssl_prefer_server_ciphers',
    'ssl_cert_file',
    'ssl_key_file',
    'ssl_ca_file'
)
ORDER BY name;

-- ── 5.2 Ver conexiones activas y su estado SSL ────────────────
\echo ''
\echo '▸ 5.2 Conexiones activas y si usan SSL:'
SELECT
    a.pid,
    a.usename,
    a.application_name,
    a.client_addr,
    CASE WHEN s.ssl THEN '🔒 SSL (' || s.version || ')' ELSE '⚠ Sin SSL' END AS cifrado,
    s.cipher
FROM pg_stat_activity a
LEFT JOIN pg_stat_ssl s ON s.pid = a.pid
WHERE a.usename IS NOT NULL
  AND a.pid != pg_backend_pid()
ORDER BY s.ssl DESC, a.usename;

-- ── 5.3 Estado SSL de la conexión actual ─────────────────────
\echo ''
\echo '▸ 5.3 Estado SSL de ESTA conexión:'
SELECT
    ssl,
    version          AS tls_version,
    cipher,
    bits             AS bits_cifrado,
    client_dn,
    issuer_dn
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();

-- ── 5.4 Verificar que los certificados están disponibles ─────
\echo ''
\echo '▸ 5.4 Verificando certificados SSL del servidor:'

DO $$
DECLARE
    cert_path TEXT;
    key_path  TEXT;
    ca_path   TEXT;
BEGIN
    SELECT setting INTO cert_path FROM pg_settings WHERE name = 'ssl_cert_file';
    SELECT setting INTO key_path  FROM pg_settings WHERE name = 'ssl_key_file';
    SELECT setting INTO ca_path   FROM pg_settings WHERE name = 'ssl_ca_file';

    -- Verificar que los ficheros existen usando pg_read_file (solo primeros bytes)
    BEGIN
        PERFORM pg_read_file(cert_path, 0, 1);
        RAISE NOTICE '✓ Certificado del servidor encontrado: %', cert_path;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠ Certificado no accesible: %', cert_path;
    END;

    BEGIN
        PERFORM pg_read_file(ca_path, 0, 1);
        RAISE NOTICE '✓ Certificado CA encontrado: %', ca_path;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠ CA no accesible: %', ca_path;
    END;
END;
$$;

-- ── 5.5 Detectar conexiones sin SSL ──────────────────────────
\echo ''
\echo '▸ 5.5 Conexiones SIN SSL desde red (posible alerta de seguridad):'
SELECT
    a.pid,
    a.usename,
    a.client_addr,
    a.application_name,
    '⚠ Conexión sin cifrar' AS alerta
FROM pg_stat_activity a
JOIN pg_stat_ssl s ON s.pid = a.pid
WHERE NOT s.ssl
  AND a.client_addr IS NOT NULL
  AND a.usename IS NOT NULL;

SELECT
    CASE WHEN count(*) = 0
         THEN '✓ Todas las conexiones de red usan SSL'
         ELSE count(*)::TEXT || ' conexión(es) sin SSL detectadas'
    END AS estado_ssl
FROM pg_stat_activity a
JOIN pg_stat_ssl s ON s.pid = a.pid
WHERE NOT s.ssl
  AND a.client_addr IS NOT NULL;

-- ── 5.6 Instrucciones para conectar con SSL desde el host ─────
\echo ''
\echo '▸ 5.6 Comandos para conectar con SSL desde el HOST:'
\echo ''
\echo '    # Copiar el certificado CA al host:'
\echo '    docker cp pg-security:/etc/postgresql/ssl/ca.crt ./ca.crt'
\echo ''
\echo '    # Conectar con SSL verificado:'
\echo '    psql "host=localhost port=5432 dbname=dwh user=app_backend'
\echo '          sslmode=verify-ca sslrootcert=./ca.crt"'
\echo '          Password: app_pass_2025'
\echo ''
\echo '    # Verificar SSL en la conexión:'
\echo '    psql "..." -c "SELECT ssl, version FROM pg_stat_ssl WHERE pid=pg_backend_pid()"'

-- ── 5.7 Ver configuración de pg_hba para SSL ─────────────────
\echo ''
\echo '▸ 5.7 Reglas pg_hba.conf relacionadas con SSL:'
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    auth_method
FROM pg_hba_file_rules
WHERE type IN ('hostssl', 'hostnossl')
   OR auth_method = 'cert'
ORDER BY line_number;

\echo ''
\echo '✓ Práctica 5 completada'
\echo '═══════════════════════════════════════════════════════'
