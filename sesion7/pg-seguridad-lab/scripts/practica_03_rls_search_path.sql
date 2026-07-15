-- =============================================================
-- practica_03_rls_search_path.sql
-- Práctica 3: Seguridad a nivel de esquema, search_path y de fila (RLS)
--
-- Ejecutar con:
--   docker exec -it pg-security psql -U postgres -d dwh \
--     -f /scripts/practica_03_rls_search_path.sql
-- =============================================================

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  PRÁCTICA 3: search_path y Row Level Security (RLS)'
\echo '═══════════════════════════════════════════════════════'

-- ── 3.1 Demostrar el riesgo del search_path ───────────────────
\echo ''
\echo '▸ 3.1 Demostración del riesgo de search_path no controlado:'

-- Crear una función maliciosa en public (simulación educativa)
CREATE OR REPLACE FUNCTION public.lower(text)
RETURNS text LANGUAGE sql AS $$
    -- Función que SOBREESCRIBE lower() si search_path incluye public antes de pg_catalog
    SELECT pg_catalog.lower($1) || ' [INTERCEPTADA]';
$$;

-- Con search_path no controlado, la función maliciosa se ejecutaría
SET search_path = public, pg_catalog;
SELECT lower('TEXTO DE PRUEBA') AS resultado_con_search_path_peligroso;

-- Con search_path controlado, pg_catalog tiene prioridad
SET search_path = pg_catalog, public;
SELECT lower('TEXTO DE PRUEBA') AS resultado_con_search_path_seguro;

-- Limpiar la función maliciosa
DROP FUNCTION IF EXISTS public.lower(text);
RESET search_path;
\echo '    → Función maliciosa eliminada'

-- ── 3.2 Verificar search_path por rol ────────────────────────
\echo ''
\echo '▸ 3.2 search_path configurado por rol:'
SELECT
    rolname,
    array_to_string(
        ARRAY(
            SELECT elem FROM unnest(rolconfig) elem
            WHERE elem LIKE '%search_path%'
        ), ' '
    ) AS search_path_config
FROM pg_roles
WHERE rolconfig IS NOT NULL
  AND rolname NOT LIKE 'pg_%'
ORDER BY rolname;

-- ── 3.3 Activar RLS en raw.pedidos ────────────────────────────
\echo ''
\echo '▸ 3.3 Activando Row Level Security en raw.pedidos...'

ALTER TABLE raw.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw.pedidos FORCE ROW LEVEL SECURITY;

-- Verificar que RLS está activo
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname = 'pedidos' AND relnamespace = 'raw'::regnamespace;

-- ── 3.4 Crear políticas RLS ───────────────────────────────────
\echo ''
\echo '▸ 3.4 Creando políticas de Row Level Security:'

-- Eliminar políticas existentes si las hay
DROP POLICY IF EXISTS politica_pedidos_lectura    ON raw.pedidos;
DROP POLICY IF EXISTS politica_pedidos_escritura  ON raw.pedidos;
DROP POLICY IF EXISTS politica_pedidos_update     ON raw.pedidos;
DROP POLICY IF EXISTS politica_pedidos_admin      ON raw.pedidos;
DROP POLICY IF EXISTS politica_por_region         ON raw.pedidos;
DROP POLICY IF EXISTS solo_pedidos_activos        ON raw.pedidos;

-- Política 1: el usuario ve solo sus propios pedidos (por cliente_id)
CREATE POLICY politica_pedidos_lectura
    ON raw.pedidos
    FOR SELECT
    TO role_app_read, role_app_write
    USING (
        cliente_id = NULLIF(current_setting('app.current_client_id', true), '')::INT
    );

-- Política 2: solo puede insertar pedidos para su propio cliente_id
CREATE POLICY politica_pedidos_escritura
    ON raw.pedidos
    FOR INSERT
    TO role_app_write
    WITH CHECK (
        cliente_id = NULLIF(current_setting('app.current_client_id', true), '')::INT
    );

