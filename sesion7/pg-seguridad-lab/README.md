# 🔐 Lab: Seguridad, Parches y Endurecimiento PostgreSQL con Docker

> Una sola instancia PostgreSQL 16 con **pgAudit**, **SSL/TLS** y todos los
> objetos del laboratorio preconfigurados. Cada práctica se ejecuta con un
> único comando `docker exec` desde tu terminal.

---

## 🗂️ Estructura del laboratorio

```
pg-seguridad-lab/
├── docker-compose.yml              # Un contenedor PostgreSQL 16 + pgAudit
├── Dockerfile                      # PG 16 + pgaudit + openssl
│
├── configs/
│   ├── postgresql.conf             # pgAudit, SSL, timeouts de seguridad
│   └── pg_hba.conf                 # Reglas de autenticación del lab
│
└── scripts/
    ├── entrypoint.sh               # Genera SSL, inicializa PG, ejecuta init_lab.sql
    ├── init_lab.sql                # Crea roles, tablas, datos, RLS, funciones
    │
    ├── practica_01_autenticacion.sql      # pg_hba, SCRAM, timeouts
    ├── practica_02_roles_privilegios.sql  # Roles, GRANT, separación de funciones
    ├── practica_03_rls_search_path.sql    # search_path, RLS por cliente y región
    ├── practica_04_politicas_seguridad.sql# SECURITY DEFINER, SQL Injection
    ├── practica_05_ssl_tls.sql            # Verificar SSL, conexiones cifradas
    ├── practica_06_pgaudit.sql            # pgAudit, logs, tabla de auditoría
    └── checklist_hardening.sql            # Checklist automatizado PASS/WARN/FAIL
```

---

## ⚡ Inicio rápido

### 1 — Construir y levantar

```bash
cd pg-seguridad-lab
chmod +x scripts/*.sh

docker compose up --build -d

# Seguir la inicialización (tarda ~30s)
docker compose logs -f
```

**Salida esperada al finalizar:**

```
[SETUP] ✓ Laboratorio de seguridad inicializado correctamente
[SETUP]   BD: dwh | Esquemas: raw, marts
[SETUP]   Roles: dba_ana, app_backend, reporting_svc, monitor_user, agente_norte, agente_sur
[SETUP]   Tablas: raw.pedidos (500 filas), raw.auditoria_accesos, raw.permisos_agente
[SETUP] Laboratorio de Seguridad listo. Puerto: 5432

dwh=# \dn
      List of schemas
  Name  |       Owner       
--------+-------------------
 marts  | postgres
 public | pg_database_owner
 raw    | postgres
(3 rows)

dwh-# \dt raw.*
               List of relations
 Schema |       Name        | Type  |  Owner   
--------+-------------------+-------+----------
 raw    | auditoria_accesos | table | postgres
 raw    | pedidos           | table | postgres
 raw    | permisos_agente   | table | postgres
(3 rows)

```



### 2 — Verificar que está listo

```bash
docker exec -it pg-security psql -U postgres -d dwh \
    -c "SELECT rolname FROM pg_roles WHERE rolname NOT LIKE 'pg_%' ORDER BY rolname;"

   rolname     
----------------
 agente_norte
 agente_sur
 app_backend
 dba_ana
 monitor_user
 postgres
 reporting_svc
 role_app_read
 role_app_write
 role_dba
(10 rows)


docker exec -it pg-security psql -U postgres -d dwh \
    -c "SELECT * FROM pg_roles WHERE rolname NOT LIKE 'pg_%' ORDER BY rolname;"
```

---

## 📋 Credenciales del laboratorio

| Rol | Contraseña | Función |
|---|---|---|
| `postgres` | `postgres_lab` | Superusuario (usar solo para admin) |
| `dba_ana` | `dba_ana_pass_2025` | DBA — miembro de `role_dba` |
| `app_backend` | `app_pass_2025` | Aplicación — lectura/escritura |
| `reporting_svc` | `report_pass_2025` | Reporting — solo lectura |
| `monitor_user` | `monitor_pass_2025` | Monitorización — `pg_monitor` |
| `agente_norte` | `agente_norte_2025` | RLS por región Norte/Este |
| `agente_sur` | `agente_sur_2025` | RLS por región Sur/Oeste |

---

## Práctica 1 — `pg_hba.conf`, Autenticación y Endurecimiento

```bash
docker exec -it pg-security psql -U postgres -d dwh \
    -f /scripts/practica_01_autenticacion.sql
```

### También puedes ejecutar los comandos uno a uno:

