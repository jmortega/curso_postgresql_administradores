# 🐘 Laboratorio: Backup y Recuperación en Clúster PostgreSQL

> **Stack completo con Docker Compose:**
> PostgreSQL 16 · Patroni · etcd · Loki · Promtail · Grafana

---

## 🗂️ Estructura del proyecto

```
lab-pg-cluster/
├── docker-compose.yml              # Orquestación completa del stack
├── Dockerfile.patroni              # Imagen PostgreSQL 16 + Patroni
├── configs/
│   ├── patroni/
│   │   ├── patroni-primary.yml     # Config Patroni nodo primario
│   │   └── patroni-replica.yml    # Config Patroni nodo réplica
│   ├── loki/
│   │   └── loki-config.yml        # Config del agregador de logs
│   ├── promtail/
│   │   ├── promtail-primary.yml   # Agente de logs nodo primario
│   │   └── promtail-replica.yml   # Agente de logs nodo réplica
│   └── grafana/
│       └── provisioning/
│           └── datasources/
│               └── loki.yml       # Datasource Loki autoprovisionado
├── scripts/
│   ├── 02_basebackup.sh           # Backup físico con pg_basebackup
│   ├── 03_pitr_recovery.sh        # Recuperación PITR
│   └── 04_validate_backup.sh      # Validación automatizada
├── logs/                          # Logs de scripts (montado en contenedores)
├── wal_archive/                   # Segmentos WAL archivados (volumen)
└── backups/                       # Base backups (volumen)
```

---

## 🌐 Servicios y puertos

| Servicio | Puerto host | Descripción |
|---|---|---|
| `pg-primary` | `5432` | PostgreSQL primario (lectura/escritura) |
| `pg-replica` | `5433` | PostgreSQL réplica (solo lectura) |
| `pg-primary` Patroni API | `8008` | REST API de Patroni (primario) |
| `pg-replica` Patroni API | `8009` | REST API de Patroni (réplica) |
| `loki` | `3100` | Agregador de logs Loki |
| `grafana` | `3000` | Dashboards Grafana |
| `etcd` | `2379` | etcd (coordinación del clúster) |

---

## ⚡ Inicio rápido

```bash
# 1. Crear directorios locales necesarios
mkdir -p logs wal_archive backups

# 2. Construir la imagen personalizada de Patroni
docker compose build

# 3. Levantar todo el stack
docker compose up -d

# 4. Verificar que todos los servicios están en marcha
docker compose ps
```

**Salida esperada tras ~30 segundos:**

```
NAME              STATUS          PORTS
etcd              running (healthy)   2379/tcp
pg-primary        running (healthy)   0.0.0.0:5432->5432/tcp
pg-replica        running (healthy)   0.0.0.0:5433->5432/tcp
loki              running (healthy)   0.0.0.0:3100->3100/tcp
promtail-primary  running             
promtail-replica  running             
grafana           running (healthy)   0.0.0.0:3000->3000/tcp
```

---

## Práctica 1: Configuración de WAL Archiving en Entorno Clusterizado

### Objetivo
Verificar que el archivado WAL configurado en `patroni-primary.yml` funciona correctamente y comprender sus parámetros.

### Conceptos clave
- **WAL (Write-Ahead Log):** registro secuencial de todos los cambios antes de escribirlos en los ficheros de datos.
- `archive_mode = on` activa el archivado; `archive_command` define cómo copiar cada segmento.
- El directorio `/mnt/wal_archive` es un volumen Docker compartido accesible desde el host en `./wal_archive/`.

### Paso 1 — Verificar la configuración activa

```bash
# Conectar al primario y revisar parámetros WAL
docker exec -it pg-primary psql -U postgres -c "
SELECT name, setting
FROM pg_settings
WHERE name IN (
  'wal_level','archive_mode','archive_command',
  'archive_timeout','max_wal_senders'
)
ORDER BY name;"

     name       |                          setting                           
-----------------+------------------------------------------------------------
 archive_command | test ! -f /mnt/wal_archive/%f && cp %p /mnt/wal_archive/%f
 archive_mode    | on
 archive_timeout | 60
 max_wal_senders | 5
 wal_level       | replica
(5 rows)


```