-- Política 3: solo puede actualizar sus propios pedidos
CREATE POLICY politica_pedidos_update
    ON raw.pedidos
    FOR UPDATE
    TO role_app_write
    USING (
        cliente_id = NULLIF(current_setting('app.current_client_id', true), '')::INT
    )
    WITH CHECK (
        cliente_id = NULLIF(current_setting('app.current_client_id', true), '')::INT
    );

-- Política 4: administradores ven todo
CREATE POLICY politica_pedidos_admin
    ON raw.pedidos
    FOR ALL
    TO role_dba
    USING (true)
    WITH CHECK (true);

-- Política 5: agentes ven solo pedidos de sus regiones (PERMISSIVE)
CREATE POLICY politica_por_region
    ON raw.pedidos
    FOR SELECT
    TO agente_norte, agente_sur
    USING (
        EXISTS (
            SELECT 1 FROM raw.permisos_agente pa
            WHERE pa.agente_id = current_user
              AND pa.region    = (raw.pedidos.metadatos_pago->>'region')
        )
    );

-- Política 6: filtro adicional — nunca mostrar cancelados (RESTRICTIVE)
CREATE POLICY solo_pedidos_activos
    ON raw.pedidos
    AS RESTRICTIVE
    FOR SELECT
    TO agente_norte, agente_sur
    USING (estado != 'cancelado');

SELECT policyname, roles, cmd, permissive FROM pg_policies
WHERE tablename = 'pedidos'
ORDER BY policyname;

-- ── 3.5 Probar RLS para un cliente específico ─────────────────
\echo ''
\echo '▸ 3.5 Prueba de RLS — cliente 42 solo ve sus pedidos:'

SET ROLE app_backend;

BEGIN;
SET LOCAL app.current_client_id = '42';

SELECT count(*) AS pedidos_del_cliente_42
FROM raw.pedidos;

SELECT id, cliente_id, estado, importe
FROM raw.pedidos
LIMIT 5;

-- Verificar que TODOS los pedidos visibles son del cliente 42
SELECT
    count(*)                                     AS total_filas,
    count(*) FILTER (WHERE cliente_id = 42)      AS filas_cliente_42,
    count(*) FILTER (WHERE cliente_id != 42)     AS filas_otros_clientes
FROM raw.pedidos;

COMMIT;

RESET ROLE;

-- ── 3.6 Comparar: dba_ana ve todo ────────────────────────────
\echo ''
\echo '▸ 3.6 Como DBA (role_dba) se ven TODOS los pedidos:'

SET ROLE dba_ana;
SELECT count(*) AS total_pedidos_visibles_para_dba FROM raw.pedidos;
RESET ROLE;

-- ── 3.7 Probar RLS para agentes por región ────────────────────
\echo ''
\echo '▸ 3.7 Prueba de RLS por región para agente_norte:'

SET ROLE agente_norte;

SELECT
    metadatos_pago->>'region' AS region,
    count(*)                  AS pedidos,
    sum(importe)              AS importe_total
FROM raw.pedidos
GROUP BY 1;

\echo '    (agente_norte solo debe ver Norte y Este, sin Cancelados)'

RESET ROLE;

\echo ''
\echo '▸ 3.7b Para agente_sur:'

SET ROLE agente_sur;
SELECT
    metadatos_pago->>'region' AS region,
    count(*) AS pedidos
FROM raw.pedidos
GROUP BY 1;
RESET ROLE;

-- ── 3.8 Ver todas las políticas activas ──────────────────────
\echo ''
\echo '▸ 3.8 Resumen de todas las políticas RLS en raw.pedidos:'
SELECT
    policyname,
    permissive,
    roles::TEXT,
    cmd,
    left(qual::TEXT, 60) AS condicion_using
FROM pg_policies
WHERE tablename = 'pedidos'
ORDER BY permissive DESC, policyname;

\echo ''
\echo '✓ Práctica 3 completada'
\echo '═══════════════════════════════════════════════════════'