```bash
# Ver las reglas activas de pg_hba.conf
docker exec -it pg-security psql -U postgres -d dwh -c "
    SELECT line_number, type, database, user_name, address, auth_method
    FROM pg_hba_file_rules ORDER BY line_number;"

# Ver el método de cifrado de contraseñas
docker exec -it pg-security psql -U postgres -c "SHOW password_encryption;"

# Ver qué usuarios tienen hash MD5 (candidatos a migrar a SCRAM)
docker exec -it pg-security psql -U postgres -c "
    SELECT usename, left(passwd,12) AS hash_tipo
    FROM pg_shadow ORDER BY usename;"

# Ver estado de expiración de contraseñas
docker exec -it pg-security psql -U postgres -c "
    SELECT rolname, rolvaliduntil,
           CASE WHEN rolvaliduntil IS NULL THEN '⚠ SIN EXPIRACIÓN'
                WHEN rolvaliduntil < now() THEN '🔴 EXPIRADA'
                ELSE '🟢 VÁLIDA'
           END AS estado
    FROM pg_roles WHERE rolcanlogin ORDER BY rolvaliduntil NULLS FIRST;"

# Recargar pg_hba.conf sin reiniciar
docker exec -it pg-security psql -U postgres -c "SELECT pg_reload_conf();"
```

---

## Práctica 2 — Roles, Privilegios y Separación de Funciones

```bash
docker exec -it pg-security psql -U postgres -d dwh \
    -f /scripts/practica_02_roles_privilegios.sql
```

### Comandos individuales:

```bash
# Ver árbol de roles
docker exec -it pg-security psql -U postgres -d dwh -c "
    SELECT r.rolname AS usuario, r2.rolname AS miembro_de
    FROM pg_roles r
    JOIN pg_auth_members m ON m.member = r.oid
    JOIN pg_roles r2 ON m.roleid = r2.oid
    WHERE r.rolname NOT LIKE 'pg_%'
    ORDER BY r2.rolname, r.rolname;"

    usuario    |   miembro_de   
---------------+----------------
 monitor_user  | pg_monitor
 agente_norte  | role_app_read
 agente_sur    | role_app_read
 reporting_svc | role_app_read
 app_backend   | role_app_write
 dba_ana       | role_dba
(6 rows)


# Ver privilegios sobre tablas del schema raw
docker exec -it pg-security psql -U postgres -d dwh -c "
    SELECT grantee, table_name,
           string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
    FROM information_schema.table_privileges
    WHERE table_schema = 'raw' AND grantee NOT IN ('postgres','PUBLIC')
    GROUP BY grantee, table_name ORDER BY grantee, table_name;"

    grantee     |    table_name     |                          privilegios                          
----------------+-------------------+---------------------------------------------------------------
 role_app_read  | auditoria_accesos | SELECT
 role_app_read  | pedidos           | SELECT
 role_app_read  | permisos_agente   | SELECT
 role_app_write | auditoria_accesos | DELETE, INSERT, SELECT, UPDATE
 role_app_write | pedidos           | DELETE, INSERT, SELECT, UPDATE
 role_app_write | permisos_agente   | DELETE, INSERT, SELECT, UPDATE
 role_dba       | auditoria_accesos | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
 role_dba       | pedidos           | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
 role_dba       | permisos_agente   | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
(9 rows)


# Probar que app_backend NO puede hacer DDL
docker exec -it pg-security psql -U app_backend \
    -h localhost -p 5432 -d dwh \
    -c "CREATE TABLE raw.test_forbidden (id INT);" 2>&1 || \
    echo "✓ Correcto: DDL denegado para app_backend"

# Probar que reporting_svc no puede hacer INSERT
docker exec -it pg-security psql -U reporting_svc \
    -p 5432 -d dwh \
    -c "INSERT INTO raw.pedidos (cliente_id, estado) VALUES (1, 'pendiente');" 2>&1 || \
    echo "✓ Correcto: INSERT denegado para reporting_svc"

# Probar que reporting_svc SÍ puede leer
$ docker exec -it pg-security psql -U reporting_svc \
    -p 5432 -d dwh \
    -c "SELECT count(*) AS pedidos_visibles FROM raw.pedidos;"
Password for user reporting_svc: report_pass_2025

 pedidos_visibles 
------------------
              500
(1 row)

```

---

## Práctica 3 — `search_path` y Row Level Security (RLS)

```bash
docker exec -it pg-security psql -U postgres -d dwh \
    -f /scripts/practica_03_rls_search_path.sql
```

### Comandos individuales:

