-- =============================================================
-- practica_06_pgaudit.sql
-- Práctica 6: Auditoría con pgAudit
--
-- Ejecutar con:
--   docker exec -it pg-security psql -U postgres -d dwh \
--     -f /scripts/practica_06_pgaudit.sql
-- =============================================================

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  PRÁCTICA 6: Auditoría con pgAudit'
\echo '═══════════════════════════════════════════════════════'

-- ── 6.1 Verificar que pgAudit está instalado y configurado ────
\echo ''
\echo '▸ 6.1 Estado de pgAudit:'
SELECT extname, extversion FROM pg_extension WHERE extname = 'pgaudit';

SELECT name, setting
FROM pg_settings
WHERE name LIKE 'pgaudit%'
ORDER BY name;

-- ── 6.2 Configuración de auditoría por rol ───────────────────
\echo ''
\echo '▸ 6.2 Auditoría configurada por rol:'
SELECT
    rolname,
    array_to_string(
        ARRAY(
            SELECT elem FROM unnest(rolconfig) elem
            WHERE elem LIKE '%pgaudit%'
        ), ' | '
    ) AS audit_config
FROM pg_roles
WHERE rolconfig IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM unnest(rolconfig) elem WHERE elem LIKE '%pgaudit%'
  )
ORDER BY rolname;

-- ── 6.3 Generar eventos de auditoría ─────────────────────────
\echo ''
\echo '▸ 6.3 Generando operaciones auditadas...'
\echo '    (verificar en los logs: docker logs pg-security 2>&1 | grep AUDIT)'

-- DDL auditado
CREATE TABLE IF NOT EXISTS raw.tabla_auditada (
    id SERIAL PRIMARY KEY,
    dato TEXT
);

-- Escritura auditada
INSERT INTO raw.tabla_auditada (dato) VALUES ('dato de prueba 1'), ('dato de prueba 2');
UPDATE raw.tabla_auditada SET dato = 'modificado' WHERE id = 1;
DELETE FROM raw.tabla_auditada WHERE id = 2;

-- GRANT/REVOKE auditado (clase 'role')
GRANT SELECT ON raw.tabla_auditada TO reporting_svc;
REVOKE SELECT ON raw.tabla_auditada FROM reporting_svc;

DROP TABLE IF EXISTS raw.tabla_auditada;

\echo '    Operaciones generadas. Ver con:'
\echo '    docker logs pg-security 2>&1 | grep "AUDIT:" | tail -20'

-- ── 6.4 Auditoría como rol específico (dba_ana audita todo) ──
\echo ''
\echo '▸ 6.4 Simulando operaciones como dba_ana (audita ALL):'

SET ROLE dba_ana;

-- Esta SELECT será auditada porque dba_ana tiene pgaudit.log='all'
SELECT count(*) AS total_pedidos_dba FROM raw.pedidos;

-- Este DDL también será auditado
CREATE TABLE IF NOT EXISTS raw.temp_dba_test (id INT);
DROP TABLE IF EXISTS raw.temp_dba_test;

RESET ROLE;

\echo '    Ver entradas AUDIT para dba_ana en los logs:'
\echo '    docker logs pg-security 2>&1 | grep -i "user=dba_ana" | grep "AUDIT:"'


-- ── 6.6 Consultar la tabla de auditoría manual ────────────────
\echo ''
\echo '▸ 6.6 Últimas entradas en la tabla de auditoría:'
SELECT
    fecha,
    usuario,
    ip_cliente,
    operacion,
    objeto,
    query,
    rows_afectadas
FROM raw.auditoria_accesos
ORDER BY fecha DESC
LIMIT 10;

-- ── 6.7 Consultas de análisis de auditoría ───────────────────
\echo ''
\echo '▸ 6.7 Actividad por usuario (últimas 24h):'
SELECT
    usuario,
    operacion,
    count(*)           AS num_operaciones,
    max(fecha)         AS ultima_vez
FROM raw.auditoria_accesos
WHERE fecha > now() - INTERVAL '24 hours'
GROUP BY usuario, operacion
ORDER BY num_operaciones DESC;

\echo ''
\echo '▸ 6.7b Accesos por hora (distribución temporal):'
SELECT
    EXTRACT(hour FROM fecha)::INT AS hora,
    count(*)                      AS operaciones,
    string_agg(DISTINCT usuario, ', ') AS usuarios
FROM raw.auditoria_accesos
GROUP BY 1
ORDER BY 1;

-- ── 6.8 Detectar accesos fuera de horario laboral ────────────
\echo ''
\echo '▸ 6.8 Accesos fuera del horario laboral (08:00-20:00):'
SELECT
    fecha,
    usuario,
    operacion,
    objeto
FROM raw.auditoria_accesos
WHERE EXTRACT(hour FROM fecha AT TIME ZONE 'Europe/Madrid') NOT BETWEEN 8 AND 20
   OR EXTRACT(dow FROM fecha) IN (0, 6)
ORDER BY fecha DESC;

SELECT
    CASE WHEN count(*) = 0
         THEN '✓ Sin accesos fuera del horario laboral'
         ELSE count(*)::TEXT || ' acceso(s) fuera del horario laboral detectados'
    END AS resultado
FROM raw.auditoria_accesos
WHERE EXTRACT(hour FROM fecha AT TIME ZONE 'Europe/Madrid') NOT BETWEEN 8 AND 20
   OR EXTRACT(dow FROM fecha) IN (0, 6);

\echo ''
\echo '✓ Práctica 6 completada'
\echo '═══════════════════════════════════════════════════════'