**Salida esperada:**

```
      name       |                         setting
-----------------+---------------------------------------------------------
 archive_command | test ! -f /mnt/wal_archive/%f && cp %p /mnt/wal_archive/%f
 archive_mode    | on
 archive_timeout | 60
 max_wal_senders | 5
 wal_level       | replica
```

### Paso 2 — Forzar archivado de un segmento WAL

```bash
# Forzar un switch de segmento WAL en el primario
docker exec -it pg-primary psql -U postgres -c "SELECT pg_switch_wal();"

# Verificar que el segmento apareció en el volumen de archivo
docker exec -it pg-primary ls -lh /mnt/wal_archive/

# Consultar estadísticas del archivador
docker exec -it pg-primary psql -U postgres -c "
SELECT archived_count,
       last_archived_wal,
       last_archived_time,
       failed_count,
       last_failed_wal
FROM pg_stat_archiver;"
```

> `failed_count` debe ser **0**. Si es mayor, revisar permisos del directorio `/mnt/wal_archive`.

### Paso 3 — Verificar replicación hacia la réplica

```bash
# Ver estado de los nodos desde Patroni
docker exec -it pg-primary patronictl \
  -c /etc/patroni/patroni.yml list

+ Cluster: pg-lab-cluster (7661739342140674070) +----+-----------+-----------------+
| Member     | Host       | Role    | State     | TL | Lag in MB | Tags            |
+------------+------------+---------+-----------+----+-----------+-----------------+
| pg-primary | pg-primary | Leader  | running   |  1 |           |                 |
| pg-replica | pg-replica | Replica | streaming |  1 |         0 | clonefrom: true |
+------------+------------+---------+-----------+----+-----------+-----------------+


# Comprobar lag de replicación desde la réplica
docker exec -it pg-replica psql -U postgres -c "
SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag,
       pg_is_in_recovery() AS is_replica;"

 replication_lag | is_replica 
-----------------+------------
 00:12:10.785232 | t
(1 row)

```

### Paso 4 — Ajustar `archive_timeout` (opcional)

Si se desea mayor granularidad de recuperación (archivado más frecuente):

```bash
# Cambiar archive_timeout a 30 s en caliente (sin reinicio)
docker exec -it pg-primary psql -U postgres -c "ALTER SYSTEM SET archive_timeout = 30;"
docker exec -it pg-primary psql -U postgres -c "SELECT pg_reload_conf();"
```

---

## Práctica 2: Backup Físico con `pg_basebackup` desde Nodo Primario

### Objetivo
Crear un backup físico completo usando el script `02_basebackup.sh`, que llama a `pg_basebackup` con los parámetros adecuados para un clúster con WAL archiving activo.

### Paso 1 — Ejecutar el backup

```bash
# Lanzar el script de backup dentro del contenedor primario
docker exec -it pg-primary bash /scripts/02_basebackup.sh

# Seguir el progreso en tiempo real
docker exec -it pg-primary tail -f /var/log/pg_scripts/backup.log
```

### Paso 2 — Ejecutar en formato tar (para archivado a largo plazo)

```bash
docker exec -it pg-primary bash /scripts/02_basebackup.sh tar 9
```

### Paso 3 — Verificar el backup desde el host

```bash
# Ver el backup generado en el directorio montado
docker exec -it pg-primary ls -lh /backup/basebackup/

# Revisar el backup_label generado por pg_basebackup
docker exec -it pg-primary bash -c 'cat /backup/basebackup/*/backup_label'
```

**Contenido esperado de `backup_label`:**

```
START WAL LOCATION: 0/3000028 (file 000000010000000000000003)
CHECKPOINT LOCATION: 0/3000060
BACKUP METHOD: streamed
BACKUP FROM: primary
START TIME: 2025-09-01 02:00:05 UTC
...
```

