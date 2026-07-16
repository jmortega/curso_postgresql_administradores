-- =============================================================
-- scripts/04_simulate_conflicts.sql
-- Simula conflictos reales de replicación activo-activo
--
-- REQUISITO: tener datos en replication_test (ejecutar 02 antes)
--
-- Hay 3 métodos de menor a mayor complejidad:
--   Método A — Pausa manual de replicación  (recomendado)
--   Método B — Race condition con pg_sleep
--   Método C — UPDATE masivo simultáneo desde dos terminales
-- =============================================================

-- ══════════════════════════════════════════════════════════════
-- MÉTODO A — PAUSA + ESCRITURA SIMULTÁNEA (más fiable)
-- ══════════════════════════════════════════════════════════════
--
-- Cómo funciona:
--   1. En n1: pausar la suscripción que recibe de n2
--   2. En n2: modificar una fila
--   3. En n1: modificar la misma fila con un valor diferente
--   4. En n1: reanudar la suscripción → Spock detecta el conflicto
--
-- Ejecuta cada bloque en la terminal indicada.
-- ─────────────────────────────────────────────────────────────

-- ── PASO 1: Insertar fila de prueba en n1 ────────────────────
-- (ejecutar en n1, puerto 6432)

INSERT INTO replication_test (node_name, region, msg)
VALUES ('conflicto-test', 'test', 'fila compartida para conflicto')
ON CONFLICT DO NOTHING;

-- Guardar el ID para usarlo en los pasos siguientes
SELECT id, msg FROM replication_test WHERE node_name = 'conflicto-test';

-- Esperar 5 segundos para que la fila llegue a n2 y n3
SELECT pg_sleep(5);

\echo ''
\echo '✓ Fila de prueba insertada. Espera 5s y continúa con PASO 2.'
\echo ''
\echo 'PASO 2 — Abre DOS terminales y ejecuta en paralelo:'
\echo ''
\echo '  Terminal A (n1 - EU, puerto 6432):'
\echo '    PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \'
\echo '      -f scripts/04b_conflict_n1.sql'
\echo ''
\echo '  Terminal B (n2 - USA, puerto 6433):'
\echo '    PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db \'
\echo '      -f scripts/04c_conflict_n2.sql'
\echo ''
\echo '  Luego verifica con:'
\echo '    PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \'
\echo '      -f scripts/04d_check_conflicts.sql'
