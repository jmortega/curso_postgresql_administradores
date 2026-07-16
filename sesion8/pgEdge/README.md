# 🌍 pgEdge Cluster — PostgreSQL Distribuido Multirregión

> Clúster **activo-activo** de 3 nodos PostgreSQL distribuidos geográficamente,
> basado en [pgEdge](https://github.com/pgEdge) y su extensión
> [Spock](https://github.com/pgEdge/spock) de replicación lógica multi-master.
> Todo en local con Docker Compose.

---

## 📋 Índice

1. [¿Qué es pgEdge?](#1-qué-es-pgedge)
2. [Arquitectura del clúster](#2-arquitectura-del-clúster)
3. [Tecnologías clave](#3-tecnologías-clave)
4. [Requisitos](#4-requisitos)
5. [Inicio rápido](#5-inicio-rápido)
6. [Caso de uso: plataforma e-commerce multirregión](#6-caso-de-uso-plataforma-e-commerce-multirregión)
7. [Demostración activo-activo](#7-demostración-activo-activo)
8. [Verificación del clúster](#8-verificación-del-clúster)
9. [Resolución de conflictos Spock](#9-resolución-de-conflictos-spock)
10. [Operaciones del clúster](#10-operaciones-del-clúster)
11. [Estructura del proyecto](#11-estructura-del-proyecto)
12. [Referencias](#12-referencias)

---

## 1. ¿Qué es pgEdge?

**pgEdge** es una plataforma de PostgreSQL distribuido diseñada para despliegues
en la nube multirregión (*Edge Computing*). Su núcleo es 100% PostgreSQL estándar,
extendido con tres extensiones propias re-licenciadas a la PostgreSQL License en 2025:

| Extensión | Función |
|---|---|
| **Spock** | Replicación lógica multi-master (activo-activo) entre nodos |
| **Snowflake** | IDs únicos globales tipo `BIGINT` para escrituras distribuidas |
| **LOLOR** | Replicación de Large Objects entre nodos |

La propuesta de valor es permitir que **cualquier nodo acepte escrituras** y
que los cambios se propaguen a los demás nodos en tiempo real, sin punto único de
fallo ni nodo "primario" obligatorio.

```
        ┌──────────────┐
        │  Aplicación  │
        │  (cualquier  │
        │   región)    │
        └──────┬───────┘
               │ escribe en el nodo más cercano
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌───────┐  ┌───────┐  ┌───────┐
│  n1   │  │  n2   │  │  n3   │
│  EU   │◄─►  USA  │◄─►  ASIA │
│ :6432 │  │ :6433 │  │ :6434 │
└───────┘  └───────┘  └───────┘
     ▲___Spock multi-master___▲
         replicación lógica
         activo-activo
```

---

## 2. Arquitectura del clúster

```
pgedge-cluster/
│
├── docker-compose.yml         # 3 nodos pgEdge + job spock-wire
├── .env                       # Credenciales y configuración
│
└── scripts/
    ├── 01_schema.sql          # DDL del caso de uso e-commerce
    ├── 02_seed_and_demo.sql   # Datos de prueba + instrucciones demo
    └── 03_verify_cluster.sql  # Verificación completa del clúster
```

### Servicios Docker Compose

| Servicio | Imagen | Puerto host | Región simulada |
|---|---|---|---|
| `postgres-n1` | `ghcr.io/pgedge/pgedge-postgres:17-spock5-standard` | **6432** | `eu-west-1` (Europa) |
| `postgres-n2` | `ghcr.io/pgedge/pgedge-postgres:17-spock5-standard` | **6433** | `us-east-1` (EE.UU.) |
| `postgres-n3` | `ghcr.io/pgedge/pgedge-postgres:17-spock5-standard` | **6434** | `ap-southeast-1` (Asia) |
| `spock-wire`  | (misma imagen) | — | Job de inicialización |

### Flujo de inicialización

```
docker compose up
       │
       ├─ n1, n2, n3 arrancan en paralelo
       │     ├─ [10] shared_preload_libraries (spock, snowflake, lolor…)
       │     ├─ [20] parámetros WAL y Spock en postgresql.conf
       │     ├─ [30] restart PostgreSQL
       │     ├─ [40] CREATE EXTENSION (spock, snowflake, vector, postgis…)
       │     ├─ [50] pg_hba.conf permite conexiones entre nodos
       │     └─ [60] spock.node_create() — registra el nodo en Spock
       │
       └─ spock-wire (espera a que los 3 nodos sean healthy)
             └─ crea 6 suscripciones Spock en malla completa:
                  n1→n2, n1→n3
                  n2→n1, n2→n3
                  n3→n1, n3→n2
```

---

## 3. Tecnologías clave

### Spock — replicación lógica multi-master

Spock implementa replicación lógica basada en WAL con suscripciones bidireccionales.
A diferencia de la replicación streaming nativa de PostgreSQL (que solo admite un
primario), Spock permite que **todos los nodos acepten escrituras simultáneamente**.

**Replication sets:** conjunto de tablas replicadas. El set `default` replica
INSERT, UPDATE y DELETE. El set `ddl_sql` replica las sentencias DDL cuando
`spock.enable_ddl_replication = on`.

```sql
-- Ver nodos registrados
SELECT node_name FROM spock.node;

-- Ver suscripciones activas
SELECT sub_name, sub_enabled FROM spock.subscription;

-- Ver tablas replicadas
SELECT set_name, relid::regclass FROM spock.tables;
```

### Snowflake — IDs únicos globalmente distribuidos

En un clúster activo-activo, usar `SERIAL` o `BIGSERIAL` provocaría colisiones de
IDs entre nodos. La extensión Snowflake de pgEdge genera IDs de 64 bits únicos
globalmente basados en timestamp + node_id:

```sql
-- En lugar de BIGSERIAL:
id BIGINT PRIMARY KEY DEFAULT snowflake.nextval()

-- Cada nodo genera IDs distintos aunque inserten al mismo tiempo
-- n1 (node_id=1): 1234567890001
-- n2 (node_id=2): 1234567890002
-- n3 (node_id=3): 1234567890003
```

### DDL Replication

Con `spock.enable_ddl_replication = on`, los `CREATE TABLE`, `ALTER TABLE`, etc.
se replican automáticamente a todos los nodos. Solo es necesario ejecutar el DDL
en **un único nodo** y Spock lo propaga.

---

## 4. Requisitos

| Herramienta | Versión mínima |
|---|---|
| Docker Engine | 24+ |
| Docker Compose | v2 (`docker compose`) |
| RAM disponible | 4 GB (mínimo para 3 nodos) |
| Acceso a internet | Para descargar `ghcr.io/pgedge/pgedge-postgres:17-spock5-standard` |

> **Nota:** La imagen `ghcr.io/pgedge/pgedge-postgres:17-spock5-standard` pesa
> aproximadamente 1.5 GB. La primera descarga puede tardar varios minutos.

---

## 5. Inicio rápido


### Paso 1 — (Opcional) Personalizar credenciales

Edita `.env` antes de arrancar:

```bash
# .env
ADMIN_PASSWORD=MiPasswordSeguro2026
REPL_PASSWORD=MiPasswordRepl2026
POSTGRES_DB=mi_base_de_datos
```

### Paso 2 — Levantar el clúster

```bash
docker compose up -d
```

Sigue los logs del job de inicialización:

```bash
docker logs spock-wire --follow
```

**Salida esperada cuando el clúster está listo:**

```
[wire] Esperando que todos los nodos tengan su nodo Spock registrado…
[wire] ✓ Nodo 'n1' listo
[wire] ✓ Nodo 'n2' listo
[wire] ✓ Nodo 'n3' listo
[wire] Creando suscripciones en malla completa (idempotente)…
[wire]   n1 → n2  (sub_n1_n2)
[wire]   n1 → n3  (sub_n1_n3)
[wire]   n2 → n1  (sub_n2_n1)
[wire]   n2 → n3  (sub_n2_n3)
[wire]   n3 → n1  (sub_n3_n1)
[wire]   n3 → n2  (sub_n3_n2)

[wire] ════════════════════════════════════════
[wire]  Clúster pgEdge 3 nodos listo y cableado
[wire]  n1 (EU)   → localhost:6432
[wire]  n2 (USA)  → localhost:6433
[wire]  n3 (ASIA) → localhost:6434
[wire] ════════════════════════════════════════

```

> El proceso completo tarda entre **2 y 5 minutos** la primera vez
> (descarga de imagen + inicialización de los 3 nodos).

### Paso 4 — Verificar conectividad

```bash
# Conectar a n1 (EU)
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \
  -c "SELECT node_name FROM spock.node ORDER BY node_name;"

#  node_name
# -----------
#  n1
#  n2
#  n3
# (3 rows)

# Conectar a n2 (USA)
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db \
  -c "SELECT node_name FROM spock.node ORDER BY node_name;"

#  node_name
# -----------
#  n1
#  n2
#  n3
# (3 rows)

# Conectar a n3 (ASIA)
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6434 -U admin ecommerce_db \
  -c "SELECT node_name FROM spock.node ORDER BY node_name;"

#  node_name
# -----------
#  n1
#  n2
#  n3
# (3 rows)

```

---

## 6. Caso de uso: plataforma e-commerce multirregión

### Problema

Una plataforma de e-commerce con usuarios en Europa, América y Asia necesita:

- **Baja latencia de lectura y escritura** para usuarios en cada región
- **Sin punto único de fallo**: si cae un nodo, los otros siguen operando
- **Consistencia eventual**: los pedidos creados en cualquier región aparecen
  en todos los nodos en segundos
- **IDs únicos globalmente** cuando múltiples nodos insertan simultáneamente

### Solución con pgEdge

```
Usuario EU      Usuario USA      Usuario ASIA
    │                │                │
    ▼                ▼                ▼
  n1:6432          n2:6433          n3:6434
(eu-west-1)     (us-east-1)   (ap-southeast-1)
    │                │                │
    └────────────────┼────────────────┘
           Spock replicación activo-activo
           (todos los nodos ven todos los datos)
```

### Crear el esquema

```bash
PGPASSWORD=Admin_Lab_2026 psql \
  -h localhost -p 6432 -U admin ecommerce_db \
  -f scripts/01_schema.sql

$ psql -h localhost -p 6432 -U admin ecommerce_db   -c "\dt"
Password for user admin: 
             List of relations
 Schema |       Name       | Type  | Owner 
--------+------------------+-------+-------
 public | categories       | table | admin
 public | customers        | table | admin
 public | order_items      | table | admin
 public | orders           | table | admin
 public | products         | table | admin
 public | regions          | table | admin
 public | replication_test | table | admin
 public | spatial_ref_sys  | table | admin
(8 rows)

```

**Tablas creadas** (se replican automáticamente a n2 y n3):

```
ecommerce_db
├── regions          — catálogo de regiones geográficas
├── categories       — categorías de productos
├── customers        — clientes (con región de origen)
├── products         — catálogo de productos
├── orders           — pedidos (con origin_node para trazabilidad)
├── order_items      — líneas de pedido
└── replication_test — tabla de verificación de replicación
```

### Verificar que el DDL llegó a n2 y n3

```bash
# 15 segundos después del CREATE TABLE en n1:
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db \
  -c "\dt"

# Resultado esperado: las mismas 7 tablas que en n1

             List of relations
 Schema |       Name       | Type  | Owner 
--------+------------------+-------+-------
 public | categories       | table | admin
 public | customers        | table | admin
 public | order_items      | table | admin
 public | orders           | table | admin
 public | products         | table | admin
 public | regions          | table | admin
 public | replication_test | table | admin
 public | spatial_ref_sys  | table | admin

```

```bash
# 15 segundos después del CREATE TABLE en n1:
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6434 -U admin ecommerce_db \
  -c "\dt"

# Resultado esperado: las mismas 7 tablas que en n1

             List of relations
 Schema |       Name       | Type  | Owner 
--------+------------------+-------+-------
 public | categories       | table | admin
 public | customers        | table | admin
 public | order_items      | table | admin
 public | orders           | table | admin
 public | products         | table | admin
 public | regions          | table | admin
 public | replication_test | table | admin
 public | spatial_ref_sys  | table | admin


```

### Insertar datos de prueba en n1

```bash
PGPASSWORD=Admin_Lab_2026 psql \
  -h localhost -p 6432 -U admin ecommerce_db \
  -f scripts/02_seed_and_demo.sql

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \
  -c "SELECT * FROM customers;"


$ psql -h localhost -p 6432 -U admin ecommerce_db \
  -c "SELECT * FROM customers;"
Password for user admin: 
                  id                  |         email         |     name     | region_id |          created_at           
--------------------------------------+-----------------------+--------------+-----------+-------------------------------
 57a4d09e-2cb9-477f-8af0-77510770031d | alice@eu.example.com  | Alice Müller |         1 | 2026-07-15 21:11:08.862324+00
 71e2336a-1bfa-481a-b74c-c2bb617cc38b | bob@us.example.com    | Bob Johnson  |         2 | 2026-07-15 21:11:08.864846+00
 a0991755-357a-4a19-a284-f064217eed84 | diana@asia.example.sg | Diana Tan    |         3 | 2026-07-15 21:11:08.867819+00
(3 rows)

(venv) linux@linux-EVO14-A8:~/Descargas/sesion8/pgEdge$ psql -h localhost -p 6433 -U admin ecommerce_db   -c "SELECT * FROM customers;"
Password for user admin: 
                  id                  |         email         |     name     | region_id |          created_at           
--------------------------------------+-----------------------+--------------+-----------+-------------------------------
 57a4d09e-2cb9-477f-8af0-77510770031d | alice@eu.example.com  | Alice Müller |         1 | 2026-07-15 21:11:08.862324+00
 71e2336a-1bfa-481a-b74c-c2bb617cc38b | bob@us.example.com    | Bob Johnson  |         2 | 2026-07-15 21:11:08.864846+00
 a0991755-357a-4a19-a284-f064217eed84 | diana@asia.example.sg | Diana Tan    |         3 | 2026-07-15 21:11:08.867819+00
(3 rows)

(venv) linux@linux-EVO14-A8:~/Descargas/sesion8/pgEdge$ psql -h localhost -p 6434 -U admin ecommerce_db   -c "SELECT * FROM customers;"
Password for user admin: 
                  id                  |         email         |     name     | region_id |          created_at           
--------------------------------------+-----------------------+--------------+-----------+-------------------------------
 57a4d09e-2cb9-477f-8af0-77510770031d | alice@eu.example.com  | Alice Müller |         1 | 2026-07-15 21:11:08.862324+00
 71e2336a-1bfa-481a-b74c-c2bb617cc38b | bob@us.example.com    | Bob Johnson  |         2 | 2026-07-15 21:11:08.864846+00
 a0991755-357a-4a19-a284-f064217eed84 | diana@asia.example.sg | Diana Tan    |         3 | 2026-07-15 21:11:08.867819+00
(3 rows)

```

---

## 7. Demostración activo-activo

Abre **tres terminales** y escribe simultáneamente en los tres nodos:

**Terminal 1 — Escritura en n1 (EU)**:
```bash
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db -c "
  INSERT INTO replication_test (node_name, region, msg)
  VALUES ('n1', 'eu-west-1', 'Pedido creado en Europa — ' || now());"
```

**Terminal 2 — Escritura en n2 (USA)**:
```bash
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db -c "
  INSERT INTO replication_test (node_name, region, msg)
  VALUES ('n2', 'us-east-1', 'Pedido creado en EE.UU. — ' || now());"
```

**Terminal 3 — Escritura en n3 (ASIA)**:
```bash
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6434 -U admin ecommerce_db -c "
  INSERT INTO replication_test (node_name, region, msg)
  VALUES ('n3', 'ap-southeast-1', 'Pedido creado en Asia — ' || now());"
```

**Espera 5 segundos y verifica en cualquier nodo** (deben aparecer las 3 filas):

```bash
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db -c "
  SELECT node_name, region, msg, ts
  FROM replication_test
  ORDER BY ts DESC;"
```

```
 node_name |     region      |           msg                         | ts
-----------+-----------------+---------------------------------------+--------
 n3        | ap-southeast-1  | Pedido creado en Asia — 2025-06-15... | ...
 n2        | us-east-1       | Pedido creado en EE.UU. — 2025-06-15  | ...
 n1        | eu-west-1       | Pedido creado en Europa — 2025-06-15  | ...
(3 rows)
```

> Las 3 filas aparecen en los 3 nodos: **replicación activo-activo confirmada**.

---

## 8. Verificación del clúster

Script de verificación completo (incluye nodos, suscripciones, slots WAL y conflictos):

```bash
PGPASSWORD=Admin_Lab_2026 psql \
  -h localhost -p 6432 -U admin ecommerce_db \
  -f scripts/03_verify_cluster.sql

PGPASSWORD=Admin_Lab_2026 psql \
  -h localhost -p 6433 -U admin ecommerce_db \
  -f scripts/03_verify_cluster.sql

PGPASSWORD=Admin_Lab_2026 psql \
  -h localhost -p 6434 -U admin ecommerce_db \
  -f scripts/03_verify_cluster.sql

```

### Consultas clave de verificación

```sql
-- Nodos registrados (debe haber 3)
SELECT node_name FROM spock.node ORDER BY node_name;

-- Suscripciones activas (debe haber 2 por nodo = 6 en total por clúster)
SELECT sub_name, sub_enabled FROM spock.subscription ORDER BY sub_name;

-- Lag de replicación por slot WAL
SELECT slot_name, active,
       pg_size_pretty(pg_wal_lsn_diff(
         pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag
FROM pg_replication_slots;

-- Conflictos detectados y cómo se resolvieron
SELECT node_name, relname, conflict_type, conflict_resolution, log_time
FROM spock.resolutions
ORDER BY log_time DESC LIMIT 10;
```

---

## 9. Resolución de conflictos Spock

En un clúster pueden producirse conflictos cuando dos nodos
actualizan la misma fila simultáneamente. Spock lo gestiona automáticamente.

La política configurada en este proyecto es `last_update_wins`:
el nodo con el timestamp de commit más reciente gana.

```ini
# En postgresql.conf de cada nodo:
spock.conflict_resolution = last_update_wins
spock.save_resolutions = on          # guarda en spock.resolutions
spock.conflict_log_level = WARNING   # loguea conflictos

Para generar conflictos hay que actualizar la misma fila desde dos nodos antes de que la replicación la propague.
El truco es pausar la replicación en un nodo, hacer la escritura conflictiva, y luego reanudarla.

# Paso 1 — Preparar la fila de prueba (en n1):

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \
  -f scripts/04_simulate_conflicts.sql

# Paso 2 — Abre dos terminales y ejecuta en paralelo (lanza Terminal B unos segundos después de Terminal A):
# Terminal A — n1 pausa su suscripción y escribe
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \
  -f scripts/04b_conflict_n1.sql

# Terminal B — n2 escribe en la misma fila
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db \
  -f scripts/04c_conflict_n2.sql

Paso 3 — Verificar el conflicto (en n1 o n2):
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \
  -f scripts/04d_check_conflicts.sql

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db \
  -f scripts/04d_check_conflicts.sql

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db -c "
  SELECT * FROM spock.resolutions;"

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db -c "
  SELECT * FROM replication_test;"

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db -c "
  SELECT * FROM replication_test;"

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6434 -U admin ecommerce_db -c "
  SELECT * FROM replication_test;"

```


**Estrategias disponibles:**

| Política | Comportamiento |
|---|---|
| `last_update_wins` | Gana el commit con timestamp más reciente |
| `first_update_wins` | Gana el commit con timestamp más antiguo |
| `apply_remote` | Siempre aplica el cambio remoto |
| `keep_local` | Siempre mantiene el valor local |

**Buenas prácticas para minimizar conflictos:**

- Diseña el esquema con particionado geográfico cuando sea posible (ej.: cada región
  solo inserta en su propio rango de datos).
- Utiliza `ON CONFLICT DO NOTHING` o `ON CONFLICT DO UPDATE` en inserts concurrentes.

---

## 10. Operaciones del clúster

### Comandos habituales

```bash
# Levantar el clúster
docker compose up -d

# Ver estado de todos los contenedores
docker compose ps

# Seguir logs de inicialización
docker logs spock-wire --follow

# Logs de un nodo específico
docker logs postgres-n1 --follow --tail 50

# Acceso psql directo a cada nodo
docker exec -it postgres-n1 psql -U admin ecommerce_db
docker exec -it postgres-n2 psql -U admin ecommerce_db
docker exec -it postgres-n3 psql -U admin ecommerce_db

# Detener sin borrar datos
docker compose stop

# Destruir el clúster (incluye volúmenes)
docker compose down -v
```

### Cambiar la imagen de PostgreSQL

Para usar PG 16 o PG 18 en lugar de PG 17, edita `.env`:

```bash
# PG 16 con Spock 5
POSTGRES_IMAGE=ghcr.io/pgedge/pgedge-postgres:16-spock5-standard

# PG 18 con Spock 5
POSTGRES_IMAGE=ghcr.io/pgedge/pgedge-postgres:18-spock5-standard
```

### Añadir una tabla al replication set manualmente

Si no usas DDL replication automática, puedes añadir tablas manualmente:

```sql
-- En cada nodo donde quieras que se replique la tabla:
SELECT spock.repset_add_all_tables('default', ARRAY['public']);

-- O tabla a tabla:
SELECT spock.repset_add_table(
  set_name := 'default',
  relation := 'public.mi_tabla',
  synchronize_data := true
);
```

### Forzar resincronización de datos

```sql
-- En el nodo destino, resincronizar una tabla desde el provider:
SELECT spock.sub_resync_table(
  subscription_name := 'sub_n2_n1',
  relation := 'public.orders'
);
```

### Simular fallo de nodo y recuperación

```bash
# Detener n2 (simular fallo de región USA)
docker stop postgres-n2

# n1 y n3 siguen operando, sus WAL slots acumulan cambios para n2
# Verifica que n1 sigue aceptando escrituras:
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6432 -U admin ecommerce_db \
  -c "INSERT INTO replication_test (node_name, region, msg)
      VALUES ('n1', 'eu-west-1', 'Escritura durante fallo de n2');"

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db   -c "INSERT INTO replication_test (node_name, region, msg)
      VALUES ('n1', 'eu-west-1', 'Escritura durante fallo de n2');"
psql: error: falló la conexión al servidor en «localhost» (127.0.0.1), puerto 6433: Conexión rehusada
	¿Está el servidor en ejecución en ese host y aceptando conexiones TCP/IP?

PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6434 -U admin ecommerce_db   -c "INSERT INTO replication_test (node_name, region, msg)
      VALUES ('n1', 'eu-west-1', 'Escritura durante fallo de n2');"

# Recuperar n2
docker start postgres-n2

# n2 se recupera automáticamente desde los slots WAL
# Esperar 30s y verificar que tiene los datos que se escribieron durante el fallo:
PGPASSWORD=Admin_Lab_2026 psql -h localhost -p 6433 -U admin ecommerce_db \
  -c "SELECT * FROM replication_test ORDER BY ts DESC LIMIT 5;"
```

---

## 11. Estructura del proyecto

```
pgedge-cluster/
│
├── docker-compose.yml            # Stack completo (3 nodos + spock-wire)
│                                 # Incluye configs inline para los scripts
│                                 # de inicialización de cada nodo
│
├── .env                          # Credenciales y configuración
│
└── scripts/                      # SQL para el caso de uso e-commerce
    ├── 01_schema.sql             # Esquema con Snowflake IDs
    ├── 02_seed_and_demo.sql      # Datos de prueba + instrucciones demo
    └── 03_verify_cluster.sql     # Verificación completa del clúster
```

### Cómo funciona `docker compose configs`

Los scripts de inicialización de cada nodo están embebidos directamente en
`docker-compose.yml` bajo la sección `configs:`. Docker los inyecta como
ficheros en `/docker-entrypoint-initdb.d/` de cada contenedor, y la imagen
de pgEdge los ejecuta en orden numérico durante el primer arranque.

Esto elimina la necesidad de un Dockerfile separado: toda la configuración
está en un único fichero.

---

## 12. Referencias

- [pgEdge GitHub](https://github.com/pgEdge) — organización oficial
- [pgEdge postgres-images](https://github.com/pgEdge/postgres-images) — imágenes Docker actuales
- [Spock — replicación multi-master](https://github.com/pgEdge/spock)
- [Snowflake — IDs distribuidos](https://github.com/pgEdge/snowflake)
- [pgEdge Documentación](https://docs.pgedge.com)
- [pgEdge en Docker — Tutorial oficial](https://docs.pgedge.com/container/docker)
- [Spock: sub_create, node_create — Referencia API](https://github.com/pgEdge/spock#sql-api)

---

## 📋 Credenciales por defecto

| Recurso | Valor |
|---|---|
| Usuario admin | `admin` |
| Contraseña admin | `Admin_Lab_2025` |
| Usuario replicación | `pgedge` |
| Contraseña replicación | `Repl_Lab_2025` |
| Base de datos | `ecommerce_db` |
| n1 (EU) | `localhost:6432` |
| n2 (USA) | `localhost:6433` |
| n3 (ASIA) | `localhost:6434` |
