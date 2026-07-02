-- ============================================================================
-- SCRIPT DE MANTENIMIENTO: TABLA DE LOGS
-- Descripción: Automatiza el purgado, optimización y estadísticas de la tabla.
-- ============================================================================

-- Configuración del nombre de la tabla
\set TABLA_LOGS 'application_logs'

BEGIN;

SELECT clock_timestamp() AS inicio_mantenimiento;

-- ----------------------------------------------------------------------------
-- OPERACIÓN 1: Purgado de Datos Antiguos (Retención de 30 días)
-- ----------------------------------------------------------------------------
-- Eliminamos logs que tengan más de 30 días basados en la columna 'timestamp'.

DO $$
DECLARE
    filas_eliminadas INT;
BEGIN
    RAISE NOTICE 'Iniciando purgado de registros antiguos...';
    
    DELETE FROM application_logs 
    WHERE timestamp < NOW() - INTERVAL '2 days';
    
    GET DIAGNOSTICS filas_eliminadas = ROW_COUNT;
    RAISE NOTICE 'Purgado completado. Registros eliminados: %', filas_eliminadas;
END $$;

COMMIT;

-- ----------------------------------------------------------------------------
-- OPERACIÓN 2: Limpieza de Espacio Muerto (VACUUM)
-- ----------------------------------------------------------------------------
-- Nota: VACUUM no puede ejecutarse dentro de un bloque de transacción.

\echo 'Ejecutando VACUUM para recuperar espacio en disco...'
VACUUM :TABLA_LOGS;


-- ----------------------------------------------------------------------------
-- OPERACIÓN 3: Reindexación (REINDEX)
-- ----------------------------------------------------------------------------

\echo 'Reconstruyendo índices fragmentados...'
REINDEX TABLE :TABLA_LOGS;


-- ----------------------------------------------------------------------------
-- OPERACIÓN 4: Actualización de Estadísticas (ANALYZE)
-- ----------------------------------------------------------------------------

\echo 'Actualizando estadísticas del optimizador...'
ANALYZE :TABLA_LOGS;


-- ----------------------------------------------------------------------------
-- Resumen Final
-- ----------------------------------------------------------------------------
SELECT clock_timestamp() AS fin_mantenimiento;
\echo '¡Mantenimiento de la tabla de logs finalizado con éxito!'