```bash
# Verificar que RLS está activo en raw.pedidos
docker exec -it pg-security psql -U postgres -d dwh -c "
    SELECT relname, relrowsecurity AS rls_activo, relforcerowsecurity AS force_rls
    FROM pg_class WHERE relname = 'pedidos' AND relnamespace = 'raw'::regnamespace;"

 relname | rls_activo | force_rls 
---------+------------+-----------
 pedidos | t          | t
(1 row)


# Ver todas las políticas RLS
docker exec -it pg-security psql -U postgres -d dwh -c "
    SELECT policyname, permissive, roles::TEXT, cmd,
           left(qual::TEXT,60) AS condicion
    FROM pg_policies WHERE tablename = 'pedidos'
    ORDER BY policyname;"

# Probar RLS como app_backend — cliente 42 solo ve SUS pedidos
docker exec -it pg-security psql -U postgres -d dwh -c "
    SET ROLE app_backend;
    BEGIN;
    SET LOCAL app.current_client_id = '42';
    SELECT count(*) AS pedidos_visible,
           count(*) FILTER (WHERE cliente_id = 42) AS son_del_cliente_42,
           count(*) FILTER (WHERE cliente_id != 42) AS de_otros_clientes
    FROM raw.pedidos;
    COMMIT;
    RESET ROLE;"

docker exec -it pg-security psql -U postgres -d dwh -c "
    SET ROLE app_backend;
    BEGIN;
    SET LOCAL app.current_client_id = '42';
    SELECT * FROM raw.pedidos;
    COMMIT;
    RESET ROLE;"

# Probar RLS como agente_norte — solo ve Norte y Este, sin cancelados
docker exec -it pg-security psql -U postgres -d dwh -c "
    SET ROLE agente_norte;
    SELECT metadatos_pago->>'region' AS region, estado, count(*)
    FROM raw.pedidos
    GROUP BY 1, 2 ORDER BY 1, 2;
    RESET ROLE;"

# Comparar: dba_ana ve TODO (sin restricción de RLS)
docker exec -it pg-security psql -U postgres -d dwh -c "
    SET ROLE dba_ana;
    SELECT count(*) AS total_sin_filtro FROM raw.pedidos;
    RESET ROLE;"
```

---

## Práctica 4 — Políticas de Seguridad

```bash
docker exec -it pg-security psql -U postgres -d dwh \
    -f /scripts/practica_04_politicas_seguridad.sql
```

### Comandos individuales:

```bash
# Ver funciones SECURITY DEFINER existentes
docker exec -it pg-security psql -U postgres -d dwh -c "
    SELECT n.nspname AS esquema, p.proname AS funcion,
           CASE p.prosecdef WHEN true THEN 'SECURITY DEFINER ⚠' ELSE 'INVOKER ✓' END AS tipo
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('raw','marts')
    ORDER BY n.nspname, p.proname;"

 esquema |          funcion          |        tipo        
---------+---------------------------+--------------------
 raw     | actualizar_estado_pedido  | SECURITY DEFINER ⚠
 raw     | buscar_estatico           | INVOKER ✓
 raw     | buscar_inseguro           | INVOKER ✓
 raw     | buscar_seguro             | INVOKER ✓
 raw     | obtener_mis_pedidos       | INVOKER ✓
 raw     | registrar_acceso_sensible | SECURITY DEFINER ⚠
(6 rows)


# Probar función SECURITY DEFINER: app_backend actualiza sin UPDATE directo

docker exec -it pg-security psql -U postgres -d dwh -c "
    -- app_backend no tiene UPDATE directo pero usa la función:
    SET ROLE app_backend;
    UPDATE raw.pedidos SET estado = 'cancelado' WHERE id = 1;
    RESET ROLE;
    -- Verificar que cambió:
    SELECT id, estado FROM raw.pedidos WHERE id = 1;"

docker exec -it pg-security psql -U postgres -d dwh -c "
    -- app_backend no tiene UPDATE directo pero usa la función:
    SET ROLE app_backend;
    SELECT raw.actualizar_estado_pedido(1, 'pendiente');
    RESET ROLE;
    -- Verificar que cambió:
    SELECT id, estado FROM raw.pedidos WHERE id = 1;"

# Probar SQL Injection: función segura vs insegura
docker exec -it pg-security psql -U postgres -d dwh -c "
    -- Input malicioso en función insegura
    SELECT * FROM raw.buscar_inseguro(''' OR ''1''=''1');
    -- Input malicioso en función segura (devuelve 0)
    SELECT count(*) AS sin_injection  FROM raw.buscar_seguro(''' OR ''1''=''1');
    -- Input malicioso en función segura (devuelve 0)
    SELECT * FROM raw.buscar_estatico(''' OR ''1''=''1');"
```

---

## Práctica 5 — SSL/TLS

```bash
docker exec -it pg-security psql -U postgres -d dwh \
    -f /scripts/practica_05_ssl_tls.sql
```

### Verificar SSL desde el host:

