#!/bin/bash

# Configuración de variables
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="postgres"
DB_NAME="app_logs_db"

# Asegurar que el script use la contraseña sin pedirla interactivamente 
export PGPASSWORD="postgres_lab"

echo "=================================================================="
echo "📊 MONITOREO DE CONEXIONES ACTIVAS EN EL CLÚSTER"
echo "=================================================================="

# 1. Obtener el número total de conexiones activas
CONEXIONES_ACTIVAS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT count(*) FROM pg_stat_activity;")

echo "▶ El clúster tiene actualmente $CONEXIONES_ACTIVAS backends abiertos."
echo ""

# 2. Mostrar el desglose de las conexiones si existen
if [ "$CONEXIONES_ACTIVAS" -gt 0 ]; then
    echo "📋 Detalle de las conexiones actuales:"
    
    # Ejecutamos psql sin el modo silencioso para aprovechar el formateo de tablas nativo
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT 
        pid AS \"PID\",
        usename AS \"Usuario\",
        datname AS \"Base de Datos\",
        client_addr AS \"IP Cliente\",
        state AS \"Estado\",
        substring(query from 1 for 40) AS \"Consulta Reciente\"
    FROM pg_stat_activity;
    "
else
    echo "No hay conexiones activas en este momento."
fi

# Limpieza de seguridad
unset PGPASSWORD
echo "=================================================================="

