# 🔄 PostgreSQL Migrations Lab

> Laboratorio práctico de migraciones de bases de datos:
> **PG14 → PG17** con `pg_dump`/`pg_restore` y estrategia zero-downtime,
> y **MySQL 8 → PostgreSQL 17** con `pgloader`.
> Todo en local con Docker Compose.

---

## 📋 Índice

1. [Arquitectura del laboratorio](#1-arquitectura-del-laboratorio)
2. [Inicio rápido](#2-inicio-rápido)
3. [Migración PG14 → PG17 con pg_dump/pg_restore](#3-migración-pg14--pg17-con-pg_dumppg_restore)
4. [Migración MySQL → PostgreSQL con pgloader](#4-migración-mysql--postgresql-con-pgloader)
5. [Estrategia zero-downtime](#5-estrategia-zero-downtime)
6. [Validación post-migración](#6-validación-post-migración)
7. [Rollback y contingencia](#7-rollback-y-contingencia)
8. [Referencia de comandos](#8-referencia-de-comandos)
9. [Estructura del proyecto](#9-estructura-del-proyecto)

---

## 1. Arquitectura del laboratorio

```
┌─────────────────────────────────────────────────────────┐
│  Tu máquina (host)                                      │
│                                                         │
│  pg14         pg17         mysql8       pgloader        │
│  PG 14.x  →  PG 17.x      MySQL 8.0  → (job puntual)  │
│  :5414        :5417        :3306                        │
│                                                         │
│  tienda_v1    tienda_v2    tienda_mysql  tienda_mysql_  │
│  (origen)     (destino)    (origen)      migrada        │
│                                                         │
│  dumps/  ←─────────────────────── volumen compartido   │
└─────────────────────────────────────────────────────────┘
```

| Servicio | Imagen | Puerto | BD | Rol |
|---|---|---|---|---|
| `pg14` | `postgres:14-bookworm` | **5414** | `tienda_v1` | Origen PG |
| `pg17` | `postgres:17-bookworm` | **5417** | `tienda_v2` | Destino PG |
| `mysql8` | `mysql:8.0` | **3306** | `tienda_mysql` | Origen MySQL |
| `pgloader` | `ghcr.io/dimitri/pgloader` | — | — | Job migración |

### Datos de prueba

Ambas BDs contienen un esquema e-commerce equivalente:

```
categorias → clientes → pedidos → lineas_pedido
                 ↑                      ↑
              productos ────────────────┘
```

Diferencias intencionales MySQL vs PG que pgloader debe resolver:

| MySQL | PostgreSQL | Mapeo pgloader |
|---|---|---|
| `TINYINT(1)` | `BOOLEAN` | `type tinyint when (= precision 1) to boolean` |
| `DATETIME` | `TIMESTAMPTZ` | `type datetime to timestamptz` |
| `DECIMAL(10,2)` | `NUMERIC(10,2)` | `type decimal to numeric` |
| `AUTO_INCREMENT` | `SERIAL` / secuencia | Automático |
| `ENGINE=InnoDB` | — | Ignorado |
| Sin ENUMs | `estado_pedido ENUM` | Constraint CHECK post-carga |
| Sin JSONB | `JSONB` | Columnas separadas → JSONB manual |

---

## 2. Inicio rápido

```bash
# 1. Levantar todos los servicios
docker compose up -d

# 2. Esperar a que todos estén saludables (~60 segundos)
docker compose ps

# 3. Verificar que PG14 tiene datos
PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 \
  -c "SELECT * FROM pedidos;"

# 4. Verificar que MySQL tiene datos
docker exec -it mysql8 mysql -uroot -proot_lab tienda_mysql \
  -e "SELECT * FROM pedidos;"
```

---

## 3. Migración PG14 → PG17 con pg_dump/pg_restore

### 3.1 Modo manual paso a paso

#### PASO 1 — Dump del esquema PG14

```bash
# Solo estructura (sin datos) → útil para revisar qué se va a migrar
PGPASSWORD=postgres_lab pg_dump \
  -h localhost -p 5414 -U postgres \
  --schema-only \
  --no-owner \
  --no-acl \
  --format=plain \
  tienda_v1 > dumps/schema_$(date +%Y%m%d).sql

# Ver el esquema generado
less dumps/schema_*.sql
```

#### PASO 2 — Restaurar esquema en PG17

```bash
PGPASSWORD=postgres_lab psql \
  -h localhost -p 5417 -U postgres \
  tienda_v2 < dumps/schema_*.sql
```

# Verificar que PG17 contiene las tablas como resultado de restaurar el esquema
```bash
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 -c "\dt"
               List of relations
 Schema |        Name        | Type  |  Owner
--------+--------------------+-------+----------
 public | _migracion_control | table | postgres
 public | categorias         | table | postgres
 public | clientes           | table | postgres
 public | lineas_pedido      | table | postgres
 public | pedidos            | table | postgres
 public | productos          | table | postgres
(6 rows)
```

#### PASO 3 — Dump de datos (formato custom, comprimido, paralelizable)

```bash
PGPASSWORD=postgres_lab pg_dump -h localhost -p 5414 -U postgres --data-only --format=custom --compress=6 tienda_v1 > dumps/data_$(date +%Y%m%d).dump

# Tamaño del dump
ls -lh dumps/data_*.dump
```

#### PASO 4 — Restaurar datos en PG17 (paralelo)

```bash
PGPASSWORD=postgres_lab pg_restore \
  -h localhost -p 5417 -U postgres --dbname=tienda_v2 --jobs=4 --no-owner --no-acl --disable-triggers dumps/data_*.dump
```

#### PASO 5 — Verificar secuencias en ambas instancias

```bash
# Las secuencias deben apuntar al valor máximo actual de cada tabla
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 \
  -c "SELECT setval('clientes_id_seq',  (SELECT max(id) FROM clientes));
      SELECT setval('productos_id_seq', (SELECT max(id) FROM productos));
      SELECT setval('pedidos_id_seq',   (SELECT max(id) FROM pedidos));"

PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 \
  -c "SELECT setval('clientes_id_seq',  (SELECT max(id) FROM clientes));
      SELECT setval('productos_id_seq', (SELECT max(id) FROM productos));
      SELECT setval('pedidos_id_seq',   (SELECT max(id) FROM pedidos));"
```

#### PASO 5 — Verificar datos

```bash

PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 \
  -c "SELECT * FROM clientes;
      SELECT * FROM productos;
      SELECT * FROM pedidos;"

PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 \
  -c "SELECT * FROM clientes;
      SELECT * FROM productos;
      SELECT * FROM pedidos;"

psql -h localhost -p 5417 -U postgres tienda_v2 -f scripts/validation/validate_pg_migration.sql
password:postgres_lab

```

### 3.2 Modo automático con el script orquestador

```bash
chmod +x ./scripts/migration/*.*
# Ver qué haría sin ejecutar nada (dry-run)
./scripts/migration/migrate_pg.sh --dry-run

# Ejecutar la migración completa
./scripts/migration/migrate_pg.sh
```

### 3.3 Dump en formato directory (más rápido)

Para tablas muy grandes, el formato `directory` permite `--jobs=N` tanto
en el dump como en el restore:

```bash
# Dump paralelo (4 workers)
PGPASSWORD=postgres_lab pg_dump \
  -h localhost -p 5414 -U postgres \
  --format=directory \
  --jobs=4 \
  --compress=6 \
  -f dumps/tienda_v1_dir/ \
  tienda_v1

# Restore paralelo (4 workers)
# añadir --clean para que elimine los objetos antes de recrearlos
PGPASSWORD=postgres_lab pg_restore \
  -h localhost -p 5417 -U postgres \
  --dbname=tienda_v2 \
  --format=directory \
  --jobs=4 \
  --no-owner \
  --clean --if-exists \
  dumps/tienda_v1_dir/
```

### 3.4 Migrar solo tablas específicas

```bash
# Solo la tabla pedidos y lineas_pedido
PGPASSWORD=postgres_lab pg_dump \
  -h localhost -p 5414 -U postgres \
  --table=pedidos \
  --table=lineas_pedido \
  --format=custom \
  tienda_v1 > dumps/pedidos_only.dump
```

---

## 4. Migración MySQL → PostgreSQL con pgloader

### 4.1 ¿Qué hace pgloader?

```
MySQL 8 ─────────────────────────────────────────► PostgreSQL 17
  │                                                      │
  │  1. Leer esquema MySQL (SHOW CREATE TABLE)           │
  │  2. Mapear tipos: TINYINT→BOOL, DATETIME→TIMESTAMPTZ │
  │  3. CREATE TABLE en PostgreSQL                        │
  │  4. Leer datos via protocol MySQL nativo             │
  │  5. Escribir con COPY (comando ultra-veloz de PG)    │
  │  6. Crear índices                                     │
  │  7. Resetear secuencias                              │
  └──────────────────────────────────────────────────────┘
```
**1 — Verificar autenticación MySQL compatible**

pgloader 3.6 no soporta `caching_sha2_password` (el plugin por defecto de MySQL 8).
El fichero `configs/mysql.cnf` ya fuerza `mysql_native_password` globalmente.
Si el contenedor ya estaba corriendo antes de este cambio, recrearlo:

```bash
docker compose down mysql8
docker compose up -d mysql8
```

Si prefieres cambiar solo el usuario sin recrear el contenedor:

```bash
docker exec -it mysql8 mysql -uroot -proot_lab -e "
  ALTER USER 'mysql_user'@'%'
    IDENTIFIED WITH mysql_native_password BY 'mysql_pass';
  FLUSH PRIVILEGES;"
```

**2 — Crear la BD destino en PG17**

pgloader no puede crear BDs por sí solo; la BD destino debe existir antes.
Con el docker-compose actualizado se crea automáticamente al arrancar.
Si el contenedor ya estaba corriendo:

```bash
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres \
  -c "CREATE DATABASE tienda_mysql_migrada;"

```

### 4.2 Migración

```bash
# Migración directa sin fichero de configuración
docker compose run --rm --entrypoint pgloader pgloader \
  "mysql://mysql_user:mysql_pass@mysql8:3306/tienda_mysql" \
  "postgresql://postgres:postgres_lab@pg17:5432/tienda_mysql_migrada"
```

**Salida esperada:**

```
2026-06-15T16:29:16.017000Z LOG pgloader version "3.6.10~devel"
2026-06-15T16:29:16.019000Z LOG Data errors in '/tmp/pgloader/'
2026-06-15T16:29:16.106000Z LOG Migrating from #<MYSQL-CONNECTION mysql://mysql_user@mysql8:3306/tienda_mysql {1005EA1DD3}>
2026-06-15T16:29:16.106000Z LOG Migrating into #<PGSQL-CONNECTION pgsql://postgres@pg17:5432/tienda_mysql_migrada {100618F073}>
2026-06-15T16:29:16.601000Z LOG report summary reset
                table name     errors       rows      bytes      total time
--------------------------  ---------  ---------  ---------  --------------
           fetch meta data          0         14                     0.086s
            Create Schemas          0          0                     0.001s
          Create SQL Types          0          0                     0.003s
             Create tables          0         10                     0.015s
            Set Table OIDs          0          5                     0.005s
--------------------------  ---------  ---------  ---------  --------------
    tienda_mysql.productos          0         10     0.8 kB          0.052s
   tienda_mysql.categorias          0          5     0.3 kB          0.067s
      tienda_mysql.pedidos          0          5     0.5 kB          0.093s
tienda_mysql.lineas_pedido          0          8     0.2 kB          0.009s
     tienda_mysql.clientes          0          5     0.7 kB          0.009s
--------------------------  ---------  ---------  ---------  --------------
   COPY Threads Completion          0          4                     0.104s
            Create Indexes          0          9                     0.010s
    Index Build Completion          0          9                     0.138s
           Reset Sequences          0          5                     0.035s
              Primary Keys          0          5                     0.002s
       Create Foreign Keys          0          0                     0.000s
           Create Triggers          0          0                     0.000s
           Set Search Path          0          1                     0.000s
          Install Comments          0          0                     0.000s
--------------------------  ---------  ---------  ---------  --------------
         Total import time          ✓         33     2.4 kB          0.289s

```

### 4.4 Verificar la BD migrada

```bash
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres \
  tienda_mysql_migrada -c "\dt"
                List of relations
    Schema    |     Name      | Type  |  Owner   
--------------+---------------+-------+----------
 tienda_mysql | categorias    | table | postgres
 tienda_mysql | clientes      | table | postgres
 tienda_mysql | lineas_pedido | table | postgres
 tienda_mysql | pedidos       | table | postgres
 tienda_mysql | productos     | table | postgres
(5 rows)

PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_mysql_migrada -c "
SELECT 'clientes' AS tabla, row_to_json(c)::text AS datos FROM clientes c
UNION ALL
SELECT 'productos', row_to_json(p)::text FROM productos p
UNION ALL
SELECT 'categorias', row_to_json(cat)::text FROM categorias cat
UNION ALL
SELECT 'pedidos', row_to_json(ped)::text FROM pedidos ped
ORDER BY tabla;"

# Comparar conteos MySQL vs PostgreSQL
docker exec -it mysql8 mysql -uroot -proot_lab tienda_mysql \
  -e "SELECT 'mysql' AS origen, count(*) FROM clientes
      UNION SELECT 'pg', (SELECT count(*) FROM clientes);"
+--------+----------+
| origen | count(*) |
+--------+----------+
| mysql  |        5 |
| pg     |        5 |
+--------+----------+

```

### Validación MySQL → PostgreSQL

```bash
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres \
  tienda_mysql_migrada \
  -f scripts/validation/validate_mysql_migration.sql

```

---

## 5. Estrategia zero-downtime

Un `pg_dump` + `pg_restore` clásico requiere parar la aplicación porque
los datos siguen llegando durante la migración. La solución es separar
el proceso en fases:

```
Fase 1 — Migración inicial (puede tardar horas en BDs grandes)
──────────────────────────────────────────────────────────────
  Aplicación → PG14  (escrituras normales)
  pg_dump PG14 → pg_restore PG17  (en paralelo, sin parar nada)

Fase 2 — Sincronización de delta (minutos)
──────────────────────────────────────────
  Capturar cambios ocurridos DURANTE la fase 1
  Aplicar delta en PG17 (publicación lógica o WAL streaming)

Fase 3 — Switchover (segundos)
────────────────────────────────
  Parar escrituras en PG14 (modo read-only)
  Verificar que PG17 está al día
  Redirigir conexiones a PG17
  Reanudar escrituras en PG17
```

### Implementación

```bash
# Fase 1: Habilitar WAL logical en PG14 para captura de cambios
PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 -c "
  -- Crear publicación de todos los cambios
  CREATE PUBLICATION pub_migracion FOR ALL TABLES;"

# Verificar la publicación
PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 -c "
  SELECT pubname, puballtables FROM pg_publication;"
    pubname    | puballtables 
---------------+--------------
 pub_migracion | t
(1 row)

# Fase 2: En PG17, suscribirse a los cambios de PG14

El nivel logical añade la información adicional para saber exactamente qué filas cambiaron en cada transacción, que es lo que usa tanto CREATE SUBSCRIPTION como pg_logical

# 1. Cambiar wal_level en PG14
docker exec -it pg14 psql -U postgres -c "
  ALTER SYSTEM SET wal_level = logical;"

# 2. Reiniciar PG14 para que el cambio surta efecto
#    (wal_level requiere restart, no solo reload)
docker restart pg14

# 3. Esperar que vuelva a estar healthy
docker inspect pg14 --format='{{.State.Health.Status}}'

# 4. Verificar que el cambio se aplicó
PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres -c "
  SHOW wal_level;"
#  wal_level
# -----------
#  logical


PGPASSWORD=postgres_lab pg_dump \
  -h localhost -p 5414 -U postgres \
  --schema-only --no-owner --no-acl --format=plain \
  tienda_v1 > dumps/schema_zero_downtime.sql

PGPASSWORD=postgres_lab psql \
  -h localhost -p 5417 -U postgres \
  tienda_v2 < dumps/schema_zero_downtime.sql

PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 -c "
  CREATE SUBSCRIPTION sub_desde_pg14
  CONNECTION 'host=pg14 port=5432 user=postgres password=postgres_lab dbname=tienda_v1'
  PUBLICATION pub_migracion;"

# Monitorizar el lag de replicación lógica
PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 -c "
  SELECT
    slot_name,
    pg_size_pretty(
      pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)
    ) AS lag_pendiente
  FROM pg_replication_slots;
"
                slot_name                | lag_pendiente 
-----------------------------------------+---------------
 sub_desde_pg14                          | 0 bytes
 pg_16874_sync_16727_7651633815638138918 | 168 bytes
 pg_16874_sync_16714_7651633815638138918 | 112 bytes
 pg_16874_sync_16697_7651633815638138918 | 56 bytes
 pg_16874_sync_16689_7651633815638138918 | 0 bytes
(5 rows)


# Fase 3: Switchover cuando el lag sea 0
# 1. Poner PG14 en read-only
PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres -c "
  ALTER DATABASE tienda_v1 SET default_transaction_read_only = on;"

# 2. Esperar que el lag llegue a 0 (pocos segundos)
# 3. Eliminar la suscripción
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 -c "
  DROP SUBSCRIPTION sub_desde_pg14;"

NOTICE:  dropped replication slot "pg_16874_sync_16727_7651633815638138918" on publisher
NOTICE:  dropped replication slot "pg_16874_sync_16714_7651633815638138918" on publisher
NOTICE:  dropped replication slot "pg_16874_sync_16697_7651633815638138918" on publisher
NOTICE:  dropped replication slot "pg_16874_sync_16689_7651633815638138918" on publisher
NOTICE:  dropped replication slot "sub_desde_pg14" on publisher
DROP SUBSCRIPTION


# 4. Redirigir la aplicación a PG17
```

---

## 6. Validación post-migración

### Validación PG14 → PG17

```bash

PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 \
  -f scripts/validation/validate_pg_migration.sql

PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 \
  -f scripts/validation/validate_pg_migration.sql

══════════════════════════════════════════════════════════
  Validación post-migración PG14 → PG17
══════════════════════════════════════════════════════════

▸ 1. Tablas presentes en PG17:
     tablename      | tableowner 
--------------------+------------
 _migracion_control | postgres
 categorias         | postgres
 clientes           | postgres
 lineas_pedido      | postgres
 pedidos            | postgres
 productos          | postgres
(6 rows)


▸ 2. Conteo de filas (verificar igual que PG14):
     tabla     | filas 
---------------+-------
 categorias    |      
 clientes      |      
 lineas_pedido |      
 pedidos       |      
 productos     |      
(5 rows)


▸ 3. Integridad referencial — pedidos sin cliente válido:
 pedidos_huerfanos 
-------------------
                 0
(1 row)

▸ 3b. Líneas de pedido sin pedido válido:
 lineas_huerfanas 
------------------
                0
(1 row)


▸ 4. Tipos de datos de las columnas clave:
     tabla     |  columna  |           tipo           |   tipo_udt    | nulable 
---------------+-----------+--------------------------+---------------+---------
 clientes      | activo    | boolean                  | bool          | NO
 clientes      | creado_en | timestamp with time zone | timestamptz   | NO
 clientes      | direccion | jsonb                    | jsonb         | YES
 clientes      | email     | character varying        | varchar       | NO
 clientes      | id        | integer                  | int4          | NO
 lineas_pedido | id        | integer                  | int4          | NO
 pedidos       | creado_en | timestamp with time zone | timestamptz   | NO
 pedidos       | estado    | USER-DEFINED             | estado_pedido | NO
 pedidos       | id        | integer                  | int4          | NO
 pedidos       | total     | numeric                  | numeric       | NO
 productos     | activo    | boolean                  | bool          | NO
 productos     | atributos | jsonb                    | jsonb         | YES
 productos     | creado_en | timestamp with time zone | timestamptz   | NO
 productos     | id        | integer                  | int4          | NO
 productos     | precio    | numeric                  | numeric       | NO
(15 rows)


▸ 5. Tipos ENUM presentes en PG17:
   enum_name   |                       valores                        
---------------+------------------------------------------------------
 estado_pedido | pendiente, confirmado, enviado, entregado, cancelado
 metodo_pago   | tarjeta, transferencia, paypal, efectivo
(2 rows)


▸ 6. Índices creados en PG17:
 tabla | indice | definicion 
-------+--------+------------
(0 rows)


▸ 7. Vistas migradas:
        viewname         | viewowner 
-------------------------+-----------
 pg_stat_statements      | postgres
 pg_stat_statements_info | postgres
(2 rows)


▸ 8. Funciones migradas:
         funcion          |   tipo   |         retorno          
--------------------------+----------+--------------------------
 armor                    | FUNCTION | text
 armor                    | FUNCTION | text
 crypt                    | FUNCTION | text
 dearmor                  | FUNCTION | bytea
 decrypt                  | FUNCTION | bytea
 decrypt_iv               | FUNCTION | bytea
 digest                   | FUNCTION | bytea
 digest                   | FUNCTION | bytea
 encrypt                  | FUNCTION | bytea
 encrypt_iv               | FUNCTION | bytea
 gen_random_bytes         | FUNCTION | bytea
 gen_random_uuid          | FUNCTION | uuid
 gen_salt                 | FUNCTION | text
 gen_salt                 | FUNCTION | text
 hmac                     | FUNCTION | bytea
 hmac                     | FUNCTION | bytea
 pg_stat_statements       | FUNCTION | record
 pg_stat_statements_info  | FUNCTION | record
 pg_stat_statements_reset | FUNCTION | timestamp with time zone
 pgp_armor_headers        | FUNCTION | record
 pgp_key_id               | FUNCTION | text
 pgp_pub_decrypt          | FUNCTION | text
 pgp_pub_decrypt          | FUNCTION | text
 pgp_pub_decrypt          | FUNCTION | text
 pgp_pub_decrypt_bytea    | FUNCTION | bytea
 pgp_pub_decrypt_bytea    | FUNCTION | bytea
 pgp_pub_decrypt_bytea    | FUNCTION | bytea
 pgp_pub_encrypt          | FUNCTION | bytea
 pgp_pub_encrypt          | FUNCTION | bytea
 pgp_pub_encrypt_bytea    | FUNCTION | bytea
 pgp_pub_encrypt_bytea    | FUNCTION | bytea
 pgp_sym_decrypt          | FUNCTION | text
 pgp_sym_decrypt          | FUNCTION | text
 pgp_sym_decrypt_bytea    | FUNCTION | bytea
 pgp_sym_decrypt_bytea    | FUNCTION | bytea
 pgp_sym_encrypt          | FUNCTION | bytea
 pgp_sym_encrypt          | FUNCTION | bytea
 pgp_sym_encrypt_bytea    | FUNCTION | bytea
 pgp_sym_encrypt_bytea    | FUNCTION | bytea
(39 rows)


▸ 8b. Triggers activos:
 trigger_name | tabla | evento | momento 
--------------+-------+--------+---------
(0 rows)


▸ 9. Secuencias y valor actual:
     sequencename     | last_value | increment_by 
----------------------+------------+--------------
 categorias_id_seq    |         33 |            1
 clientes_id_seq      |         33 |            1
 lineas_pedido_id_seq |            |            1
 pedidos_id_seq       |         33 |            1
 productos_id_seq     |         33 |            1
(5 rows)


▸ 10. Columnas JSONB — clientes con dirección completa:
 id |      email       |  ciudad   | codigo_postal 
----+------------------+-----------+---------------
  1 | alice@ejemplo.es | Madrid    | 28013
  2 | bob@ejemplo.es   | Barcelona | 08002
  3 | carol@ejemplo.es | Sevilla   | 41001
  4 | david@ejemplo.es | Málaga    | 29001
  5 | eva@ejemplo.es   | Zaragoza  | 50001
(5 rows)


▸ 11. Resumen de validación:
 clientes | productos | pedidos | lineas | total_facturado |         ultimo_pedido         
----------+-----------+---------+--------+-----------------+-------------------------------
        5 |         8 |       5 |      0 |         1664.92 | 2026-06-15 14:47:07.138337+00
(1 row)

```

### Checklist de validación manual

```bash
# 1. Conteo de filas por tabla (comparar en origen y destino)
for TABLE in categorias clientes productos pedidos lineas_pedido; do
  SRC=$(PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 \
    -tAc "SELECT count(*) FROM $TABLE")
  DST=$(PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 \
    -tAc "SELECT count(*) FROM $TABLE")
  if [ "$SRC" -eq "$DST" ]; then
    echo "✓ $TABLE: $SRC filas"
  else
    echo "✗ $TABLE: origen=$SRC destino=$DST DISCREPANCIA"
  fi
done

# 2. Verificar totales financieros
echo "Suma total pedidos PG14:"
PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres tienda_v1 \
  -tAc "SELECT sum(total) FROM pedidos"

echo "Suma total pedidos PG17:"
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 \
  -tAc "SELECT sum(total) FROM pedidos"

# 3. Verificar índices
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 \
  -c "SELECT count(*) AS indices FROM pg_indexes WHERE schemaname='public'"

# 4. Verificar secuencias correctas
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 \
  -c "SELECT sequencename, last_value FROM pg_sequences WHERE schemaname='public'"

# 5. Test de inserción en destino
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 -c "
  INSERT INTO clientes (email, nombre, region_id)
  VALUES ('test_migration@lab.com', 'Test Migration', 1)
  ON CONFLICT DO NOTHING;
  SELECT id, email FROM clientes WHERE email='test_migration@lab.com';
  DELETE FROM clientes WHERE email='test_migration@lab.com';"
```

---

## 7. Rollback y contingencia

### Principio fundamental

> **Nunca destruyas el origen hasta que el destino esté validado al 100%.**
> PG14 y MySQL deben seguir operativos durante al menos 24h post-migración.

### Rollback de migración PG14 → PG17

```bash
# Ejecutar el script de rollback
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres tienda_v2 \
  -f scripts/rollback/rollback_pg_migration.sql

# Revertir PG14 de read-only a read-write
PGPASSWORD=postgres_lab psql -h localhost -p 5414 -U postgres -c "
  ALTER DATABASE tienda_v1 RESET default_transaction_read_only;"

# Redirigir aplicación de vuelta a PG14
export DATABASE_URL="postgresql://postgres:postgres_lab@localhost:5414/tienda_v1"
```

### Rollback de migración MySQL → PG

pgloader no modifica MySQL: el origen siempre queda intacto.
El rollback es redirigir la aplicación a MySQL:

```bash
# Volver a MySQL
export DATABASE_URL="mysql://mysql_user:mysql_pass@localhost:3306/tienda_mysql"

# Limpiar la BD migrada en PG17 si quieres reintentar
PGPASSWORD=postgres_lab psql -h localhost -p 5417 -U postgres -c "
  DROP DATABASE IF EXISTS tienda_mysql_migrada;
  CREATE DATABASE tienda_mysql_migrada;"
```

### Plan de contingencia por escenarios

| Escenario | Probabilidad | Acción |
|---|---|---|
| Datos faltantes tras restore | Media | Comparar con `pg_dump --data-only` de tablas individuales |
| Secuencias desincronizadas | Alta | `SELECT setval(...)` en cada tabla |
| Índices no creados | Baja | `CREATE INDEX CONCURRENTLY` manualmente |
| Tipos incompatibles | Media | `ALTER TABLE ... USING cast(...)` |
| Triggers no migrados | Media | Extraer con `pg_dump --section=post-data` y aplicar |
| Timeout durante restore | Baja | `pg_restore --jobs=1` y aumentar `statement_timeout` |
| Error en pgloader | Media | Ver `pgloader --verbose`, corregir `.load` y reintentar |

---

## 8. Referencia de comandos

### pg_dump opciones clave

```bash
# Formatos de salida
--format=plain      # SQL texto plano  (.sql)
--format=custom     # Binario comprimido (.dump) — RECOMENDADO
--format=directory  # Directorio multi-fichero — permite --jobs
--format=tar        # Tar sin compresión

# Control del contenido
--schema-only       # Solo DDL (estructura)
--data-only         # Solo datos (INSERT/COPY)
--section=pre-data  # Esquema + objetos antes de los datos
--section=data      # Solo datos
--section=post-data # Índices, triggers, constraints tras los datos

# Filtrado
--table=nombre      # Solo una tabla
--schema=nombre     # Solo un esquema
--exclude-table=x   # Excluir tabla

# Opciones útiles
--no-owner          # No incluir OWNER en el SQL
--no-acl            # No incluir GRANT/REVOKE
--compress=6        # Nivel de compresión (0=sin, 9=máximo)
--jobs=4            # Paralelo (solo con --format=directory)
--verbose           # Ver progreso
```

### pg_restore opciones clave

```bash
pg_restore \
  -h host -p puerto -U usuario \
  --dbname=nombre_bd \
  --jobs=4 \              # Restauración paralela
  --no-owner \
  --no-acl \
  --disable-triggers \    # Deshabilitar triggers durante carga
  --exit-on-error \       # Parar ante el primer error
  --section=data \        # Solo restaurar datos
  --table=nombre \        # Solo una tabla
  fichero.dump
```

### pgloader opciones clave

```bash
pgloader [opciones] fichero.load
pgloader [opciones] ORIGEN DESTINO

# Opciones
--verbose           # Máximo detalle
--debug             # Incluye SQL generado
--dry-run           # Muestra qué haría sin ejecutar
--on-error-stop     # Parar ante el primer error
--logfile=log.txt   # Guardar log en fichero
```

---

## 9. Estructura del proyecto

```
pg-migrations-lab/
│
├── docker-compose.yml              # 4 servicios: pg14, pg17, mysql8, pgloader
├── configs/
│   └── mysql.cnf                   # Configuración MySQL (charset, binlog)
│
├── scripts/
│   ├── pg/
│   │   ├── 01_seed_pg14.sql        # Esquema + datos en PG14
│   │   └── 02_create_pg17.sql      # Preparar PG17 vacío
│   │
│   ├── mysql/
│   │   ├── 01_seed_mysql.sql       # Esquema + datos en MySQL 8
│   │   └── pgloader.load           # Configuración de pgloader (mapeos, transformaciones)
│   │
│   ├── migration/
│   │   └── migrate_pg.sh           # Orquestador zero-downtime PG14→PG17
│   │
│   ├── validation/
│   │   ├── validate_pg_migration.sql    # Validación PG14→PG17
│   │   └── validate_mysql_migration.sql # Validación MySQL→PG
│   │
│   └── rollback/
│       └── rollback_pg_migration.sql   # Estrategia de rollback PG14→PG17
│
└── dumps/                          # Directorio compartido para ficheros dump
    └── (generado en runtime)
```

---

## 📋 Credenciales

| Servicio | Host | Puerto | Usuario | Contraseña | BD |
|---|---|---|---|---|---|
| PostgreSQL 14 | localhost | 5414 | `postgres` | `postgres_lab` | `tienda_v1` |
| PostgreSQL 17 | localhost | 5417 | `postgres` | `postgres_lab` | `tienda_v2` |
| MySQL 8 | localhost | 3306 | `root` | `root_lab` | `tienda_mysql` |
| MySQL 8 (app) | localhost | 3306 | `mysql_user` | `mysql_pass` | `tienda_mysql` |