### Paso 4 — Automatizar con cron dentro del contenedor

```bash
# Añadir cron al contenedor primario (en un entorno real usar un job externo)
docker exec -it pg-primary bash -c "
echo '0 2 * * * postgres bash /scripts/02_basebackup.sh >> /var/log/pg_scripts/backup.log 2>&1' \
  > /etc/cron.d/pg_backup && crontab /etc/cron.d/pg_backup"
```

### Paso 5 — Crear un replication slot físico

#### Concepto

Un **replication slot** físico le indica al primario que **no debe eliminar** ni reciclar los segmentos WAL que un consumidor concreto (una réplica, `pg_basebackup` o una herramienta de backup) aún no ha recibido, incluso si ese consumidor se desconecta temporalmente. Sin un slot, si el consumidor se cae más tiempo del que cubre `wal_keep_size`/`archive_command`, se puede producir un error irrecuperable de tipo *"requested WAL segment has already been removed"*.

> ⚠️ **Cuidado en producción:** un slot "huérfano" (sin consumidor activo) hace que el primario retenga WAL indefinidamente, pudiendo llenar el disco. Monitoriza siempre `pg_replication_slots` y elimina los slots que ya no se usen.

#### Crear el slot

```bash
# Crear un slot físico llamado "backup_slot" en el primario
docker exec -it pg-primary psql -U postgres -c "
SELECT pg_create_physical_replication_slot('backup_slot');"

 pg_create_physical_replication_slot 
-------------------------------------
 (backup_slot,)
(1 row)


```

**Salida esperada:**

```
 slot_name   | lsn
-------------+-----
 backup_slot |
```

#### Verificar los slots existentes

```bash
docker exec -it pg-primary psql -U postgres -c "
SELECT slot_name, slot_type, active, restart_lsn, wal_status
FROM pg_replication_slots;"

  slot_name  | slot_type | active | restart_lsn | wal_status 
-------------+-----------+--------+-------------+------------
 pg_replica  | physical  | t      | 0/17000060  | reserved
 backup_slot | physical  | f      |             | 
(2 rows)

docker exec -it pg-primary psql -U postgres -c "
SELECT 
    slot_name, 
    active, 
    wal_status, -- Nos dice si el disco está en riesgo ('normal', 'extended', 'reserved')
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS bytes_retenidos
FROM pg_replication_slots;
"

```

| Columna | Significado |
|---|---|
| `active` | `true` si hay un proceso actualmente consumiendo el slot |
| `restart_lsn` | Punto WAL más antiguo que el primario debe conservar por este slot |
| `wal_status` | `reserved` / `extended` / `unreserved` / `lost` — indica el riesgo de pérdida de WAL |

#### Usar el slot en un backup físico

```bash
# pg_basebackup asociado al slot: el WAL generado durante el backup
# queda retenido aunque el proceso se interrumpa
docker exec -it pg-primary pg_basebackup \
  -h localhost -U replicator \
  -D /backup/basebackup_slot_$(date +%Y%m%d_%H%M%S) \
  --slot=backup_slot \
  --wal-method=stream \
  --checkpoint=fast \
  --progress --verbose

pg_basebackup: initiating base backup, waiting for checkpoint to complete
pg_basebackup: checkpoint completed
pg_basebackup: write-ahead log start point: 0/19000028 on timeline 1
pg_basebackup: starting background WAL receiver
23487/23487 kB (100%), 1/1 tablespace                                         
pg_basebackup: write-ahead log end point: 0/19000100
pg_basebackup: waiting for background process to finish streaming ...
pg_basebackup: syncing data to disk ...
pg_basebackup: renaming backup_manifest.tmp to backup_manifest
pg_basebackup: base backup completed

```

> El slot debe crearse **antes** de lanzar `pg_basebackup --slot=...`; la herramienta no lo crea automáticamente salvo que se use `--create-slot` en el mismo comando.

