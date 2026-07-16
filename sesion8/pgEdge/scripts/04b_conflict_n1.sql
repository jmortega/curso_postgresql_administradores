-- =============================================================
-- scripts/04b_conflict_n1.sql
-- Ejecutar en n1 (puerto 6432) — Terminal A
--
-- PGPASSWORD=Admin_Lab_2025 psql -h localhost -p 6432 \
--   -U admin ecommerce_db -f scripts/04b_conflict_n1.sql
-- =============================================================

\echo '═══════════════════════════════════════════════════'
\echo '  TERMINAL A — n1 (EU, puerto 6432)'
\echo '═══════════════════════════════════════════════════'

-- Paso 1: Pausar la suscripción que recibe cambios de n2
-- Esto impide que n1 aplique los cambios que n2 va a escribir
\echo ''
\echo '▸ Pausando suscripción sub_n1_n2 en n1...'
SELECT spock.sub_disable('sub_n1_n2');
SELECT pg_sleep(1);

-- Paso 2: Actualizar la fila en n1 con valor local
\echo '▸ Actualizando fila en n1 (valor: ACTUALIZADO_EN_N1)...'
UPDATE replication_test
SET msg = 'ACTUALIZADO_EN_N1_' || now()::text
WHERE node_name = 'conflicto-test';

\echo '▸ Valor en n1 tras UPDATE:'
SELECT id, node_name, msg, ts
FROM replication_test
WHERE node_name = 'conflicto-test';

-- Paso 3: Esperar 3 segundos (para que n2 también escriba)
\echo ''
\echo '▸ Esperando 3 segundos para que n2 escriba su valor...'
SELECT pg_sleep(3);

-- Paso 4: Reactivar la suscripción → Spock recibe el cambio de n2
-- y detecta el conflicto (misma fila, distinto valor)
\echo '▸ Reactivando suscripción sub_n1_n2 → Spock resolverá el conflicto...'
SELECT spock.sub_enable('sub_n1_n2');

-- Esperar a que la replicación aplique
SELECT pg_sleep(3);

\echo ''
\echo '▸ Valor final en n1 tras resolución del conflicto:'
SELECT id, node_name, msg, ts
FROM replication_test
WHERE node_name = 'conflicto-test';

\echo ''
\echo '✓ Ejecuta scripts/04d_check_conflicts.sql para ver el conflicto registrado'
