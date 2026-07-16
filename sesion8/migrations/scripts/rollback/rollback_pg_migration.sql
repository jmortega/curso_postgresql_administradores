-- =============================================================
-- scripts/rollback/rollback_pg_migration.sql
-- Estrategia de rollback para migración PG14 → PG17
--
-- CUÁNDO USAR:
--   Si la validación post-migración detecta errores críticos
--   y necesitas volver al estado anterior.
--
-- PREMISA:
--   El rollback más seguro es NO haber desconectado PG14 aún.
--   Esta guía asume que PG14 sigue en marcha y PG17 es el
--   nodo que hay que limpiar/reinicializar.
-- =============================================================

\echo '══════════════════════════════════════════════════════════'
\echo '  ROLLBACK — Migración PG14 → PG17'
\echo '══════════════════════════════════════════════════════════'
\echo ''
\echo '  IMPORTANTE: ejecutar contra PG17 (puerto 5417)'
\echo '  PG14 (puerto 5414) NO se toca — sigue siendo el origen'
\echo ''

-- ── PASO 1: Verificar que PG14 sigue operativo ───────────────
\echo '▸ PASO 1 — Verificar disponibilidad de PG14 antes de rollback'
\echo '  En otra terminal:'
\echo '  PGPASSWORD=postgres_lab psql -h localhost -p 5414 \'
\echo '    -U postgres tienda_v1 -c "SELECT count(*) FROM pedidos;"'
\echo ''

-- ── PASO 2: Registrar el rollback ────────────────────────────
\echo '▸ PASO 2 — Registrar inicio del rollback'
UPDATE _migracion_control
SET valor = 'rollback_iniciado', ts = now()
WHERE clave = 'estado';

-- ── PASO 3: Punto de control — guardar estado actual ────────
\echo '▸ PASO 3 — Guardar inventario del estado actual en PG17'
CREATE TABLE IF NOT EXISTS _rollback_snapshot AS
SELECT
    (SELECT count(*) FROM clientes)       AS clientes,
    (SELECT count(*) FROM productos)      AS productos,
    (SELECT count(*) FROM pedidos)        AS pedidos,
    (SELECT count(*) FROM lineas_pedido)  AS lineas,
    now()                                  AS ts_rollback;

SELECT * FROM _rollback_snapshot;

-- ── PASO 4: Desconectar aplicación de PG17 ───────────────────
\echo ''
\echo '▸ PASO 4 — Terminar conexiones activas a tienda_v2'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'tienda_v2'
  AND pid <> pg_backend_pid();

-- ── PASO 5: Limpiar PG17 (si se desea reintentar la migración)
\echo ''
\echo '▸ PASO 5 — Limpiar datos migrados en PG17 (preparar para reintento)'
\echo '  ATENCIÓN: esto elimina TODOS los datos de PG17'
\echo '  Descomenta las líneas siguientes solo si estás seguro:'
\echo ''
-- DROP TABLE IF EXISTS lineas_pedido CASCADE;
-- DROP TABLE IF EXISTS pedidos CASCADE;
-- DROP TABLE IF EXISTS productos CASCADE;
-- DROP TABLE IF EXISTS clientes CASCADE;
-- DROP TABLE IF EXISTS categorias CASCADE;
-- DROP TABLE IF EXISTS auditoria CASCADE;
-- DROP TYPE  IF EXISTS estado_pedido;
-- DROP TYPE  IF EXISTS metodo_pago;
-- DROP VIEW  IF EXISTS resumen_pedidos;
-- DROP FUNCTION IF EXISTS fn_auditoria();

-- ── PASO 6: Redirigir tráfico a PG14 ────────────────────────
\echo ''
\echo '▸ PASO 6 — Redirigir la aplicación a PG14'
\echo '  Actualiza la cadena de conexión en tu aplicación:'
\echo '  DE:  postgres://postgres:***@localhost:5417/tienda_v2'
\echo '  A:   postgres://postgres:***@localhost:5414/tienda_v1'
\echo ''
\echo '  Variables de entorno típicas:'
\echo '  DATABASE_URL=postgresql://postgres:postgres_lab@localhost:5414/tienda_v1'

-- ── PASO 7: Verificar que PG14 acepta tráfico ───────────────
\echo ''
\echo '▸ PASO 7 — Verificar estado de PG14'
\echo '  PGPASSWORD=postgres_lab psql -h localhost -p 5414 \'
\echo '    -U postgres tienda_v1 \'
\echo '    -c "SELECT count(*), max(creado_en) FROM pedidos;"'

-- ── REGISTRO FINAL ────────────────────────────────────────────
UPDATE _migracion_control
SET valor = 'rollback_completado', ts = now()
WHERE clave = 'estado';

INSERT INTO _migracion_control (clave, valor)
VALUES ('rollback_motivo', 'Validación fallida — ver _rollback_snapshot')
ON CONFLICT (clave) DO UPDATE SET valor = EXCLUDED.valor, ts = now();

\echo ''
\echo '✓ Rollback registrado. PG14 sigue siendo el nodo activo.'
\echo '  Corrige los errores y reintenta la migración con:'
\echo '  bash scripts/migration/migrate_pg.sh'
\echo '══════════════════════════════════════════════════════════'