En su estado actual (wal_status = reserved) no hay riesgo inmediato — el WAL retenido todavía cabe dentro de márgenes normales. Pero si dejas esos dos slots inactivos así indefinidamente, cada nuevo segmento WAL que se genere en el primario se irá acumulando sin poder liberarse, hasta que:

1.wal_status pase a extended (ya se salió del margen normal, pero Patroni/Postgres aún lo retienen)
2.luego a unreserved (riesgo real)
3.y en el peor caso, si el disco se llena antes, el primario puede quedarse sin espacio y dejar de aceptar escrituras — el fallo clásico de "slot huérfano llena el disco"

#### Crear y usar el slot en un solo paso (alternativa)

```bash
docker exec -it pg-primary pg_basebackup \
  -h localhost -U replicator \
  -D /backup/basebackup_autoslot_$(date +%Y%m%d_%H%M%S) \
  --slot=basebackup_auto --create-slot \
  --wal-method=stream --checkpoint=fast
```

#### Eliminar un slot que ya no se necesita

```bash
docker exec -it pg-primary psql -U postgres -c "
SELECT pg_drop_replication_slot('backup_slot');"
```

---

## Práctica 3: Simulación de Desastre y Recuperación PITR en Clúster

### Objetivo
Simular la pérdida accidental de datos y recuperar hasta el momento exacto anterior al desastre.

### Paso 1 — Crear datos y registrar el punto seguro

```bash
# Crear tabla con datos de prueba en el primario
docker exec -i pg-primary psql -U postgres << 'EOF'
CREATE DATABASE lab_pitr;
\c lab_pitr
CREATE TABLE datos_criticos AS
  SELECT generate_series(1, 10000) AS id,
         md5(random()::text)       AS valor,
         now()                     AS creado_en;
-- Registrar timestamp ANTES del desastre
SELECT now() AS punto_seguro;
EOF
```

> **⚠️ Anotar el timestamp mostrado.** Se usará como `recovery_target_time`.

### Paso 2 — Realizar un backup ANTES del desastre

```bash
docker exec -it pg-primary bash /scripts/02_basebackup.sh
```

### Paso 3 — Simular el desastre

```bash
# Esperar unos segundos y ejecutar el DROP
sleep 5
docker exec -it pg-primary psql -U postgres -d lab_pitr \
  -c "DROP TABLE datos_criticos;"

# Confirmar que la tabla ya no existe
docker exec -it pg-primary psql -U postgres -d lab_pitr -c "\dt"
```

### Paso 4 — Lanzar la recuperación PITR

```bash
# Usar el timestamp anotado en el Paso 1 (ajustar el valor)
docker exec -it pg-primary bash /scripts/03_pitr_recovery.sh \
  "2026-07-12 21:54:48"

[2026-07-12 22:00:48] INICIO: recuperación PITR hasta '2026-07-12 21:54:48'
[2026-07-12 22:00:48] INFO: usando backup /backup/basebackup/20260712_215515/
localhost:5432 - no response
[2026-07-12 22:00:48] INFO: renombrando PGDATA actual a /data/patroni_pre_recovery_20260712_220048
[2026-07-12 22:00:48] INFO: restaurando base backup...
     49,301,111 100%  195.91MB/s    0:00:00 (xfr#1278, to-chk=0/1306)  
[2026-07-12 22:00:48] INFO: configuración PITR escrita en postgresql.auto.conf
[2026-07-12 22:00:48] INFO: iniciando PostgreSQL en modo recuperación...
waiting for server to start.... done
server started
[2026-07-12 22:00:48] INFO: monitorizando recuperación (máx. 5 min)...
localhost:5432 - accepting connections
[2026-07-12 22:00:48] PASS: PostgreSQL disponible tras recuperación PITR
[2026-07-12 22:00:48] INFO: verificando datos recuperados...
             now              | pg_is_in_recovery 
------------------------------+-------------------
 2026-07-12 22:00:59.46296+00 | t
(1 row)

[2026-07-12 22:00:48] FIN: recuperación PITR completada --- target='2026-07-12 21:54:48'


# Monitorizar el log de recuperación
docker exec -it pg-primary tail -f /var/log/pg_scripts/recovery.log
```

