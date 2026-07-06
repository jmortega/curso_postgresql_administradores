# Guía — Superset + Metabase + PostgreSQL con Docker Compose

---

## Estructura de ficheros

```
proyecto/
├── docker-compose.yml
├── Dockerfile.superset
├── superset_config.py
├── init-db.sql
└── .env
```

---

## Arquitectura del stack

```
┌─────────────────────────────────────────────────────┐
│                   Red Docker interna                 │
│                                                      │
│  ┌──────────────┐      ┌──────────────────────────┐ │
│  │   Superset   │      │         Metabase         │ │
│  │  :8088       │      │         :3000            │ │
│  └──────┬───────┘      └────────────┬─────────────┘ │
│         │                           │               │
│         ▼                           ▼               │
│  ┌──────────────────────────────────────────────┐   │
│  │          PostgreSQL (db)  :5432 interno       │   │
│  │          BD: analytics    (datos negocio)     │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │    Redis     │  │   PostgreSQL (metabase-db)   │ │
│  │  caché/colas │  │   BD: metabase (metastore)   │ │
│  └──────────────┘  └──────────────────────────────┘ │
└─────────────────────────────────────────────────────┘

Acceso desde el host:
  localhost:8088  → Superset
  localhost:3000  → Metabase
  localhost:5433  → PostgreSQL (psql, DBeaver, etc.)
```

| Servicio | Puerto host | Puerto interno | Descripción |
|---|---|---|---|
| Superset | 8088 | 8088 | BI / visualización |
| Metabase | 3000 | 3000 | BI / exploración |
| PostgreSQL (datos) | 5433 | 5432 | BD compartida |
| PostgreSQL (metabase) | — | 5432 | Metastore interno de Metabase |
| Redis | — | 6379 | Caché y colas de Superset |

---

## 1. Puesta en marcha

### 1.1 Generar la SECRET_KEY y arrancar

```bash
# Generar clave segura y guardarla en .env
echo "SUPERSET_SECRET_KEY=$(openssl rand -base64 42)" > .env

# Construir la imagen de Superset (instala psycopg2 en el venv)
docker compose build --no-cache

# Levantar todos los servicios
docker compose up -d

# Seguir los logs
docker compose logs -f
```

### 1.2 Inicializar Superset (solo la primera vez)

```bash
# 1. Crear el schema de la base de datos de Superset
docker compose exec superset superset db upgrade

# 2. Crear el usuario administrador
docker compose exec superset superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@ejemplo.com \
  --password admin123

# 3. Cargar roles y permisos por defecto
docker compose exec superset superset init
```

### 1.3 Verificar que todo está healthy

```bash
docker compose ps
# Todos los servicios deben mostrar "healthy" o "running"
```

---

## 2. Conexión desde línea de comandos (psql)

### Desde el host (puerto mapeado 5433)

```bash
psql postgresql://analytics:analytics_pass@localhost:5433/analytics
analytics=# \dt
                   List of relations
 Schema |            Name             | Type  |   Owner   
--------+-----------------------------+-------+-----------
 public | ab_group                    | table | analytics
 public | ab_group_role               | table | analytics
 public | ab_permission               | table | analytics
 public | ab_permission_view          | table | analytics
 public | ab_permission_view_role     | table | analytics
 public | ab_register_user            | table | analytics
 public | ab_role                     | table | analytics
 public | ab_user                     | table | analytics
 public | ab_user_group               | table | analytics
 public | ab_user_role                | table | analytics
 public | ab_view_menu                | table | analytics
 public | alembic_version             | table | analytics
 public | annotation                  | table | analytics
 public | annotation_layer            | table | analytics
 public | cache_keys                  | table | analytics
 public | clientes                    | table | analytics
 public | css_templates               | table | analytics
 public | dashboard_roles             | table | analytics
 public | dashboard_slices            | table | analytics
 public | dashboard_user              | table | analytics
```

### Consultas de ejemplo una vez conectado

```sql
-- Ver las tablas disponibles
\dt

-- Consultar datos de ventas
SELECT categoria, SUM(cantidad * precio) AS total
FROM ventas
GROUP BY categoria
ORDER BY total DESC;

-- Ver clientes por ciudad
SELECT ciudad, COUNT(*) AS total_clientes
FROM clientes
GROUP BY ciudad
ORDER BY total_clientes DESC;

-- Salir
\q
```

---

## 3. Crear usuarios en Superset

### 3.1 Desde la CLI (recomendado para el primer admin)

```bash
# Crear usuario admin
docker compose exec superset superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@ejemplo.com \
  --password admin123

# Crear usuario de solo lectura
docker compose exec superset superset fab create-user \
  --role Gamma \
  --username analista \
  --firstname Ana \
  --lastname García \
  --email ana@ejemplo.com \
  --password analista123
```

Roles disponibles en Superset:

| Rol | Permisos |
|---|---|
| `Admin` | Acceso total, gestión de usuarios y configuración |
| `Alpha` | Puede crear y editar sus propios charts y dashboards |
| `Gamma` | Solo puede ver dashboards y charts que se le compartan |
| `sql_lab` | Acceso al SQL Lab para ejecutar consultas |
| `Public` | Acceso mínimo sin autenticación (deshabilitado por defecto) |

### 3.2 Desde la interfaz web de Superset

