# 🐘 Sesión 2 — PostgreSQL Avanzado con Docker

> PostGIS · pgvector · pg_stat_statements · pg_wait_sampling
>
> Un único contenedor PostgreSQL 16 con todas las extensiones preinstaladas.
> Los scripts Python se ejecutan desde el host conectando a `localhost:5432`.

---

## 🗂️ Estructura del proyecto

```
pg-sesion2/
├── docker-compose.yml              # Servicio único: pg-sesion2
├── Dockerfile                      # PG16 + PostGIS + pgvector + pg_wait_sampling
│
├── configs/
│   ├── postgresql.conf             # shared_preload_libraries con todas las extensiones
│   └── pg_hba.conf
│
├── scripts/                        # Scripts Python (ejecutar desde el host)
│   ├── init_db.sql                 # Se ejecuta al arrancar: activa extensiones
│   ├── postgis_manager.py          # Gestión de datos geoespaciales
│   ├── pgvector_manager.py         # Almacenamiento y búsqueda de vectores
│   ├── pgmon_manager.py            # Monitorización con pg_stat_statements
│   └── postgres_logs_manager.py   # Gestión de logs de aplicación
│
├── postgis/
│   ├── postgis_guide.md            # Guía de PostGIS
│
├── pgvector/
│   └── pgvector_guide.md           # Guía de pgvector
│
└── pgmon/
    └── pgmon_guide.md              # Guía de pg_stat_statements y pg_wait_sampling
```

---

## ⚡ Inicio rápido

### 1 — Levantar el contenedor

```bash
docker compose up --build -d
docker compose logs -f    # esperar "database system is ready to accept connections"
```

## Creación de virtualenv

```bash
# Crear entorno virtual (recomendado)
python3 -m venv venv
source venv/bin/activate

```

### 2 — Instalar dependencias Python en el host

```bash
pip install -r requeriments.txt
```

### 3 — Ejecutar los scripts

```bash
# Gestión de logs de aplicación
python scripts/postgres_logs_manager.py

# Búsqueda vectorial / embeddings
python scripts/pgvector_manager.py

# Datos geoespaciales
python scripts/postgis_manager.py

# Monitorización
python scripts/pgmon_manager.py

```

---

## 🔌 Configuración de conexión

Todos los scripts leen la conexión desde **variables de entorno** con
estos valores por defecto (que apuntan al contenedor):

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `PG_HOST` | `localhost` | Host de PostgreSQL |
| `PG_PORT` | `5432` | Puerto |
| `PG_USER` | `postgres` | Usuario |
| `PG_PASSWORD` | `postgres_lab` | Contraseña |
| `PG_DBNAME` | `postgres` | BD de conexión inicial |

Para sobrescribir sin tocar el código:

```bash
# Ejemplo: conectar a un servidor externo
export PG_HOST=mi-servidor.ejemplo.com
export PG_PASSWORD=mi_password_seguro
python scripts/pgmon_manager.py
```

---

## 🌐 Extensiones preinstaladas

| Extensión | Activada al arrancar | Para qué sirve |
|---|---|---|
| `pg_stat_statements` | ✅ Sí | Estadísticas de queries (pgmon_manager) |
| `pg_wait_sampling` | ✅ Sí | Eventos de espera (pgmon_manager) |
| `vector` (pgvector) | ✅ Sí | Búsqueda vectorial / embeddings |
| `postgis` | ✅ Sí | Datos geoespaciales |
| `postgis_topology` | ✅ Sí | Topología espacial |

---

## 🗄️ Bases de datos creadas por los scripts

Cada script crea su propia BD la primera vez que se ejecuta:

| Script | BD que crea |
|---|---|
| `postgres_logs_manager.py` | `app_logs_db` |
| `pgvector_manager.py` | `pgvector_db` |
| `postgis_manager.py` | `postgis_geo_db` |
| `pgmon_manager.py` | usa `postgres` directamente |

---

CREATE USER usuario WITH PASSWORD 'password';
GRANT CONNECT ON DATABASE app_logs_db TO usuario;
GRANT USAGE, CREATE ON SCHEMA public TO usuario;
\du

## 🛠️ Comandos útiles

```bash
# Levantar el contenedor
docker compose up -d

# Ver logs en tiempo real
docker compose logs -f

# Conectar con psql desde el host
psql -h localhost -p 5432 -U postgres
password:postgres_lab

# Verificar extensiones activas
psql -h localhost -p 5432 -U postgres -c "
    SELECT name, default_version, installed_version
    FROM pg_available_extensions
    WHERE installed_version IS NOT NULL
    ORDER BY name;"

# Acceder al contenedor (bash)
docker exec -it pg-sesion2 bash

# Detener y eliminar datos
docker compose down -v
```

---

## 📚 Guías

- **PostGIS** → `postgis/postgis_guide.md`
- **pgvector** → `pgvector/pgvector_guide.md`
- **pg_stat_statements + pg_wait_sampling** → `pgmon/pgmon_guide.md`