**Mensajes clave esperados en el log:**

```
LOG:  starting point-in-time recovery to 2025-09-01 11:44:59+00
LOG:  restored log file "000000010000000000000003" from archive
LOG:  recovery stopping before commit of transaction ...
LOG:  database system is ready to accept read only connections
```

### Paso 5 — Verificar los datos recuperados

```bash

docker exec -it pg-primary psql -U postgres -d lab_pitr -c "\dt"

             List of relations
 Schema |      Name      | Type  |  Owner   
--------+----------------+-------+----------
 public | datos_criticos | table | postgres
(1 row)


docker exec -it pg-primary psql -U postgres -d lab_pitr \
  -c "SELECT count(*) FROM datos_criticos;"
# Resultado esperado: 10000

docker exec -it pg-primary psql -U postgres \
  -c "SELECT pg_is_in_recovery();"
# Resultado esperado: f (promoted, ya es primario)
```

### Paso 6 — Reintegrar la réplica tras la recuperación

```bash
# Reinicializar la réplica para que siga al nuevo primario
docker exec -it pg-primary patronictl \
  -c /etc/patroni/patroni.yml reinit pg-lab-cluster pg-replica --force

+ Cluster: pg-lab-cluster (7661739342140674070) ---+-----------+-----------------+
| Member     | Host       | Role    | State   | TL | Lag in MB | Tags            |
+------------+------------+---------+---------+----+-----------+-----------------+
| pg-primary | pg-primary | Replica | running |  3 |       111 |                 |
| pg-replica | pg-replica | Leader  | running |  2 |           | clonefrom: true |
+------------+------------+---------+---------+----+-----------+-----------------+
Error: No replica among provided members


# Verificar estado del clúster
docker exec -it pg-primary patronictl \
  -c /etc/patroni/patroni.yml list
```

---

## Práctica 4: Validación de Backups y Simulacros de Restauración en Entorno HA

### Objetivo
Verificar de forma automatizada que los backups son restaurables, y practicar un failover controlado del clúster.

### Paso 1 — Validar el backup más reciente

```bash
# Ejecutar el script de validación
docker exec -it pg-primary bash /scripts/04_validate_backup.sh

# Ver resultados detallados
docker exec -it pg-primary cat /var/log/pg_scripts/validate.log
```

**Salida esperada:**

```
[2025-09-01 03:00:10] INICIO: validación de backup ===
[2025-09-01 03:00:10] PASS: backup_label encontrado
[2025-09-01 03:00:12] PASS: checksums SHA256 verificados correctamente
[2025-09-01 03:00:14] PASS: pg_checksums internos OK
[2025-09-01 03:00:22] PASS: instancia temporal arrancó y acepta conexiones
[2025-09-01 03:00:22] PASS: catálogo de tablas accesible --- 87 tablas encontradas
[2025-09-01 03:00:22] === RESUMEN: 5 pruebas pasadas, 0 fallos ===
[2025-09-01 03:00:22] FIN: backup válido y restaurable
```

### Paso 2 — Simulacro de failover (Game Day)

```bash
# Registrar inicio del simulacro
echo "=== INICIO SIMULACRO $(date) ===" | tee -a logs/gameday.log

# Simular caída del primario (parar el contenedor)
docker stop pg-primary

# Verificar que Patroni promueve la réplica automáticamente
# (observar desde el host con la Patroni API de la réplica)
sleep 5
curl -s http://localhost:8009/patroni | python3 -m json.tool

# Medir RTO: tiempo hasta que la réplica es primaria
echo "Nueva primaria elegida: $(date)" | tee -a logs/gameday.log
```

### Paso 3 — Verificar disponibilidad durante el failover

```bash
# Conectar al nuevo primario (ahora en el puerto 5433)
psql -h localhost -p 5433 -U postgres \
  -c "SELECT pg_is_in_recovery(), now();"

# La réplica anterior debe indicar is_in_recovery = false
# (se ha promovido a primario)
```