1. Acceder a `http://localhost:8088` e iniciar sesión como `admin`.
    user:admin
    password:admin123
2. Ir a **Settings** (icono ⚙️ arriba a la derecha) → **List Users**.
3. Pulsar el botón **+** (esquina superior derecha).
4. Rellenar el formulario:
   - **First Name / Last Name**: nombre del usuario
   - **Username**: nombre de login
   - **Email**: correo electrónico
   - **Active**: activado
   - **Role**: seleccionar uno o varios roles
   - **Password / Confirm Password**: contraseña
5. Pulsar **Save**.

---

## 4. Conectar Superset a PostgreSQL

### 4.1 Desde la CLI (automatizado)

```bash
docker compose exec superset superset set-database-uri \
  --database-name "Analytics PostgreSQL" \
  --uri "postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics"
```

### 4.2 Desde la interfaz web de Superset

1. Acceder a `http://localhost:8088`.
2. Ir a **Settings** → **Database Connections**.
3. Pulsar **+ Database** (botón azul arriba a la derecha).
4. En el selector de base de datos elegir **PostgreSQL**.
5. Rellenar la cadena de conexión:

```
postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics
```

> ⚠️ Usar `db:5432` (nombre de servicio Docker)
Database name:analytics
Username:analytics
Password:analytics_pass

6. Pulsar **Test Connection** — debe aparecer "Connection looks good!".
7. Pulsar **Connect**.

### 4.3 Crear un dataset (tabla) en Superset

1. Ir a **Data** → **Datasets** → **+ Dataset**.
2. Seleccionar:
   - **Database**: Analytics PostgreSQL
   - **Schema**: public
   - **Table**: ventas (o clientes)
3. Pulsar **Add**.

### 4.4 Crear un chart de ejemplo

1. Ir a **Charts** → **+ Chart**.
2. Seleccionar el dataset `ventas`.
3. Elegir tipo de chart: **Bar Chart**.
4. Configurar:
   - **X Axis**: `categoria`
   - **Metric**: `SUM(precio * cantidad)`
5. Pulsar **Update Chart** → **Save**.

---

## 5. Conectar Metabase a PostgreSQL

### 5.1 Configuración inicial (primera vez)

1. Acceder a `http://localhost:3000`.
2. Metabase muestra un asistente de configuración inicial:
   - Seleccionar idioma y pulsar **Next**.
   - Rellenar nombre, email y contraseña del admin.
   - Pulsar **Next**.

### 5.2 Añadir la base de datos PostgreSQL

En el asistente de configuración inicial (o posteriormente desde **Admin → Databases**):

| Campo | Valor |
|---|---|
| **Database type** | PostgreSQL |
| **Display name** | Analytics PostgreSQL |
| **Host** | `db` |
| **Port** | `5432` |
| **Database name** | `analytics` |
| **Username** | `analytics` |
| **Password** | `analytics_pass` |

> ⚠️ Igual que en Superset: usar `db:5432`, no `localhost:5433`.

Pulsar **Save** → Metabase ejecutará una sincronización automática del schema.

### 5.3 Crear usuarios adicionales en Metabase

1. Ir a **Admin** (icono ⚙️) → **People** → **Invite someone**.
2. Rellenar nombre y email.
3. Seleccionar grupo:
   - **Administrators**: acceso total
   - **All Users**: acceso estándar
4. Pulsar **Send invite** (o **Create** si el email no está configurado).

### 5.4 Hacer una pregunta (query) en Metabase

**Modo visual (sin SQL):**
1. Pulsar **+ New** → **Question**.
2. Seleccionar **Analytics PostgreSQL** → tabla `ventas`.
3. Usar los filtros y agrupaciones visuales.
4. Pulsar **Visualize**.

**Modo SQL:**
1. Pulsar **+ New** → **SQL query**.
2. Seleccionar **Analytics PostgreSQL**.
3. Escribir la consulta:

```sql
SELECT
    categoria,
    SUM(cantidad * precio) AS total_ventas,
    COUNT(*)               AS num_pedidos
FROM ventas
GROUP BY categoria
ORDER BY total_ventas DESC;
```

4. Pulsar **Run query** (Ctrl+Enter / Cmd+Enter).

---

## 6. Operaciones habituales

### Parar y arrancar el stack

```bash
# Parar sin borrar datos
docker compose stop

# Arrancar de nuevo
docker compose start

# Parar y eliminar contenedores (los volúmenes persisten)
docker compose down

# Eliminar todo incluidos los volúmenes (¡borra los datos!)
docker compose down -v
```

### Ver logs de un servicio concreto

```bash
docker compose logs -f superset
docker compose logs -f metabase
docker compose logs -f db
```

### Hacer backup de la base de datos

```bash
docker compose exec db pg_dump \
  -U analytics analytics > backup_$(date +%Y%m%d).sql
```

### Restaurar backup

```bash
cat backup_20250101.sql | docker compose exec -T db \
  psql -U analytics analytics
```

---

## 7. Resumen de accesos

| Servicio | URL | Usuario | Contraseña |
|---|---|---|---|
| Superset | http://localhost:8088 | admin | admin123 |
| Metabase | http://localhost:3000 | (configurado en setup) | (configurado en setup) |
| PostgreSQL (host) | localhost:5433 | analytics | analytics_pass |
| PostgreSQL (Docker) | db:5432 | analytics | analytics_pass |
