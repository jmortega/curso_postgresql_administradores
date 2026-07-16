-- =============================================================
-- scripts/04d_check_conflicts.sql
-- Verifica los conflictos detectados por Spock
-- Ejecutar en cualquier nodo después de los scripts 04b y 04c
--
-- PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 \
--   -U admin ecommerce_db -f scripts/04d_check_conflicts.sql
-- =============================================================

\echo '══════════════════════════════════════════════════════════'
\echo '  Verificación de conflictos Spock'
\echo '══════════════════════════════════════════════════════════'

-- ── 1. Estado actual de la fila en cada nodo ─────────────────
\echo ''
\echo '▸ 1. Estado actual de la fila conflictiva:'
\echo '     (conecta a los 3 nodos para comparar)'
SELECT id, node_name, msg, ts
FROM replication_test
WHERE node_name = 'conflicto-test'
ORDER BY ts DESC;

-- ── 2. Conflictos registrados ─────────────────────────────────
\echo ''
\echo '▸ 2. Total de conflictos registrados en este nodo:'
SELECT count(*) AS total_conflictos FROM spock.resolutions;

-- ── 3. Detalle de conflictos ──────────────────────────────────
\echo ''
\echo '▸ 3. Detalle de los últimos conflictos:'
\echo '     conflict_type       → tipo de conflicto detectado'
\echo '     conflict_resolution → cómo lo resolvió Spock'
\echo '     local_tuple         → valor que tenía este nodo'
\echo '     remote_tuple        → valor que llegó del otro nodo'
SELECT
    id,
    node_name,
    log_time,
    relname                         AS tabla,
    idxname                         AS indice_conflicto,
    conflict_type,
    conflict_resolution,
    local_tuple::text               AS valor_local,
    remote_tuple::text              AS valor_remoto
FROM spock.resolutions
ORDER BY log_time DESC;

-- ── 4. Explicación del resultado ─────────────────────────────
\echo ''
\echo '▸ 4. Tipos de conflicto posibles en Spock:'
\echo ''
\echo '   insert_exists    → INSERT cuya PK ya existe en el nodo destino'
\echo '   update_missing   → UPDATE de una fila que no existe en el destino'
\echo '   update_differs   → UPDATE simultáneo de la misma fila (más común)'
\echo '   delete_missing   → DELETE de una fila que ya no existe'
\echo ''
\echo '▸ Resolución aplicada (configurada en postgresql.conf):'
\echo ''
\echo '   last_update_wins → gana el cambio con timestamp más reciente'
\echo '   first_update_wins→ gana el cambio más antiguo'
\echo '   apply_remote     → siempre gana el nodo remoto'
\echo '   keep_local       → siempre mantiene el valor local'

-- ── 5. Verificar convergencia: todos los nodos deben tener ────
--      el mismo valor final tras la resolución
\echo ''
\echo '▸ 5. Compara el valor en los 3 nodos (deben ser iguales):'
\echo ''
\echo '   PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \'
\echo '     -c "SELECT msg FROM replication_test WHERE node_name='"'"'conflicto-test'"'"';"'
\echo ''
\echo '   PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db \'
\echo '     -c "SELECT msg FROM replication_test WHERE node_name='"'"'conflicto-test'"'"';"'
\echo ''
\echo '   PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6434 -U admin ecommerce_db \'
\echo '     -c "SELECT msg FROM replication_test WHERE node_name='"'"'conflicto-test'"'"';"'
\echo ''
\echo '══════════════════════════════════════════════════════════'
\echo '  Si spock.resolutions está vacío en este nodo,'
\echo '  el conflicto se detectó en el otro nodo (n2).'
\echo '  Ejecuta este mismo script contra el puerto 6433.'
\echo '══════════════════════════════════════════════════════════'