### Paso 4 — Reincorporar el nodo original como réplica

```bash
# Reiniciar el contenedor original
docker start pg-primary

# Reinicializar como réplica del nuevo primario
sleep 10
docker exec -it pg-replica patronictl \
  -c /etc/patroni/patroni.yml reinit pg-lab-cluster pg-primary --force

# Estado final del clúster
docker exec -it pg-replica patronictl \
  -c /etc/patroni/patroni.yml list
```

### Paso 5 — Automatizar validaciones con cron

```bash
# Validación semanal (domingos a las 3:00 AM)
docker exec -it pg-primary bash -c "
echo '0 3 * * 0 postgres bash /scripts/04_validate_backup.sh' \
  > /etc/cron.d/pg_validate"
```

---

## Práctica 5: Integración con Loki para Centralización de Logs

### Objetivo
Verificar que los logs de PostgreSQL, Patroni, backup y validación llegan correctamente a Loki y crear consultas y alertas en Grafana.

### Paso 1 — Verificar que Promtail envía logs a Loki

```bash
# Estado de Promtail del primario
docker logs promtail-primary --tail 20

# Verificar que Loki recibe datos (API de health)
curl -s http://localhost:3100/ready
# Respuesta esperada: "ready"

# Consultar etiquetas disponibles en Loki
curl -s "http://localhost:3100/loki/api/v1/labels" | python3 -m json.tool
```

### Paso 2 — Acceder a Grafana

```
URL:      http://localhost:3000
Usuario:  admin
Password: grafana_lab_2025
```

### Paso 3 — Explorar logs en Grafana (Explore → Loki)

**Consultas LogQL de ejemplo:**

```logql
# Todos los logs del clúster
{cluster="pg-lab-cluster"}

# Solo errores del primario
{job="postgresql", node="pg-primary"} |= "ERROR"

# Ver archivado WAL fallido
{job="postgresql"} |= "archive command failed"

# Resultados de validaciones de backup
{job="pg-validate"} |~ "(PASS|FAIL)"

# Logs de backup con estado
{job="pg-backup"} | line_format "{{.status}}: {{.message}}"

# Detección de inicio de recuperación PITR
{job="postgresql"} |= "point-in-time recovery"

# Actividad de Patroni (cambios de líder)
{job="patroni"} |= "promoted"
```

### Paso 4 — Crear un dashboard básico de backup

En Grafana → **Dashboards → New → Add visualization**:

**Panel 1: Últimas operaciones de backup**
```logql
{job="pg-backup", node="pg-primary"}
| line_format "{{.status}} | {{.message}}"
```

**Panel 2: Errores de PostgreSQL en tiempo real**
```logql
{job="postgresql", cluster="pg-lab-cluster", level="ERROR"}
  | line_format "{{.node}} | {{.message}}"
```

**Panel 3: Tasa de errores WAL (últimas 24h)**
```logql
sum(
  count_over_time(
    {job="postgresql"} |= "archive command failed" [1h]
  )
) by (node)
```

### Paso 5 — Configurar alertas en Grafana

En Grafana → **Alerting → Alert rules → New rule**:

**Alerta: WAL archive fallido**
- **Consulta:**
  ```logql
  count_over_time({job="postgresql"} |= "archive command failed" [5m]) > 0
  ```
- **Condición:** valor > 0
- **Severidad:** Critical
- **Mensaje:** `Archivado WAL fallido en {{ $labels.node }}`

**Alerta: Backup script con errores**
- **Consulta:**
  ```logql
  count_over_time({job="pg-backup"} |= "FAIL" [1h]) > 0
  ```
- **Mensaje:** `Script de backup con errores — revisar /var/log/pg_scripts/backup.log`

---

## 🔧 Comandos de administración útiles

