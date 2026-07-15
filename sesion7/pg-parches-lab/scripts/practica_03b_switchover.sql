-- =============================================================
-- practica_03b_switchover.sql
-- Switchover final del major upgrade v15 → v16
-- Ejecutar DESPUÉS de practica_03_major_upgrade_logico.sql
-- cuando el lag de replicación lógica sea ~0
--
-- IMPORTANTE: ejecutar contra el mismo nodo (líder actual del
-- clúster PG16) donde se ejecutó practica_03_major_upgrade_logico.sql.
-- Tras la Práctica 2, ese nodo suele ser pg-replica1, no pg-primary.
-- Verifica con: docker exec -it pg-primary patronictl -c /etc/patroni/patroni.yml list
--   docker exec -it pg-replica1 psql -U postgres \
--     -f /scripts/practica_03b_switchover.sql
-- =============================================================

\echo ''
\echo '╔══════════════════════════════════════════════════════╗'
\echo '║   PRÁCTICA 3b: Switchover v15 → v16                 ║'
\echo '╚══════════════════════════════════════════════════════╝'

-- ── Verificar lag antes de proceder ──────────────────────────
\echo ''
\echo '▸ Verificando lag de replicación lógica antes del switchover:'
SELECT
    subname,
    received_lsn,
    latest_end_lsn,
    EXTRACT(epoch FROM (now() - latest_end_time))::INT AS lag_segundos
FROM pg_stat_subscription;

\echo ''
\echo '▸ Conteo de filas en v16 (destino) vs v15 (origen):'
SELECT count(*) AS filas_en_v16 FROM public.pedidos_v15;
\echo '    Comparar con: docker exec -it pg-v15 psql -U postgres'
\echo '                  -c "SELECT count(*) FROM pedidos_v15;"'

-- ── Simular modo mantenimiento ────────────────────────────────
\echo ''
\echo '▸ Simulando modo mantenimiento en v15...'
\echo '  (En producción: activar feature flag / nginx 503 / etc.)'
\echo ''
\echo '  Ejecutar en v15 para bloquear escrituras nuevas:'
\echo '  docker exec -it pg-v15 psql -U postgres -c "'
\echo '    BEGIN; LOCK TABLE pedidos_v15 IN SHARE MODE;"'
\echo ''
\echo '  Verificar que el lag llegó a 0:'

-- Esperar a que el lag sea mínimo
DO $$
DECLARE
    lag_seconds NUMERIC;
    attempts    INT := 0;
BEGIN
    LOOP
        SELECT EXTRACT(epoch FROM (now() - latest_end_time))
        INTO lag_seconds
        FROM pg_stat_subscription
        WHERE subname = 'sub_desde_v15';

        IF lag_seconds IS NOT NULL AND lag_seconds < 2 THEN
            RAISE NOTICE '✓ Lag = % segundos — listo para switchover', round(lag_seconds, 1);
            EXIT;
        END IF;

        attempts := attempts + 1;
        IF attempts > 20 THEN
            RAISE WARNING 'Lag todavía en % segundos después de 20s', round(lag_seconds, 1);
            EXIT;
        END IF;

        PERFORM pg_sleep(1);
    END LOOP;
END;
$$;

-- ── Desactivar la suscripción (v16 ya no recibe de v15) ──────
\echo ''
\echo '▸ Desactivando suscripción lógica (v16 ya está al día):'
ALTER SUBSCRIPTION sub_desde_v15 DISABLE;

SELECT
    subname,
    subenabled AS activa,
    'Suscripción desactivada — v16 es ahora el sistema principal' AS estado
FROM pg_subscription
WHERE subname = 'sub_desde_v15';

-- ── Verificar datos finales en v16 ────────────────────────────
\echo ''
\echo '▸ Datos finales en v16 después del switchover:'
SELECT
    count(*)                                        AS total_filas,
    count(*) FILTER (WHERE estado='pendiente')      AS pendientes,
    count(*) FILTER (WHERE estado='procesado')      AS procesados,
    count(*) FILTER (WHERE estado='cancelado')      AS cancelados,
    round(sum(importe)::numeric,2)                  AS importe_total
FROM public.pedidos_v15;

-- ── Sincronizar secuencias (paso CRÍTICO antes de aceptar escrituras) ──
-- La replicación lógica replica los VALORES de fila (INSERT/UPDATE/
-- DELETE), pero nunca el estado de las secuencias. La secuencia
-- pedidos_v15_id_seq en v16 se creó desde cero al hacer CREATE TABLE
-- (Paso 3.3) y sigue en su valor inicial, aunque la tabla ya tenga
-- filas con IDs mucho más altos copiados desde v15. Si no se corrige
-- aquí, el primer INSERT nuevo en v16 intentará reutilizar un ID que
-- ya existe → "duplicate key value violates unique constraint".
\echo ''
\echo '▸ Sincronizando secuencias (la replicación lógica NO las replica):'

DO $$
DECLARE
    seq_name TEXT;
    max_id   BIGINT;
BEGIN
    SELECT pg_get_serial_sequence('public.pedidos_v15', 'id') INTO seq_name;
    SELECT COALESCE(MAX(id), 0) INTO max_id FROM public.pedidos_v15;

    IF seq_name IS NULL THEN
        RAISE WARNING 'No se encontró una secuencia asociada a pedidos_v15.id — revisar manualmente';
    ELSE
        PERFORM setval(seq_name, max_id);
        RAISE NOTICE '✓ Secuencia % sincronizada a % (MAX(id) actual)', seq_name, max_id;
    END IF;
END;
$$;

-- ── Probar escritura en v16 ────────────────────────────────────
\echo ''
\echo '▸ Verificando que v16 acepta escrituras (como nuevo sistema principal):'
INSERT INTO public.pedidos_v15 (cliente_id, estado, importe)
VALUES (88888, 'procesado', 999.99);

SELECT id, cliente_id, estado, importe, fecha
FROM public.pedidos_v15
WHERE cliente_id = 88888;

-- ── Limpieza ──────────────────────────────────────────────────
\echo ''
\echo '▸ Limpieza de la infraestructura de migración:'
\echo '  Ejecutar en v16 cuando se confirme OK:'
\echo '  DROP SUBSCRIPTION sub_desde_v15;'
\echo ''
\echo '  Ejecutar en v15 cuando se confirme OK:'
\echo '  docker exec -it pg-v15 psql -U postgres -c "DROP PUBLICATION pub_upgrade;"'

\echo ''
\echo '╔══════════════════════════════════════════════════════╗'
\echo '║   ✓ SWITCHOVER COMPLETADO — v16 es el sistema activo ║'
\echo '║   RTO del switchover: < 10 segundos                  ║'
\echo '╚══════════════════════════════════════════════════════╝'
