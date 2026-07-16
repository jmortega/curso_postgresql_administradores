-- =============================================================
-- scripts/04c_conflict_n2.sql
-- Ejecutar en n2 (puerto 6433) — Terminal B
-- (ejecutar SIMULTÁNEAMENTE con 04b_conflict_n1.sql)
--
-- PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 \
--   -U admin ecommerce_db -f scripts/04c_conflict_n2.sql
-- =============================================================

\echo '═══════════════════════════════════════════════════'
\echo '  TERMINAL B — n2 (USA, puerto 6433)'
\echo '═══════════════════════════════════════════════════'

-- Pequeña pausa para que n1 tenga tiempo de pausar su suscripción
\echo '▸ Esperando 2 segundos para sincronizar con n1...'
SELECT pg_sleep(2);

-- Actualizar la misma fila en n2 con un valor diferente
-- Como n1 tiene la suscripción pausada, recibirá este cambio
-- con retraso → conflicto con el cambio local de n1
\echo '▸ Actualizando la misma fila en n2 (valor: ACTUALIZADO_EN_N2)...'
UPDATE replication_test
SET msg = 'ACTUALIZADO_EN_N2_' || now()::text
WHERE node_name = 'conflicto-test';

\echo ''
\echo '▸ Valor en n2 tras UPDATE:'
SELECT id, node_name, msg, ts
FROM replication_test
WHERE node_name = 'conflicto-test';

\echo ''
\echo '✓ n2 ha escrito su valor. n1 reactivará su suscripción'
\echo '  y Spock resolverá el conflicto con last_update_wins.'