```bash
# Estado completo del clúster
docker exec -it pg-primary patronictl \
  -c /etc/patroni/patroni.yml list

# Failover manual controlado
docker exec -it pg-primary patronictl \
  -c /etc/patroni/patroni.yml failover pg-lab-cluster \
  --master pg-primary --candidate pg-replica --force

# Ver logs del primario en tiempo real
docker logs pg-primary -f

# Reiniciar solo PostgreSQL dentro del contenedor (Patroni lo gestiona)
docker exec -it pg-primary patronictl \
  -c /etc/patroni/patroni.yml restart pg-lab-cluster pg-primary

# Listar todos los replication slots y su estado
docker exec -it pg-primary psql -U postgres -c "
SELECT slot_name, slot_type, active, restart_lsn, wal_status
FROM pg_replication_slots;"

# Eliminar un replication slot inactivo (libera WAL retenido)
docker exec -it pg-primary psql -U postgres -c "
SELECT pg_drop_replication_slot('nombre_del_slot');"

# Detener todo el laboratorio
docker compose down

# Detener y eliminar volúmenes (ELIMINA TODOS LOS DATOS)
docker compose down -v
```

---

## 📊 Resumen de verificaciones por práctica

| Práctica | Comando de verificación | Resultado esperado |
|---|---|---|
| 1. WAL Archiving | `SELECT * FROM pg_stat_archiver;` | `failed_count = 0` |
| 2. Base Backup | `cat backups/basebackup/*/backup_label` | Fecha y LSN válidos |
| 3. PITR | `SELECT count(*) FROM datos_criticos;` | `10000` filas |
| 4. Validación | `cat logs/validate.log \| grep RESUMEN` | `0 fallos` |
| 5. Loki | `curl localhost:3100/loki/api/v1/labels` | Labels de PostgreSQL visibles |

---

## ⚠️ Errores frecuentes y soluciones

### El primario no arranca con Patroni
```bash
# Ver logs de arranque
docker logs pg-primary --tail 50

# Verificar que etcd es accesible
docker exec -it pg-primary curl -s http://etcd:2379/health
```

### WAL no se archiva (`failed_count > 0`)
```bash
# Verificar permisos del directorio de archivo
docker exec -it pg-primary ls -la /mnt/wal_archive/

# Probar archive_command manualmente
docker exec -it pg-primary bash -c "
  cp /data/patroni/pg_wal/\$(ls /data/patroni/pg_wal | head -1) \
     /mnt/wal_archive/test_wal && echo OK"
```

### pg_basebackup falla por autenticación
```bash
# Verificar pg_hba.conf generado por Patroni
docker exec -it pg-primary cat /data/patroni/pg_hba.conf

# Probar conexión de replicación
docker exec -it pg-primary psql \
  -h localhost -U replicator -c "SELECT 1;" replication
```

### Un replication slot está llenando el disco (`wal_status = lost` o crecimiento de `/data/patroni/pg_wal`)
```bash
# Identificar slots inactivos que están reteniendo WAL
docker exec -it pg-primary psql -U postgres -c "
SELECT slot_name, active, restart_lsn, wal_status
FROM pg_replication_slots
WHERE active = false;"

# Si el slot ya no corresponde a ningún backup o réplica en uso, eliminarlo
docker exec -it pg-primary psql -U postgres -c "
SELECT pg_drop_replication_slot('nombre_del_slot');"
```

### Loki no recibe logs
```bash
# Ver errores de Promtail
docker logs promtail-primary --tail 30

# Verificar conectividad de Promtail a Loki
docker exec -it promtail-primary \
  wget -q --spider http://loki:3100/ready && echo "OK"
```

---

## 📚 Referencias

- [Patroni — Documentación oficial](https://patroni.readthedocs.io/)
- [PostgreSQL WAL Archiving](https://www.postgresql.org/docs/current/continuous-archiving.html)
- [Grafana Loki — LogQL](https://grafana.com/docs/loki/latest/query/)
- [pg_basebackup — Referencia](https://www.postgresql.org/docs/current/app-pgbasebackup.html)
