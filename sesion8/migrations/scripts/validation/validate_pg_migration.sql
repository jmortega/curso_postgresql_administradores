-- =============================================================
-- scripts/validation/validate_pg_migration.sql
-- Validación exhaustiva post-migración PG14 → PG17
--
-- Ejecutar contra PG17 comparando con PG14 vía dblink:
--   PGPASSWORD=postgres_lab psql -h localhost -p 5417 \
--     -U postgres tienda_v2 \
--     -f scripts/validation/validate_pg_migration.sql
-- =============================================================

\echo '══════════════════════════════════════════════════════════'
\echo '  Validación post-migración PG14 → PG17'
\echo '══════════════════════════════════════════════════════════'

-- ── 1. Verificar que las tablas existen ───────────────────────
\echo ''
\echo '▸ 1. Tablas presentes en PG17:'
SELECT tablename, tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ── 2. Conteo de filas por tabla ─────────────────────────────
\echo ''
\echo '▸ 2. Conteo de filas (verificar igual que PG14):'
SELECT
    t.tablename                                         AS tabla,
    (xpath('/row/c/text()',
        query_to_xml(format('SELECT count(*) AS c FROM %I', t.tablename),
                     false, false, ''))
    )[1]::text::bigint                                  AS filas
FROM pg_tables t
WHERE t.schemaname = 'public'
  AND t.tablename NOT LIKE '\_%'
ORDER BY t.tablename;

-- ── 3. Verificar integridad referencial ───────────────────────
\echo ''
\echo '▸ 3. Integridad referencial — pedidos sin cliente válido:'
SELECT count(*) AS pedidos_huerfanos
FROM pedidos p
LEFT JOIN clientes c ON c.id = p.cliente_id
WHERE c.id IS NULL;

\echo '▸ 3b. Líneas de pedido sin pedido válido:'
SELECT count(*) AS lineas_huerfanas
FROM lineas_pedido lp
LEFT JOIN pedidos p ON p.id = lp.pedido_id
WHERE p.id IS NULL;

-- ── 4. Verificar tipos de datos migrados ─────────────────────
\echo ''
\echo '▸ 4. Tipos de datos de las columnas clave:'
SELECT
    table_name      AS tabla,
    column_name     AS columna,
    data_type       AS tipo,
    udt_name        AS tipo_udt,
    is_nullable     AS nulable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('clientes','productos','pedidos','lineas_pedido')
  AND column_name IN ('id','email','precio','total','estado',
                      'creado_en','activo','direccion','atributos')
ORDER BY table_name, column_name;

-- ── 5. Verificar ENUMs migrados ───────────────────────────────
\echo ''
\echo '▸ 5. Tipos ENUM presentes en PG17:'
SELECT t.typname AS enum_name,
       string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS valores
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
GROUP BY t.typname
ORDER BY t.typname;

-- ── 6. Verificar índices ──────────────────────────────────────
\echo ''
\echo '▸ 6. Índices creados en PG17:'
SELECT
    tablename   AS tabla,
    indexname   AS indice,
    indexdef    AS definicion
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename NOT LIKE '_%'
ORDER BY tablename, indexname;

-- ── 7. Verificar vistas ───────────────────────────────────────
\echo ''
\echo '▸ 7. Vistas migradas:'
SELECT viewname, viewowner
FROM pg_views
WHERE schemaname = 'public'
ORDER BY viewname;

-- ── 8. Verificar funciones y triggers ────────────────────────
\echo ''
\echo '▸ 8. Funciones migradas:'
SELECT
    routine_name    AS funcion,
    routine_type    AS tipo,
    data_type       AS retorno
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;

\echo ''
\echo '▸ 8b. Triggers activos:'
SELECT
    trigger_name,
    event_object_table  AS tabla,
    event_manipulation  AS evento,
    action_timing       AS momento
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ── 9. Verificar secuencias (auto-increment) ─────────────────
\echo ''
\echo '▸ 9. Secuencias y valor actual:'
SELECT
    sequencename,
    last_value,
    increment_by
FROM pg_sequences
WHERE schemaname = 'public'
ORDER BY sequencename;

-- ── 10. Verificar datos JSONB ────────────────────────────────
\echo ''
\echo '▸ 10. Columnas JSONB — clientes con dirección completa:'
SELECT
    id,
    email,
    direccion->>'ciudad'     AS ciudad,
    direccion->>'cp'         AS codigo_postal
FROM clientes
WHERE direccion IS NOT NULL
ORDER BY id;

-- ── 11. Resumen final ────────────────────────────────────────
\echo ''
\echo '▸ 11. Resumen de validación:'
SELECT
    (SELECT count(*) FROM clientes)       AS clientes,
    (SELECT count(*) FROM productos)      AS productos,
    (SELECT count(*) FROM pedidos)        AS pedidos,
    (SELECT count(*) FROM lineas_pedido)  AS lineas,
    (SELECT sum(total) FROM pedidos)      AS total_facturado,
    (SELECT max(creado_en) FROM pedidos)  AS ultimo_pedido;

\echo ''
\echo '✓ Validación completada'
\echo '  Compara los valores con los de PG14 (puerto 5414)'
\echo '══════════════════════════════════════════════════════════'
