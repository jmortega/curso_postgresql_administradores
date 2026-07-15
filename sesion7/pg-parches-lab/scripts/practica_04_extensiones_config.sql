-- =============================================================
-- practica_04_extensiones_config.sql
-- Práctica 4: Actualización de extensiones y recarga de configuración
-- sin reiniciar PostgreSQL
--
-- Ejecutar:
--   docker exec -it pg-primary psql -U postgres \
--     -f /scripts/practica_04_extensiones_config.sql
-- =============================================================

\echo ''
\echo '╔══════════════════════════════════════════════════════╗'
\echo '║   PRÁCTICA 4: Extensiones y Config Reload            ║'
\echo '╚══════════════════════════════════════════════════════╝'

-- ── 4.1 Estado actual de extensiones ─────────────────────────
\echo ''
\echo '▸ 4.1 Extensiones instaladas y su estado:'
SELECT
    name,
    installed_version    AS version_instalada,
    default_version      AS version_disponible,
    CASE
        WHEN installed_version = default_version THEN '✓ al día'
        WHEN installed_version < default_version THEN '⚠ actualización disponible'
        ELSE '? revisar'
    END AS estado
FROM pg_available_extensions
WHERE installed_version IS NOT NULL
ORDER BY name;

-- ── 4.2 Ver la ruta de actualización disponible ───────────────
\echo ''
\echo '▸ 4.2 Ruta de actualización de pg_stat_statements:'
SELECT source, target, path
FROM pg_extension_update_paths('pg_stat_statements')
WHERE source = (
    SELECT installed_version
    FROM pg_available_extensions
    WHERE name = 'pg_stat_statements'
)
ORDER BY target;

-- ── 4.3 Actualizar una extensión sin reinicio ────────────────
\echo ''
\echo '▸ 4.3 Actualizando extensiones (no requiere reinicio de PG):'
DO $$
DECLARE
    ext RECORD;
BEGIN
    FOR ext IN
        SELECT name, installed_version, default_version
        FROM pg_available_extensions
        WHERE installed_version IS NOT NULL
          AND installed_version != default_version
    LOOP
        RAISE NOTICE 'Actualizando: % (%  →  %)',
            ext.name, ext.installed_version, ext.default_version;
        EXECUTE format('ALTER EXTENSION %I UPDATE', ext.name);
    END LOOP;

    IF NOT FOUND THEN
        RAISE NOTICE '✓ Todas las extensiones ya están al día';
    END IF;
END;
$$;

-- ── 4.4 Extensiones en shared_preload_libraries ───────────────
\echo ''
\echo '▸ 4.4 Extensiones cargadas en shared_preload_libraries:'
SHOW shared_preload_libraries;
\echo '  Nota: cambios en shared_preload_libraries requieren reinicio'
\echo '  En clúster HA: rolling restart nodo a nodo via Patroni'

-- ── 4.5 Cambios de configuración con pg_reload_conf ──────────
\echo ''
\echo '▸ 4.5 Cambios de configuración sin reinicio (pg_reload_conf):'

-- Guardar el valor actual
SELECT name, setting AS valor_actual
FROM pg_settings
WHERE name IN ('log_min_duration_statement', 'work_mem', 'log_connections')
ORDER BY name;

-- Aplicar cambio de configuración
ALTER SYSTEM SET log_min_duration_statement = '500';
ALTER SYSTEM SET work_mem = '32MB';

-- Recargar sin reiniciar
SELECT pg_reload_conf() AS config_recargada;

-- Verificar que el cambio se aplicó
SELECT name, setting AS nuevo_valor, unit
FROM pg_settings
WHERE name IN ('log_min_duration_statement', 'work_mem')
ORDER BY name;

\echo '  ✓ Configuración recargada sin reinicio de PostgreSQL'

-- ── 4.6 Parámetros que sí requieren reinicio ─────────────────
\echo ''
\echo '▸ 4.6 Parámetros pendientes que requieren reinicio:'
SELECT name, setting AS valor_activo,
       boot_val AS valor_al_inicio,
       reset_val AS valor_pendiente_de_reset,
       context
FROM pg_settings
WHERE pending_restart = true
ORDER BY name;

SELECT
    CASE WHEN count(*) = 0
         THEN '✓ Sin parámetros pendientes de reinicio'
         ELSE count(*)::TEXT || ' parámetro(s) requieren reinicio para activarse'
    END AS estado
FROM pg_settings WHERE pending_restart;

-- ── 4.7 Restaurar configuración del lab ──────────────────────
\echo ''
\echo '▸ 4.7 Restaurando configuración original...'
ALTER SYSTEM RESET log_min_duration_statement;
ALTER SYSTEM RESET work_mem;
SELECT pg_reload_conf();
\echo '  ✓ Configuración restaurada'

\echo ''
\echo '✓ Práctica 4 completada'
\echo '╚══════════════════════════════════════════════════════╝'
