#!/bin/bash
# Script de automatización de copias controlado por Bash

# Configuración de variables
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="postgres"
DB_NAME="app_logs_db"

# Asegurar que el script use la contraseña sin pedirla interactivamente 
export PGPASSWORD="postgres_lab"
BACKUP_PATH="/home/linux/Descargas/sesion2/logs_$(date +%F).csv"

echo "Iniciando extracción automatizada de logs de INFO..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
\nopaging
\set ON_ERROR_STOP on

-- Pasar los logs de las últimas 24 horas a un CSV local
\copy (SELECT timestamp, http_method, message FROM application_logs WHERE log_level = 'INFO') TO '$BACKUP_PATH' WITH CSV HEADER;

EOF

if [ $? -eq 0 ]; then
    echo "¡Automatización exitosa! Archivo generado en $BACKUP_PATH"
else
    echo "Fallo crítico en la extracción del pool de datos"
    exit 1
fi