```bash
# Ver si el servidor tiene SSL activo
docker exec -it pg-security psql -U postgres -c "SHOW ssl;"

# Ver configuración SSL completa
docker exec -it pg-security psql -U postgres -c "
    SELECT name, setting FROM pg_settings
    WHERE name LIKE 'ssl%' ORDER BY name;"

# Ver el estado SSL de todas las conexiones activas
docker exec -it pg-security psql -U postgres -c "
    SELECT a.usename, a.client_addr,
           CASE WHEN s.ssl THEN '🔒 ' || s.version ELSE '⚠ Sin SSL' END AS cifrado
    FROM pg_stat_activity a
    LEFT JOIN pg_stat_ssl s ON s.pid = a.pid
    WHERE a.usename IS NOT NULL;"

# Copiar el certificado CA al host y conectar con SSL verificado
docker cp pg-security:/etc/postgresql/ssl/ca.crt ./ca.crt

psql "host=localhost port=5432 dbname=dwh user=app_backend \
      sslmode=verify-ca sslrootcert=./ca.crt" \
      -c "SELECT ssl, version AS tls FROM pg_stat_ssl WHERE pid=pg_backend_pid();"
# Password: app_pass_2025
```

---

## Práctica 6 — Auditoría con pgAudit

```bash
docker exec -it pg-security psql -U postgres -d dwh \
    -f /scripts/practica_06_pgaudit.sql

$ docker exec -it pg-security psql -U postgres -d dwh -c "
SELECT name, setting FROM pg_settings
WHERE name IN ('shared_preload_libraries', 'pgaudit.log', 'log_destination',
               'logging_collector', 'log_min_messages');"
           name           |        setting         
--------------------------+------------------------
 log_destination          | stderr
 log_min_messages         | log
 logging_collector        | on
 pgaudit.log              | read, write, ddl, role
 shared_preload_libraries | pgaudit
(5 rows)

$ docker exec -it pg-security ls -la /var/log/postgresql
total 752
drwxrwxr-t 2 postgres postgres   4096 Jul 14 11:49 .
drwxr-xr-x 1 root     root       4096 Jul 14 01:36 ..
-rw------- 1 postgres postgres 752962 Jul 14 13:50 postgresql-2026-07-14.log
-rw------- 1 postgres postgres    463 Jul 14 11:49 startup.log

$ docker exec -it pg-security bash -c 'grep "AUDIT:" /var/log/postgresql/*.log | tail -20'

$ docker exec -it pg-security bash -c 'grep "AUDIT:"| grep "WRITE" /var/log/postgresql/*.log | tail -20'

$ docker exec -it pg-security bash -c 'grep "AUDIT:"| grep "DDL" /var/log/postgresql/*.log | tail -20'

```


---

## ✅ Checklist automático de endurecimiento

```bash
docker exec -it pg-security psql -U postgres -d dwh \
    -f /scripts/checklist_hardening.sql

```

**Salida esperada:**

```
╔═══════════════════════════════════════════════════════╗
║   CHECKLIST DE ENDURECIMIENTO — PostgreSQL Security   ║
╚═══════════════════════════════════════════════════════╝

── RESULTADOS DETALLADOS ────────────────────────────────
 categoria    | resultado | control                              | detalle
--------------+-----------+--------------------------------------+---------------------------
 AUTENTICACIÓN| ✅ PASS   | SSL habilitado                       | ssl = on
 AUTENTICACIÓN| ✅ PASS   | password_encryption = scram-sha-256  | Valor actual: scram-sha-256
 AUTENTICACIÓN| ✅ PASS   | ssl_min_protocol_version >= TLSv1.2  | ssl_min_protocol_version = TLSv1.2
 AUDITORÍA    | ✅ PASS   | pgAudit instalado                    | pgAudit activo
 ...

── PUNTUACIÓN GLOBAL ────────────────────────────────────
 total_pass | total_warn | total_fail | total_controles | puntuacion
 ----------+------------+------------+-----------------+-----------
         14 |          2 |          0 |              16 | 87.5%
```

---

## 🛠️ Comandos de gestión

```bash
# Levantar el laboratorio
docker compose up -d

# Ver logs en tiempo real
docker compose logs -f

# Conectar como superusuario
docker exec -it pg-security psql -U postgres -d dwh

# Conectar como un rol específico (contraseñas en la tabla de arriba)
docker exec -it pg-security psql -U app_backend -h localhost -p 5432 -d dwh

# Reiniciar desde cero (elimina todos los datos)
docker compose down -v && docker compose up --build -d

# Ver el log de PostgreSQL completo
docker exec pg-security cat /var/log/postgresql/postgresql-$(date +%Y-%m-%d).log
```

---

## 📚 Referencias

- [PostgreSQL — Client Authentication](https://www.postgresql.org/docs/current/client-authentication.html)
- [PostgreSQL — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [PostgreSQL — SSL Support](https://www.postgresql.org/docs/current/ssl-tcp.html)
- [pgAudit — Documentación](https://www.pgaudit.org/)
- [CIS PostgreSQL Benchmark](https://www.cisecurity.org/benchmark/postgresql)
