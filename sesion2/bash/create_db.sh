#!/bin/bash

# 1. Definir variables de entorno para PostgreSQL
export PGPASSWORD="postgres_lab"
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="postgres"
NEW_DB_NAME="app_prod_db"
DB_OWNER="usuario"

echo "Iniciando la creación de la base de datos: $NEW_DB_NAME..."

# 2. Ejecutar createdb asignando un dueño (owner) específico
createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -O "$DB_OWNER" -E UTF8 "$NEW_DB_NAME"

# 3. Verificar si el comando fue exitoso
if [ $? -eq 0 ]; then
    echo "¡Base de datos $NEW_DB_NAME creada con éxito y asignada a $DB_OWNER!"
else
    echo "Hubo un error al crear la base de datos."
fi

# 4. Limpiar la contraseña de la memoria por seguridad
unset PGPASSWORD
