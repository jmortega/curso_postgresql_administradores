# Consultas de diagnóstico PostgreSQL — Guía paso a paso

> Referencia completa de consultas sobre `pg_catalog`, metadatos del sistema,
> estadísticas y diagnóstico de actividad. Cada consulta incluye el comando
> completo para ejecutarse con `docker exec` o con `psql` directamente.

---

## Cómo usar esta guía

Cada sección muestra tres formas de ejecutar la misma consulta:

```bash
# Opción A — desde el host con docker exec (sin SSL, usuario postgres)
docker exec postgres-ssl psql -U postgres -d testdb -c "<SQL>"

# Opción B — desde el host con psql sin certificado cliente (sslmode=require)
psql "host=localhost port=5432 dbname=testdb user=pguser \
      password=pgpassword sslmode=require" \
     -c "<SQL>"

# Opción C — desde el host con psql con certificado cliente (sslmode=verify-full)
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full \
      sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt \
      sslkey=certs/client/client.key" \
     -c "<SQL>"
```

Para no repetir la cadena de conexión en cada comando, puedes exportarla:

```bash
# Sin certificado cliente
export PGCONN="host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require"

# Con certificado cliente
export PGCONN="host=localhost port=5432 dbname=testdb user=pguser \
  sslmode=verify-full sslrootcert=certs/ca/ca.crt \
  sslcert=certs/client/client.crt sslkey=certs/client/client.key"

# Uso posterior
psql "$PGCONN" -c "SELECT version();"
```

O usar el script Python que lo gestiona automáticamente:

```bash
# Ejecutar todas las secciones
python3 test_consultas.py --password pgpassword

# Con certificado cliente
python3 test_consultas.py --password pgpassword \
    --sslcert certs/client/client.crt \
    --sslkey  certs/client/client.key \
    --sslrootcert certs/ca/ca.crt

# Solo una sección: ssl | catalog | objetos | estadisticas | actividad | datos
python3 test_consultas.py --password pgpassword --seccion catalog
```

---

## Índice

