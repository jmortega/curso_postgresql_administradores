-- =============================================================
-- scripts/validation/validate_mysql_migration.sql
-- Validación post-migración MySQL → PostgreSQL
--
-- Ejecutar contra PG17 (BD tienda_mysql_migrada):
--   PGPASSWORD=postgres_lab psql -h localhost -p 5417 \
--     -U postgres tienda_mysql_migrada \
--     -f scripts/validation/validate_mysql_migration.sql
-- =============================================================

\echo '══════════════════════════════════════════════════════════'
\echo '  Validación post-migración MySQL → PostgreSQL'
\echo '══════════════════════════════════════════════════════════'

-- ── 1. Conteo de filas ────────────────────────────────────────
\echo ''
\echo '▸ 1. Filas migradas por tabla:'
\echo '     (comparar con: SELECT count(*) FROM <tabla> en MySQL)'
SELECT 'categorias'   AS tabla, count(*) AS filas FROM categorias
UNION ALL
SELECT 'clientes',             count(*) FROM clientes
UNION ALL
SELECT 'productos',            count(*) FROM productos
UNION ALL
SELECT 'pedidos',              count(*) FROM pedidos
UNION ALL
SELECT 'lineas_pedido',        count(*) FROM lineas_pedido
ORDER BY tabla;

-- ── 2. Verificar mapeo de tipos ───────────────────────────────
\echo ''
\echo '▸ 2. Tipos de datos post-migración (TINYINT→BOOLEAN, etc.):'
SELECT
    column_name     AS columna,
    data_type       AS tipo_pg,
    udt_name        AS tipo_interno
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'clientes'
ORDER BY ordinal_position;

-- ── 3. Verificar conversión TINYINT → BOOLEAN ────────────────
\echo ''
\echo '▸ 3. Conversión TINYINT(1) → BOOLEAN en clientes:'
SELECT id, email, activo, pg_typeof(activo) AS tipo_activo
FROM clientes
ORDER BY id;

-- ── 4. Verificar DATETIME → TIMESTAMPTZ ─────────────────────
\echo ''
\echo '▸ 4. Conversión DATETIME → TIMESTAMPTZ (debe incluir zona horaria):'
SELECT id, email, creado_en, pg_typeof(creado_en) AS tipo_ts
FROM clientes
LIMIT 3;

-- ── 5. Verificar DECIMAL → NUMERIC ──────────────────────────
\echo ''
\echo '▸ 5. Precisión de precios tras migración DECIMAL → NUMERIC:'
SELECT id, sku, precio, precio_coste,
       pg_typeof(precio) AS tipo_precio
FROM productos
ORDER BY id;

-- ── 6. Integridad referencial ────────────────────────────────
\echo ''
\echo '▸ 6. Integridad referencial — pedidos huérfanos:'
SELECT count(*) AS pedidos_sin_cliente
FROM pedidos p
LEFT JOIN clientes c ON c.id = p.cliente_id
WHERE c.id IS NULL;

\echo '▸ 6b. Líneas sin pedido padre:'
SELECT count(*) AS lineas_huerfanas
FROM lineas_pedido lp
LEFT JOIN pedidos p ON p.id = lp.pedido_id
WHERE p.id IS NULL;

-- ── 7. Verificar constraint de estado ────────────────────────
\echo ''
\echo '▸ 7. Constraint CHECK en columna estado:'
SELECT
    constraint_name,
    check_clause
FROM information_schema.check_constraints
WHERE constraint_schema = 'public'
  AND constraint_name LIKE 'chk_%';

-- ── 8. Verificar que no hay NULL inesperados ─────────────────
\echo ''
\echo '▸ 8. Valores NULL críticos (deben ser 0 en todos):'
SELECT
    sum(CASE WHEN email IS NULL     THEN 1 ELSE 0 END) AS emails_nulos,
    sum(CASE WHEN nombre IS NULL    THEN 1 ELSE 0 END) AS nombres_nulos,
    sum(CASE WHEN creado_en IS NULL THEN 1 ELSE 0 END) AS fechas_nulas
FROM clientes;

SELECT
    sum(CASE WHEN total IS NULL    THEN 1 ELSE 0 END) AS totales_nulos,
    sum(CASE WHEN estado IS NULL   THEN 1 ELSE 0 END) AS estados_nulos
FROM pedidos;

-- ── 9. Verificar totales financieros ────────────────────────
\echo ''
\echo '▸ 9. Totales financieros (comparar con MySQL):'
SELECT
    count(*)        AS num_pedidos,
    sum(total)      AS total_facturado,
    avg(total)      AS ticket_medio,
    min(total)      AS minimo,
    max(total)      AS maximo
FROM pedidos;

-- ── 10. Info de la migración ─────────────────────────────────
\echo ''
\echo '▸ 10. Metadatos de la migración (si existe la tabla):'
DO $$
DECLARE
    r RECORD;
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public' AND tablename = '_migracion_info'
    ) THEN
        FOR r IN EXECUTE 'SELECT clave, valor, ts FROM _migracion_info ORDER BY clave'
        LOOP
            RAISE NOTICE '  %: % (ts: %)', r.clave, r.valor, r.ts;
        END LOOP;
    ELSE
        RAISE NOTICE '  _migracion_info no existe — el AFTER LOAD DO de pgloader no se ejecutó.';
        RAISE NOTICE '  Puedes crearlo manualmente con scripts/mysql/pgloader_after.sql';
    END IF;
END $$;

\echo ''
\echo '══════════════════════════════════════════════════════════'
\echo '  Para comparar con MySQL directamente:'
\echo '  mysql -h 127.0.0.1 -P 3306 -u root -proot_lab tienda_mysql \'
\echo '    -e "SELECT count(*) FROM clientes; SELECT sum(total) FROM pedidos;"'
\echo '══════════════════════════════════════════════════════════'
