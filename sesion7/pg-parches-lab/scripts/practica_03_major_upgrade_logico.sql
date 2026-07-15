-- =============================================================
-- practica_03_major_upgrade_logico.sql
-- Práctica 3: Major Version Upgrade PostgreSQL 15 → 16
-- usando Replicación Lógica (zero downtime)
--
-- Arquitectura del lab:
--   pg-v15 (puerto 5435) → ORIGEN  (PostgreSQL 15)
--   Clúster PG16 (Patroni) → DESTINO
--
-- IMPORTANTE: ejecutar contra el LÍDER ACTUAL del clúster, no
-- necesariamente contra el contenedor pg-primary. Si ya hiciste la
-- Práctica 2 (rolling update), el switchover dejó a pgreplica1 como
-- líder. Comprueba primero cuál es el líder:
--   docker exec -it pg-primary patronictl -c /etc/patroni/patroni.yml list
--
-- y ejecuta este script contra ESE nodo, por ejemplo:
--   docker exec -it pg-replica1 psql -U postgres \
--     -f /scripts/practica_03_major_upgrade_logico.sql
-- =============================================================

\echo ''
\echo '╔══════════════════════════════════════════════════════╗'
\echo '║   PRÁCTICA 3: Major Upgrade v15 → v16 (Lógica)      ║'
\echo '╚══════════════════════════════════════════════════════╝'

-- ── 3.1 Verificar ambas instancias ───────────────────────────
\echo ''
\echo '▸ 3.1 Versiones del clúster:'
SELECT
    'destino (líder actual)' AS instancia,
    version()                AS version,
    pg_is_in_recovery()      AS en_recovery;

\echo '    Si en_recovery = t, este nodo NO es el líder — repite el'
\echo '    script contra el nodo que patronictl liste como Leader.'

-- ── 3.2 Verificar wal_level en el origen (pg-v15) ────────────
\echo ''
\echo '▸ 3.2 Verificar wal_level en el origen (pg-v15:5435):'
\echo '    Ejecutar manualmente: docker exec -it pg-v15 psql -U postgres -c "SHOW wal_level;"'
\echo '    Debe mostrar: logical'

-- ── 3.3 Crear la tabla destino en v16 (misma estructura que v15) ─
\echo ''
\echo '▸ 3.3 Crear tabla destino en v16 (misma estructura que v15):'

CREATE TABLE IF NOT EXISTS public.pedidos_v15 (
    id             BIGSERIAL PRIMARY KEY,
    cliente_id     INTEGER       NOT NULL,
    fecha          TIMESTAMP     NOT NULL DEFAULT now(),
    estado         VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
    importe        NUMERIC(10,2)
);

SELECT 'Tabla pedidos_v15 creada/existente en v16' AS resultado;

-- ── 3.4 Crear la suscripción lógica (v16 suscribe a v15) ─────
\echo ''
\echo '▸ 3.4 Crear suscripción lógica desde v16 → v15:'

-- Eliminar suscripción anterior si existe
DROP SUBSCRIPTION IF EXISTS sub_desde_v15;

CREATE SUBSCRIPTION sub_desde_v15
    CONNECTION 'host=pg-v15 port=5432 dbname=dwh user=logical_repl
                password=logical_lab_2025 connect_timeout=10'
    PUBLICATION pub_upgrade
    WITH (
        copy_data         = true,
        synchronous_commit = off,
        create_slot       = true
    );

SELECT 'Suscripción sub_desde_v15 creada' AS resultado;

-- Esperar unos segundos a que la copia inicial empiece
\echo '    Esperando 5s a que empiece la copia inicial...'
SELECT pg_sleep(5);

-- ── 3.5 Monitorizar el progreso de la copia inicial ──────────
\echo ''
\echo '▸ 3.5 Estado de la suscripción lógica:'
SELECT
    subname,
    received_lsn,
    latest_end_lsn,
    latest_end_time,
    CASE WHEN latest_end_time IS NOT NULL
         THEN now() - latest_end_time
         ELSE NULL
    END AS lag_tiempo
FROM pg_stat_subscription;

-- ── 3.6 Verificar datos sincronizados ────────────────────────
\echo ''
\echo '▸ 3.6 Verificar datos copiados desde v15 a v16:'
SELECT pg_sleep(5);   -- Dar tiempo para completar la copia

SELECT
    count(*)       AS filas_en_v16,
    min(fecha)     AS fecha_min,
    max(fecha)     AS fecha_max
FROM public.pedidos_v15;

\echo '    Para comparar con origen:'
\echo '    docker exec -it pg-v15 psql -U postgres -c "SELECT count(*) FROM pedidos_v15;"'

-- ── 3.7 Insertar en el origen y verificar que replica ─────────
\echo ''
\echo '▸ 3.7 Instrucciones para verificar replicación en tiempo real:'
\echo ''
\echo '    # Terminal 1: insertar en el ORIGEN (v15)'
\echo '    docker exec -it pg-v15 psql -U postgres -c "'
\echo '        INSERT INTO pedidos_v15 (cliente_id, estado, importe)'
\echo '        VALUES (9999, '\''nuevo_en_v15'\'', 777.77);"'
\echo ''
\echo '    # Terminal 2: verificar que llegó al DESTINO (v16)'
\echo '    docker exec -it pg-primary psql -U postgres -c "'
\echo '        SELECT * FROM pedidos_v15 WHERE cliente_id = 9999;"'

-- ── 3.8 Preparar el switchover ────────────────────────────────
\echo ''
\echo '▸ 3.8 Verificar lag antes del switchover:'
SELECT
    subname,
    CASE WHEN latest_end_time IS NOT NULL
         THEN now() - latest_end_time
         ELSE 'sin datos'::TEXT
    END AS lag_aproximado
FROM pg_stat_subscription;

\echo ''
\echo '    Cuando el lag sea < 1 segundo, ejecutar el switchover:'
\echo '    Ver practica_03b_switchover.sql'

\echo ''
\echo '✓ Suscripción lógica activa — replicación v15 → v16 en marcha'
\echo '╚══════════════════════════════════════════════════════╝'