1. [Conexión y verificación SSL](#1-conexión-y-verificación-ssl)
2. [pg_catalog y vistas de metadatos esenciales](#2-pg_catalog-y-vistas-de-metadatos-esenciales)
3. [Bases de datos, roles, esquemas, tablespaces y objetos](#3-bases-de-datos-roles-esquemas-tablespaces-y-objetos)
4. [Estadísticas del sistema y pg_stat_statements](#4-estadísticas-del-sistema-y-pg_stat_statements)
5. [Actividad, bloqueos y sesiones](#5-actividad-bloqueos-y-sesiones)

---

## 1. Conexión y verificación SSL

### Ver estado SSL de la sesión actual

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT ssl, version AS protocolo, cipher, bits, client_dn AS cert_cliente
FROM pg_stat_ssl WHERE pid = pg_backend_pid();"

# psql sin cert cliente
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" \
     -c "SELECT ssl, version AS protocolo, cipher, bits FROM pg_stat_ssl WHERE pid = pg_backend_pid();"

# psql con cert cliente (verify-full)
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt sslkey=certs/client/client.key" \
     -c "SELECT ssl, version AS protocolo, cipher, bits, client_dn FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
```

### Ver contexto de la sesión

```bash
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT current_user, current_database(), inet_client_addr(), pg_backend_pid();"
```

---

## 2. pg_catalog y vistas de metadatos esenciales

`pg_catalog` es el esquema interno de PostgreSQL donde residen todas las tablas
de sistema. Es más rico en detalle que `information_schema`.

### 2.1 pg_class — catálogo central de objetos

`pg_class` tiene una fila por tabla, vista, índice, secuencia o tipo compuesto.
`relkind`: `r`=tabla, `v`=vista, `m`=vista materializada, `i`=índice, `S`=secuencia.

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT
    c.relname                                     AS tabla,
    n.nspname                                     AS esquema,
    c.relkind                                     AS tipo,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS tamanio_total,
    c.reltuples::BIGINT                           AS filas_estimadas
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('ventas','rrhh')
  AND c.relkind IN ('r','v','m')
ORDER BY n.nspname, c.relname;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT c.relname AS tabla, n.nspname AS esquema, c.relkind AS tipo,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS tamanio_total,
    c.reltuples::BIGINT AS filas_estimadas
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('ventas','rrhh') AND c.relkind IN ('r','v','m')
ORDER BY n.nspname, c.relname;"

# psql con cert cliente
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt sslkey=certs/client/client.key" -c "
SELECT c.relname AS tabla, n.nspname AS esquema, c.relkind AS tipo,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS tamanio_total
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('ventas','rrhh') AND c.relkind IN ('r','v','m')
ORDER BY n.nspname, c.relname;"
```

### 2.2 pg_attribute — columnas de una tabla

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT
    a.attname                                         AS columna,
    pg_catalog.format_type(a.atttypid, a.atttypmod)  AS tipo,
    a.attnotnull                                      AS obligatorio,
    a.atthasdef                                       AS tiene_default
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c     ON c.oid = a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'ventas' AND c.relname = 'pedidos'
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY a.attnum;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT a.attname AS columna, pg_catalog.format_type(a.atttypid, a.atttypmod) AS tipo,
    a.attnotnull AS obligatorio
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'ventas' AND c.relname = 'pedidos'
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY a.attnum;"
```

### 2.3 pg_index — índices

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT
    i.relname                                       AS indice,
    ix.indisunique                                  AS unico,
    ix.indisprimary                                 AS primario,
    array_to_string(
        ARRAY(SELECT pg_get_indexdef(ix.indexrelid, k+1, true)
              FROM generate_subscripts(ix.indkey, 1) k), ', ') AS columnas,
    pg_size_pretty(pg_relation_size(i.oid))         AS tamanio
FROM pg_catalog.pg_index ix
JOIN pg_catalog.pg_class t ON t.oid = ix.indrelid
JOIN pg_catalog.pg_class i ON i.oid = ix.indexrelid
JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'ventas'
ORDER BY t.relname, i.relname;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT i.relname AS indice, ix.indisunique AS unico, ix.indisprimary AS primario,
    pg_size_pretty(pg_relation_size(i.oid)) AS tamanio
FROM pg_catalog.pg_index ix
JOIN pg_catalog.pg_class t ON t.oid = ix.indrelid
JOIN pg_catalog.pg_class i ON i.oid = ix.indexrelid
JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'ventas'
ORDER BY t.relname, i.relname;"
```

### 2.4 pg_constraint — restricciones

`contype`: `p`=PRIMARY KEY, `f`=FOREIGN KEY, `c`=CHECK, `u`=UNIQUE.

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT conname AS restriccion, contype AS tipo,
    conrelid::regclass AS tabla, confrelid::regclass AS tabla_ref
FROM pg_catalog.pg_constraint
WHERE conrelid::regclass::text LIKE 'ventas.%'
ORDER BY contype, conname;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT conname AS restriccion, contype AS tipo,
    conrelid::regclass AS tabla, confrelid::regclass AS tabla_ref
FROM pg_catalog.pg_constraint
WHERE conrelid::regclass::text LIKE 'ventas.%'
ORDER BY contype, conname;"
```

### 2.5 pg_depend — dependencias entre objetos

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT classid::regclass AS catalogo, objid::regclass AS objeto,
    deptype AS tipo_dependencia
FROM pg_catalog.pg_depend
WHERE refobjid = 'ventas.clientes'::regclass AND deptype != 'i'
ORDER BY classid;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT classid::regclass AS catalogo, objid::regclass AS objeto, deptype
FROM pg_catalog.pg_depend
WHERE refobjid = 'ventas.clientes'::regclass AND deptype != 'i'
ORDER BY classid;"
```

---

## 3. Bases de datos, roles, esquemas, tablespaces y objetos

### 3.1 Bases de datos

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT datname AS base_datos,
    pg_size_pretty(pg_database_size(datname)) AS tamanio,
    datcollate AS collation, datconnlimit AS max_conexiones
FROM pg_catalog.pg_database WHERE NOT datistemplate
ORDER BY pg_database_size(datname) DESC;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT datname AS base_datos,
    pg_size_pretty(pg_database_size(datname)) AS tamanio,
    datcollate AS collation, datconnlimit AS max_conexiones
FROM pg_catalog.pg_database WHERE NOT datistemplate
ORDER BY pg_database_size(datname) DESC;"

# psql con cert cliente
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt sslkey=certs/client/client.key" -c "
SELECT datname AS base_datos,
    pg_size_pretty(pg_database_size(datname)) AS tamanio,
    datcollate AS collation, datconnlimit AS max_conexiones
FROM pg_catalog.pg_database WHERE NOT datistemplate
ORDER BY pg_database_size(datname) DESC;"
```

### 3.2 Roles y usuarios

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT rolname AS rol, rolsuper AS superuser, rolcreatedb AS puede_crear_bd,
    rolcanlogin AS puede_hacer_login, rolconnlimit AS max_conexiones,
    rolvaliduntil AS expira
FROM pg_catalog.pg_roles WHERE rolname NOT LIKE 'pg_%' ORDER BY rolname;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT rolname AS rol, rolsuper AS superuser, rolcanlogin AS puede_hacer_login,
    rolconnlimit AS max_conexiones
FROM pg_catalog.pg_roles WHERE rolname NOT LIKE 'pg_%' ORDER BY rolname;"
```

Membresías de roles:

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT r.rolname AS miembro, g.rolname AS grupo, m.admin_option AS puede_conceder
FROM pg_catalog.pg_auth_members m
JOIN pg_catalog.pg_roles r ON r.oid = m.member
JOIN pg_catalog.pg_roles g ON g.oid = m.roleid
ORDER BY g.rolname, r.rolname;"
```

### 3.3 Esquemas y permisos

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT nspname AS esquema,
    pg_catalog.pg_get_userbyid(nspowner) AS propietario,
    array_to_string(nspacl, ', ') AS permisos
FROM pg_catalog.pg_namespace
WHERE nspname NOT LIKE 'pg_%' AND nspname != 'information_schema'
ORDER BY nspname;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT nspname AS esquema,
    pg_catalog.pg_get_userbyid(nspowner) AS propietario,
    array_to_string(nspacl, ', ') AS permisos
FROM pg_catalog.pg_namespace
WHERE nspname NOT LIKE 'pg_%' AND nspname != 'information_schema'
ORDER BY nspname;"
```

### 3.4 Tablespaces

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT spcname AS tablespace,
    pg_catalog.pg_get_userbyid(spcowner) AS propietario,
    pg_tablespace_location(oid) AS ubicacion,
    pg_size_pretty(pg_tablespace_size(oid)) AS tamanio
FROM pg_catalog.pg_tablespace ORDER BY spcname;"
```

### 3.5 Tamaño de tablas e índices

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT n.nspname AS esquema, c.relname AS tabla,
    pg_size_pretty(pg_relation_size(c.oid))       AS datos,
    pg_size_pretty(pg_indexes_size(c.oid))        AS indices,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
    c.reltuples::BIGINT                            AS filas_est
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
ORDER BY pg_total_relation_size(c.oid) DESC LIMIT 15;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT n.nspname AS esquema, c.relname AS tabla,
    pg_size_pretty(pg_relation_size(c.oid)) AS datos,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
ORDER BY pg_total_relation_size(c.oid) DESC LIMIT 15;"
```

### 3.6 Funciones y procedimientos

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT proname AS funcion, n.nspname AS esquema,
    pg_get_function_identity_arguments(p.oid) AS argumentos,
    prokind AS tipo, prosecdef AS security_definer
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY n.nspname, proname LIMIT 20;"
```

---

## 4. Estadísticas del sistema y pg_stat_statements

Las vistas `pg_stat_*` son acumulativas desde el último `pg_stat_reset()`.
`pg_stat_statements` requiere `shared_preload_libraries = 'pg_stat_statements'`
(ya configurado en el lab).

# Añadir shared_preload_libraries al auto.conf
docker exec postgres-ssl bash -c "
echo \"shared_preload_libraries = 'pg_stat_statements'\" >> /var/lib/postgresql/data/postgresql.auto.conf
echo \"pg_stat_statements.track = all\" >> /var/lib/postgresql/data/postgresql.auto.conf"

# Reiniciar el contenedor (necesario — este parámetro requiere restart)
docker compose restart postgres-ssl

# Verificar que cargó
docker exec postgres-ssl psql -U postgres -c "SHOW shared_preload_libraries;"

### 4.1 pg_stat_database — estadísticas por base de datos

Un `cache_hit_pct` < 95% indica que `shared_buffers` es insuficiente.

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT datname AS base_datos, blks_read, blks_hit,
    round(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    tup_inserted, tup_updated, tup_deleted,
    xact_commit, xact_rollback, deadlocks
FROM pg_stat_database WHERE datname = current_database();"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT datname AS base_datos, blks_read, blks_hit,
    round(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    xact_commit, xact_rollback, deadlocks
FROM pg_stat_database WHERE datname = current_database();"

# psql con cert cliente
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt sslkey=certs/client/client.key" -c "
SELECT datname AS base_datos, blks_read, blks_hit,
    round(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct,
    xact_commit, xact_rollback, deadlocks
FROM pg_stat_database WHERE datname = current_database();"
```

### 4.2 pg_stat_user_tables — actividad por tabla

`seq_scan` alto + `idx_scan` bajo en tablas grandes = falta un índice.

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT schemaname AS esquema, relname AS tabla,
    seq_scan, idx_scan, n_tup_ins, n_tup_upd, n_tup_del,
    n_live_tup, n_dead_tup,
    last_autovacuum::TIMESTAMP(0), last_autoanalyze::TIMESTAMP(0)
FROM pg_stat_user_tables
WHERE schemaname IN ('ventas','rrhh')
ORDER BY seq_scan DESC;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT schemaname AS esquema, relname AS tabla,
    seq_scan, idx_scan, n_live_tup, n_dead_tup,
    last_autovacuum::TIMESTAMP(0)
FROM pg_stat_user_tables
WHERE schemaname IN ('ventas','rrhh')
ORDER BY seq_scan DESC;"
```

### 4.3 pg_stat_user_indexes — uso de índices

```bash
# Índices nunca usados (candidatos a eliminar) — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT schemaname, relname AS tabla, indexrelname AS indice, idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog','information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT schemaname, relname AS tabla, indexrelname AS indice, idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog','information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;"
```

### 4.4 pg_stat_statements — consultas más lentas

```bash
# Top 10 por tiempo medio — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT left(query, 80) AS consulta, calls,
    round(mean_exec_time::numeric, 2) AS media_ms,
    round(max_exec_time::numeric, 2)  AS max_ms,
    round(total_exec_time::numeric, 2) AS total_ms,
    rows
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%' AND calls > 1
ORDER BY mean_exec_time DESC LIMIT 10;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT left(query, 80) AS consulta, calls,
    round(mean_exec_time::numeric, 2) AS media_ms,
    round(total_exec_time::numeric, 2) AS total_ms
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%' AND calls > 1
ORDER BY mean_exec_time DESC LIMIT 10;"

# Resetear estadísticas acumuladas
docker exec postgres-ssl psql -U postgres -d testdb -c "SELECT pg_stat_statements_reset();"
```

### 4.5 pg_settings — parámetros de configuración

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT name, setting, unit, source, context, pending_restart
FROM pg_settings
WHERE name IN (
    'shared_buffers','work_mem','effective_cache_size','max_connections',
    'wal_level','ssl','ssl_min_protocol_version',
    'pg_stat_statements.max','pg_stat_statements.track'
)
ORDER BY name;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT name, setting, unit, source, pending_restart
FROM pg_settings
WHERE name IN (
    'shared_buffers','work_mem','max_connections',
    'ssl','ssl_min_protocol_version','pg_stat_statements.track'
)
ORDER BY name;"

# Parámetros con pending_restart (requieren reinicio)
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT name, setting, pending_restart FROM pg_settings WHERE pending_restart = true;"
```

---

## 5. Actividad, bloqueos y sesiones

### 5.1 pg_stat_activity — sesiones activas

```bash
# Todas las sesiones excepto la propia — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT pid, usename AS usuario, application_name AS aplicacion,
    client_addr AS ip, state, wait_event_type, wait_event,
    round(EXTRACT(EPOCH FROM (now()-query_start))::numeric, 1) AS duracion_s,
    left(query, 60) AS consulta
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY duracion_s DESC NULLS LAST;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT pid, usename AS usuario, state, wait_event_type, wait_event,
    round(EXTRACT(EPOCH FROM (now()-query_start))::numeric, 1) AS duracion_s,
    left(query, 60) AS consulta
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY duracion_s DESC NULLS LAST;"

# psql con cert cliente
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt sslkey=certs/client/client.key" -c "
SELECT pid, usename AS usuario, state, wait_event_type,
    round(EXTRACT(EPOCH FROM (now()-query_start))::numeric, 1) AS duracion_s,
    left(query, 60) AS consulta
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY duracion_s DESC NULLS LAST;"
```

### 5.2 pg_locks — bloqueos activos

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT pid, locktype AS tipo, relation::regclass AS objeto,
    mode, granted,
    CASE granted WHEN true THEN 'obtenido' ELSE 'esperando' END AS estado
FROM pg_locks
WHERE pid <> pg_backend_pid() AND locktype != 'virtualxid'
ORDER BY granted, locktype;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT pid, locktype AS tipo, relation::regclass AS objeto,
    mode, granted,
    CASE granted WHEN true THEN 'obtenido' ELSE 'esperando' END AS estado
FROM pg_locks
WHERE pid <> pg_backend_pid() AND locktype != 'virtualxid'
ORDER BY granted, locktype;"
```

### 5.3 Cadena de bloqueos — quién bloquea a quién

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT blocked.pid AS pid_bloqueado, blocked.usename AS usuario_bloqueado,
    blocking.pid AS pid_bloqueador, blocking.usename AS usuario_bloqueador,
    round(EXTRACT(EPOCH FROM (now()-blocked.query_start))::numeric, 1) AS espera_s,
    left(blocked.query, 50) AS consulta_bloqueada
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock'
ORDER BY espera_s DESC;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT blocked.pid AS pid_bloqueado, blocking.pid AS pid_bloqueador,
    round(EXTRACT(EPOCH FROM (now()-blocked.query_start))::numeric, 1) AS espera_s,
    left(blocked.query, 50) AS consulta_bloqueada
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock' ORDER BY espera_s DESC;"
```

### 5.4 pg_stat_ssl — conexiones SSL activas

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT a.pid, a.usename, a.client_addr,
    s.ssl, s.version AS protocolo, s.cipher, s.bits, s.client_dn AS cert_cliente
FROM pg_stat_activity a
JOIN pg_stat_ssl s USING (pid)
WHERE a.pid <> pg_backend_pid()
ORDER BY s.ssl DESC;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT a.pid, a.usename, s.ssl, s.version AS protocolo, s.cipher, s.bits
FROM pg_stat_activity a
JOIN pg_stat_ssl s USING (pid)
WHERE a.pid <> pg_backend_pid() ORDER BY s.ssl DESC;"
```

### 5.5 pg_stat_replication — réplicas conectadas

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT pid, application_name, client_addr, state,
    sync_state,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS lag_bytes
FROM pg_stat_replication;"
```

### 5.6 Resumen de sesiones por estado

```bash
# docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT
    count(*) AS total,
    count(*) FILTER (WHERE state = 'active')      AS activas,
    count(*) FILTER (WHERE state = 'idle')        AS idle,
    count(*) FILTER (WHERE state LIKE 'idle in%') AS idle_en_tx,
    count(*) FILTER (WHERE wait_event_type='Lock') AS esperando_lock
FROM pg_stat_activity WHERE pid <> pg_backend_pid();"

# psql con cert cliente
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt sslkey=certs/client/client.key" -c "
SELECT count(*) AS total,
    count(*) FILTER (WHERE state = 'active') AS activas,
    count(*) FILTER (WHERE state = 'idle') AS idle,
    count(*) FILTER (WHERE wait_event_type='Lock') AS esperando_lock
FROM pg_stat_activity WHERE pid <> pg_backend_pid();"
```

### 5.7 Terminar sesiones problemáticas

```bash
# Cancelar la consulta activa (la sesión continúa)
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT pg_cancel_backend(pid)
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < now() - interval '10 minutes'
  AND pid <> pg_backend_pid();"

# Terminar la sesión completa
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE usename = 'pguser' AND pid <> pg_backend_pid();"
```

> `pg_cancel_backend` envía SIGINT (cancela solo la consulta).
> `pg_terminate_backend` envía SIGTERM (cierra la conexión).

---

## Referencia rápida de vistas del sistema

| Vista | Descripción |
|---|---|
| `pg_class` | Tablas, vistas, índices, secuencias |
| `pg_attribute` | Columnas de cada relación |
| `pg_index` | Definición de índices |
| `pg_constraint` | PK, FK, CHECK, UNIQUE |
| `pg_namespace` | Esquemas |
| `pg_roles` | Roles y usuarios |
| `pg_database` | Bases de datos del clúster |
| `pg_tablespace` | Tablespaces |
| `pg_settings` | Parámetros de configuración activos |
| `pg_stat_activity` | Sesiones y consultas en curso |
| `pg_stat_database` | Estadísticas acumuladas por BD |
| `pg_stat_user_tables` | Lecturas, escrituras y vacuum por tabla |
| `pg_stat_user_indexes` | Uso de cada índice |
| `pg_stat_ssl` | Estado SSL de cada conexión |
| `pg_stat_replication` | Réplicas streaming conectadas |
| `pg_locks` | Bloqueos activos e intentados |
| `pg_stat_statements` | Estadísticas por texto de consulta (extensión) |

---

## 6. information_schema — consultas estándar SQL

`information_schema` es el esquema estándar ISO/SQL que expone metadatos de forma
portable entre motores (PostgreSQL, MySQL, SQL Server). Es menos detallado que
`pg_catalog` pero más portable y legible.

### 6.1 Tablas y columnas

```bash
# Todas las tablas del usuario actual — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema')
ORDER BY table_schema, table_name;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema')
ORDER BY table_schema, table_name;"

# psql con cert cliente
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt sslkey=certs/client/client.key" -c "
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog','information_schema')
ORDER BY table_schema, table_name;"
```

### 6.2 Columnas de una tabla

```bash
# Columnas de ventas.pedidos con tipo, nulabilidad y default — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT column_name, data_type, character_maximum_length,
    is_nullable, column_default, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'ventas' AND table_name = 'pedidos'
ORDER BY ordinal_position;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT column_name, data_type, character_maximum_length,
    is_nullable, column_default, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'ventas' AND table_name = 'pedidos'
ORDER BY ordinal_position;"
```

### 6.3 Restricciones (PRIMARY KEY, FOREIGN KEY, CHECK, UNIQUE)

```bash
# Todas las restricciones del esquema ventas — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT tc.constraint_name, tc.constraint_type,
    tc.table_schema, tc.table_name,
    kcu.column_name,
    ccu.table_name AS tabla_referenciada,
    ccu.column_name AS columna_referenciada
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name
    AND kcu.table_schema = tc.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'ventas'
ORDER BY tc.constraint_type, tc.constraint_name;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT tc.constraint_name, tc.constraint_type,
    tc.table_name, kcu.column_name,
    ccu.table_name AS tabla_referenciada
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name
    AND kcu.table_schema = tc.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'ventas'
ORDER BY tc.constraint_type, tc.constraint_name;"
```

### 6.4 Privilegios sobre tablas

```bash
# Qué permisos tiene cada usuario sobre las tablas del lab — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT grantee, table_schema, table_name, privilege_type, is_grantable
FROM information_schema.role_table_grants
WHERE table_schema IN ('ventas','rrhh')
ORDER BY grantee, table_schema, table_name, privilege_type;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema IN ('ventas','rrhh')
ORDER BY grantee, table_schema, table_name, privilege_type;"
```

### 6.5 Columnas de clave primaria

```bash
# PKs de todas las tablas del lab — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT kcu.table_schema, kcu.table_name, kcu.column_name, kcu.ordinal_position
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name
    AND kcu.table_schema   = tc.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema IN ('ventas','rrhh')
ORDER BY kcu.table_schema, kcu.table_name, kcu.ordinal_position;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT kcu.table_schema, kcu.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name
    AND kcu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema IN ('ventas','rrhh')
ORDER BY kcu.table_schema, kcu.table_name;"
```

### 6.6 Vistas definidas por el usuario

```bash
# Listar vistas con su definición SQL — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT table_schema, table_name,
    left(view_definition, 120) AS definicion
FROM information_schema.views
WHERE table_schema NOT IN ('pg_catalog','information_schema')
ORDER BY table_schema, table_name;"
```

### 6.7 Secuencias

```bash
# Secuencias del lab con sus valores actuales — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT sequence_schema, sequence_name,
    data_type, start_value, minimum_value, maximum_value, increment
FROM information_schema.sequences
WHERE sequence_schema IN ('ventas','rrhh')
ORDER BY sequence_schema, sequence_name;"

# psql sin cert
psql "host=localhost port=5432 dbname=testdb user=pguser password=pgpassword sslmode=require" -c "
SELECT sequence_schema, sequence_name, start_value, minimum_value, maximum_value
FROM information_schema.sequences
WHERE sequence_schema IN ('ventas','rrhh')
ORDER BY sequence_schema, sequence_name;"
```

### 6.8 Rutinas (funciones y procedimientos)

```bash
# Funciones definidas en el lab — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT routine_schema, routine_name, routine_type,
    data_type AS tipo_retorno, security_type
FROM information_schema.routines
WHERE routine_schema NOT IN ('pg_catalog','information_schema')
ORDER BY routine_schema, routine_name;"
```

### 6.9 Esquemas accesibles por el usuario actual

```bash
# Esquemas visibles con permisos — docker exec
docker exec postgres-ssl psql -U postgres -d testdb -c "
SELECT schema_name, schema_owner
FROM information_schema.schemata
WHERE schema_name NOT LIKE 'pg_%'
  AND schema_name != 'information_schema'
ORDER BY schema_name;"

# psql con cert cliente
psql "host=localhost port=5432 dbname=testdb user=pguser \
      sslmode=verify-full sslrootcert=certs/ca/ca.crt \
      sslcert=certs/client/client.crt sslkey=certs/client/client.key" -c "
SELECT schema_name, schema_owner
FROM information_schema.schemata
WHERE schema_name NOT LIKE 'pg_%'
  AND schema_name != 'information_schema'
ORDER BY schema_name;"
```

### 6.10 Comparativa information_schema vs pg_catalog

| Aspecto | `information_schema` | `pg_catalog` |
|---|---|---|
| Estándar | ISO/SQL — portable entre motores | Específico de PostgreSQL |
| Detalle | Información básica (tipo, nulabilidad, permisos) | Detalle completo (OIDs, flags internos, estadísticas) |
| Rendimiento | Más lento (vistas sobre pg_catalog) | Más rápido (tablas base) |
| Uso recomendado | Scripts portables, auditorías de esquema | Diagnóstico avanzado, DBA, extensiones |
| Metadatos de sistema | No expone catálogos internos | Acceso completo a todo |

