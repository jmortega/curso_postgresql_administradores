# 🐘 pg_backup.py — Backup Lógico y Físico de PostgreSQL

> Script Python para automatizar backups de PostgreSQL usando `pg_dump` (lógico)
> y `pg_basebackup` (físico), con verificación de integridad, rotación automática
> y logging detallado.

---

## 📋 Índice

1. [Requisitos](#1-requisitos)
2. [Instalación](#2-instalación)
3. [Arquitectura interna](#3-arquitectura-interna)
4. [Modos de backup](#4-modos-de-backup)
   - [logical — pg_dump](#41-modo-logical--pg_dump)
   - [physical — pg_basebackup](#42-modo-physical--pg_basebackup)
   - [both — ambos en secuencia](#43-modo-both--ambos-en-secuencia)
5. [Referencia de argumentos](#5-referencia-de-argumentos)
6. [Variables de entorno](#6-variables-de-entorno)
7. [Ejemplos de ejecución](#7-ejemplos-de-ejecución)
8. [Estructura de directorios generada](#8-estructura-de-directorios-generada)
9. [Salida y logging](#9-salida-y-logging)
10. [Automatización con cron](#10-automatización-con-cron)
11. [Errores comunes](#11-errores-comunes)

---

## 1. Requisitos

| Componente | Versión mínima | Notas |
|---|---|---|
| Python | 3.8+ | Solo librería estándar, sin dependencias externas |
| `pg_dump` | 12+ | Incluido en `postgresql-client` |
| `pg_basebackup` | 12+ | Incluido en `postgresql-client` |
| `pg_restore` | 12+ | Solo para verificación del modo `custom` |

```bash
# Instalar cliente PostgreSQL en Ubuntu/Debian
sudo apt-get install postgresql-client

# Verificar que los binarios están disponibles
which pg_dump pg_basebackup pg_restore
```

---

## 2. Instalación

```bash
# Descargar o copiar el script
cp pg_backup.py /usr/local/bin/pg_backup.py
chmod +x /usr/local/bin/pg_backup.py

# Crear directorios de backup y log
sudo mkdir -p /backup/logical /backup/physical
sudo chown postgres:postgres /backup/logical /backup/physical

sudo mkdir -p /var/log
sudo touch /var/log/pg_backup.log
sudo chown postgres:postgres /var/log/pg_backup.log
```

> El script **no tiene dependencias externas** — usa únicamente la librería
> estándar de Python (`subprocess`, `hashlib`, `pathlib`, `argparse`, `logging`).

---

## 3. Arquitectura interna

El script se organiza en cinco componentes:

```
pg_backup.py
│
├── PgConfig          ← Parámetros de conexión (host, port, user, pass, db)
├── BackupConfig      ← Parámetros del backup (modo, dirs, compresión, etc.)
├── BackupResult      ← Resultado de cada operación (éxito, tamaño, checksum)
│
├── LogicalBackup     ← Encapsula pg_dump
│   ├── run()         ← Orquesta el proceso completo
│   └── _verify_dump()← Verifica integridad según el formato
│
├── PhysicalBackup    ← Encapsula pg_basebackup
│   ├── run()         ← Orquesta el proceso completo
│   └── _verify_base_backup() ← Verifica backup_label y pg_wal
│
└── BackupOrchestrator← Coordina LogicalBackup y/o PhysicalBackup
    ├── run()         ← Ejecuta según el modo elegido
    └── _print_summary() ← Imprime resumen final y sale con código 1 si hay fallos
```

### Flujo de ejecución general

```
parse_args()
     │
     ▼
BackupOrchestrator.run()
     │
     ├─ modo=logical  → LogicalBackup.run()
     ├─ modo=physical → PhysicalBackup.run()
     └─ modo=both     → LogicalBackup.run() → PhysicalBackup.run()
              │
              ▼ (para cada backup)
        1. _check_binary()    ← Verifica pg_dump / pg_basebackup en PATH
        2. Crea directorio destino
        3. Construye lista de argumentos del comando
        4. _run()             ← subprocess.run() con PGPASSWORD en el entorno
        5. Comprueba returncode != 0
        6. _verify_*()        ← Verifica integridad del resultado
        7. _sha256_*()        ← Calcula checksum SHA-256
        8. _write_checksum_file() ← Escribe .sha256 junto al backup
        9. _cleanup_old_backups() ← Elimina backups con mtime > retention_days
       10. BackupResult       ← Devuelve resultado con métricas
```

---

## 4. Modos de backup

### 4.1 Modo `logical` — `pg_dump`

**¿Qué hace?**

Genera un volcado lógico de la base de datos: extrae las definiciones SQL de
todos los objetos (tablas, índices, secuencias, funciones…) y sus datos en un
formato portable.

**Internamente:**

```
LogicalBackup.run()
│
├── Verifica pg_dump en PATH
├── Crea: /backup/logical/
├── Nombre del fichero: {dbname}_{YYYYMMDD_HHMMSS}.dump
│
├── Construye el comando pg_dump:
│     pg_dump
│       --host=<host>         → servidor PostgreSQL
│       --port=<port>
│       --username=<user>
│       --dbname=<db>
│       --format=custom       → formato comprimido y paralelizable
│       --compress=9          → compresión zlib nivel 9
│       --no-password         → usa PGPASSWORD del entorno
│       --verbose             → imprime objetos procesados
│       [--schema=<s>]        → si se especificaron schemas
│       [--table=<t>]         → si se especificaron tablas
│       --file=<dest>
│
├── subprocess.run() con PGPASSWORD en el entorno
├── Comprueba returncode == 0
│
├── _verify_dump():
│     custom    → pg_restore --list (lee cabecera, no restaura)
│     directory → comprueba que existe toc.dat
│     plain     → comprueba que el .sql no está vacío
│     tar       → comprueba que el .tar tiene tamaño > 0
│
├── sha256sum del fichero → escribe {nombre}.sha256
└── _cleanup_old_backups() → elimina .dump más antiguos que retention_days
```

**Formatos disponibles (`--logical-format`):**

| Formato | Extensión | Descripción | Restauración |
|---|---|---|---|
| `custom` *(defecto)* | `.dump` | Comprimido, paralelizable | `pg_restore -d db archivo.dump` |
| `plain` | `.sql` | SQL texto plano | `psql -d db -f archivo.sql` |
| `tar` | `.tar` | Tar comprimido | `pg_restore -d db archivo.tar` |
| `directory` | *(dir)* | Directorio con un fichero por tabla | `pg_restore -d db directorio/` |

**Cuándo usar backup lógico:**
- Migrar entre versiones de PostgreSQL.
- Restaurar objetos individuales (tablas, schemas).
- Copias de seguridad portables entre plataformas.
- No requiere rol de replicación.

---

### 4.2 Modo `physical` — `pg_basebackup`

**¿Qué hace?**

Copia los ficheros de datos físicos del clúster PostgreSQL mientras el
servidor está en marcha, usando el protocolo de replicación. Incluye los
segmentos WAL necesarios para obtener un backup consistente,
habilitando recuperación punto en el tiempo (PITR).

**Internamente:**

```
PhysicalBackup.run()
│
├── Verifica pg_basebackup en PATH
├── Crea: /backup/physical/{YYYYMMDD_HHMMSS}/
│
├── Construye el comando pg_basebackup:
│     pg_basebackup
│       --host=<host>
│       --port=<port>
│       --username=<user>      → debe tener rol REPLICATION
│       --pgdata=<dest>        → directorio destino
│       --wal-method=stream    → abre una segunda conexión de replicación
│                                para los WAL en paralelo al backup
│       --checkpoint=fast      → fuerza checkpoint inmediato (no espera)
│       --compress=9           → compresión del directorio resultante
│       --progress             → muestra % completado
│       --verbose              → imprime ficheros copiados
│       --no-password
│
├── subprocess.run() con PGPASSWORD en el entorno
├── Comprueba returncode == 0
│
├── _verify_base_backup():
│     ├── Comprueba que backup_label existe
│     ├── Parsea backup_label:
│     │     START WAL LOCATION → LSN desde donde aplicar WAL
│     │     START TIME         → timestamp de inicio del backup
│     │     BACKUP FROM        → primary | standby
│     └── Comprueba presencia de pg_wal/ o pg_wal.tar.gz
│
├── sha256 del directorio completo → escribe {timestamp}.sha256
└── _cleanup_old_backups() → elimina directorios más antiguos que retention_days
```

**Opciones de WAL (`--wal-method`):**

| Método | Descripción | Recomendado |
|---|---|---|
| `stream` *(defecto)* | Segunda conexión de replicación en paralelo; los WAL quedan embebidos | ✅ Producción |
| `fetch` | Copia los WAL del servidor al finalizar el backup de datos | Entornos simples |
| `none` | No incluye WAL; debe combinarse con WAL archiving externo | Avanzado |

**Cuándo usar backup físico:**
- Recuperación Point-in-Time (PITR).
- Configuración de réplicas nuevas.
- Backups muy grandes donde el rendimiento es crítico.
- Requiere rol de `REPLICATION` o superusuario.

---

### 4.3 Modo `both` — Ambos en secuencia

Ejecuta primero el backup lógico y después el físico. Si el lógico falla,
el físico **igualmente se intenta**. El proceso termina con código de
salida `1` solo si alguno de los dos falló.

```
both
 ├── LogicalBackup.run()   → /backup/logical/{db}_{ts}.dump
 └── PhysicalBackup.run()  → /backup/physical/{ts}/
```

---

## 5. Referencia de argumentos

```
python pg_backup.py [OPCIONES]
```

### Conexión

| Argumento | Defecto | Descripción |
|---|---|---|
| `--host` | `localhost` | Host del servidor PostgreSQL |
| `--port` | `5432` | Puerto |
| `--user` | `postgres` | Usuario de conexión |
| `--password` | *(vacío)* | Contraseña (o usar `PGPASSWORD`) |
| `--db` | `postgres` | Base de datos (solo para lógico) |

### Modo

| Argumento | Valores | Defecto | Descripción |
|---|---|---|---|
| `--mode` | `logical` `physical` `both` | `logical` | Tipo de backup |

### Almacenamiento

| Argumento | Defecto | Descripción |
|---|---|---|
| `--backup-dir` | `/backup` | Directorio raíz de backups |
| `--retention-days` | `7` | Días antes de rotar backups antiguos |
| `--compress` | `9` | Nivel de compresión zlib (0 = sin compresión, 9 = máxima) |

### Opciones lógico

| Argumento | Defecto | Descripción |
|---|---|---|
| `--logical-format` | `custom` | Formato pg_dump: `custom` `plain` `tar` `directory` |
| `--schemas` | *(todos)* | Lista de schemas a incluir (separados por espacios) |
| `--tables` | *(todas)* | Lista de tablas a incluir (separadas por espacios) |

### Opciones físico

| Argumento | Defecto | Descripción |
|---|---|---|
| `--wal-method` | `stream` | Método WAL: `stream` `fetch` `none` |
| `--checkpoint` | `fast` | Tipo de checkpoint: `fast` `spread` |

### Operación

| Argumento | Descripción |
|---|---|
| `--no-verify` | Omitir verificación de integridad tras el backup |
| `--dry-run` | Mostrar comandos sin ejecutar nada |
| `--log-file <ruta>` | Escribir log adicional en fichero |
| `--verbose` | Activar nivel de logging DEBUG |

---

## 6. Variables de entorno

Todos los argumentos de conexión pueden sustituirse por variables de entorno
estándar de PostgreSQL:

```bash
export PGHOST=192.168.1.10
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=mi_contraseña_segura
export PGDATABASE=produccion
```

Los argumentos de línea de comandos tienen **prioridad** sobre las variables
de entorno.

---

## 7. Ejemplos de ejecución

### Backup lógico básico (servidor local)

```bash
$ sudo python3 pg_backup.py --mode logical --password ecommerce_pass --user ecommerce_user
2026-06-21 22:39:12 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 22:39:12 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 22:39:12 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 22:39:12 [INFO    ] Modo        : logical
2026-06-21 22:39:12 [INFO    ] Directorio  : /backup
2026-06-21 22:39:12 [INFO    ] Retención   : 7 días
2026-06-21 22:39:12 [INFO    ] Verificación: sí
2026-06-21 22:39:12 [INFO    ] ── BACKUP LÓGICO ─────────────────────────────────
2026-06-21 22:39:12 [INFO    ] Host     : localhost:5432
2026-06-21 22:39:12 [INFO    ] Base     : postgres
2026-06-21 22:39:12 [INFO    ] Formato  : custom
2026-06-21 22:39:12 [INFO    ] Compresión: 9
2026-06-21 22:39:12 [INFO    ] Destino  : /backup/logical/postgres_20260621_223912.dump
2026-06-21 22:39:13 [INFO    ] Verificando integridad del dump…
2026-06-21 22:39:13 [INFO    ] Verificación OK: 15 objetos en el dump
2026-06-21 22:39:13 [INFO    ] Checksum SHA-256 escrito en: /backup/logical/postgres_20260621_223912.dump.sha256
2026-06-21 22:39:13 [INFO    ] Backup lógico completado en 0.2s
2026-06-21 22:39:13 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 22:39:13 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 22:39:13 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 22:39:13 [INFO    ]   Modo      : logical
  Estado    : ✓ OK
  Duración  : 0.2s
  Ruta      : /backup/logical/postgres_20260621_223912.dump
  Tamaño    : 1.1 KB
  SHA-256   : 6bea220d39b23f7a…
2026-06-21 22:39:13 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 22:39:13 [INFO    ] Resultado: 1 OK / 0 FAIL

```

**Qué hace:**
- Conecta a `localhost:5432` con el usuario `ecommerce_user`
- Ejecuta `pg_dump --format=custom --compress=9 --file=/backup/logical/postgres_20260621_223912.dump`
- Verifica el dump con `pg_restore --list`
- Escribe `/backup/logical/postgres_20260621_223912.dump.sha256`
- Elimina dumps anteriores a 7 días

---

### Backup lógico en formato SQL plano

```bash
$ python3 pg_backup.py \
  --mode logical \
  --db ecommercedb \
  --password ecommerce_pass \
  --user ecommerce_user \
  --logical-format plain \
  --backup-dir ./backups
2026-06-21 22:45:58 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 22:45:58 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 22:45:58 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 22:45:58 [INFO    ] Modo        : logical
2026-06-21 22:45:58 [INFO    ] Directorio  : backups
2026-06-21 22:45:58 [INFO    ] Retención   : 7 días
2026-06-21 22:45:58 [INFO    ] Verificación: sí
2026-06-21 22:45:58 [INFO    ] ── BACKUP LÓGICO ─────────────────────────────────
2026-06-21 22:45:58 [INFO    ] Host     : localhost:5432
2026-06-21 22:45:58 [INFO    ] Base     : ecommercedb
2026-06-21 22:45:58 [INFO    ] Formato  : plain
2026-06-21 22:45:58 [INFO    ] Compresión: 9
2026-06-21 22:45:58 [INFO    ] Destino  : backups/logical/ecommercedb_20260621_224558.sql
2026-06-21 22:45:58 [INFO    ] Verificando integridad del dump…
2026-06-21 22:45:58 [INFO    ] Verificación OK: fichero SQL de 17161 bytes
2026-06-21 22:45:58 [INFO    ] Checksum SHA-256 escrito en: backups/logical/ecommercedb_20260621_224558.sql.sha256
2026-06-21 22:45:58 [INFO    ] Backup lógico completado en 0.1s
2026-06-21 22:45:58 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 22:45:58 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 22:45:58 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 22:45:58 [INFO    ]   Modo      : logical
  Estado    : ✓ OK
  Duración  : 0.1s
  Ruta      : backups/logical/ecommercedb_20260621_224558.sql
  Tamaño    : 16.8 KB
  SHA-256   : b8ed5cdf3d6a60fb…
2026-06-21 22:45:58 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 22:45:58 [INFO    ] Resultado: 1 OK / 0 FAIL

```

**Genera:** `backups/logical/ecommercedb_20260621_224558.sql`

---

### Backup lógico de schemas y tablas específicos

```bash
$ python3 pg_backup.py \
  --mode logical \
  --db ecommercedb \
  --password ecommerce_pass \
  --user ecommerce_user \
  --schemas public \
  --tables customers \
  --logical-format plain \
  --backup-dir ./backups
2026-06-21 22:52:26 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 22:52:26 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 22:52:26 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 22:52:26 [INFO    ] Modo        : logical
2026-06-21 22:52:26 [INFO    ] Directorio  : backups
2026-06-21 22:52:26 [INFO    ] Retención   : 7 días
2026-06-21 22:52:26 [INFO    ] Verificación: sí
2026-06-21 22:52:26 [INFO    ] ── BACKUP LÓGICO ─────────────────────────────────
2026-06-21 22:52:26 [INFO    ] Host     : localhost:5432
2026-06-21 22:52:26 [INFO    ] Base     : ecommercedb
2026-06-21 22:52:26 [INFO    ] Formato  : plain
2026-06-21 22:52:26 [INFO    ] Compresión: 9
2026-06-21 22:52:26 [INFO    ] Destino  : backups/logical/ecommercedb_20260621_225226.sql
2026-06-21 22:52:27 [INFO    ] Verificando integridad del dump…
2026-06-21 22:52:27 [INFO    ] Verificación OK: fichero SQL de 4027 bytes
2026-06-21 22:52:27 [INFO    ] Checksum SHA-256 escrito en: backups/logical/ecommercedb_20260621_225226.sql.sha256
2026-06-21 22:52:27 [INFO    ] Backup lógico completado en 0.1s
2026-06-21 22:52:27 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 22:52:27 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 22:52:27 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 22:52:27 [INFO    ]   Modo      : logical
  Estado    : ✓ OK
  Duración  : 0.1s
  Ruta      : backups/logical/ecommercedb_20260621_225226.sql
  Tamaño    : 3.9 KB
  SHA-256   : 3827a5f80611582b…
2026-06-21 22:52:27 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 22:52:27 [INFO    ] Resultado: 1 OK / 0 FAIL

```

**Qué hace:**
- Solo incluye la tabla `customers` del schema `public`

---

### Backup físico (servidor local, usuario con rol REPLICATION)

```bash
$ python3 pg_backup.py   --mode physical   --db ecommercedb   --password ecommerce_pass   --user ecommerce_user   --backup-dir ./backups   --compress 0
2026-06-21 23:28:53 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:28:53 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 23:28:53 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:28:53 [INFO    ] Modo        : physical
2026-06-21 23:28:53 [INFO    ] Directorio  : backups
2026-06-21 23:28:53 [INFO    ] Retención   : 7 días
2026-06-21 23:28:53 [INFO    ] Verificación: sí
2026-06-21 23:28:53 [INFO    ] ── BACKUP FÍSICO ─────────────────────────────────
2026-06-21 23:28:53 [INFO    ] Host       : localhost:5432
2026-06-21 23:28:53 [INFO    ] Usuario    : ecommerce_user (debe tener rol REPLICATION)
2026-06-21 23:28:53 [INFO    ] WAL method : stream
2026-06-21 23:28:53 [INFO    ] Checkpoint : fast
2026-06-21 23:28:53 [INFO    ] Destino    : backups/physical/20260621_232853
2026-06-21 23:28:53 [INFO    ] Verificando integridad del backup físico…
2026-06-21 23:28:53 [INFO    ] backup_label — START WAL : 0/2000028 (file 000000010000000000000002)
2026-06-21 23:28:53 [INFO    ] backup_label — START TIME: 2026-06-21 21:28:53 UTC
2026-06-21 23:28:53 [INFO    ] backup_label — BACKUP FROM: primary
2026-06-21 23:28:53 [INFO    ] Verificación OK: backup_label y pg_wal presentes
2026-06-21 23:28:53 [INFO    ] Checksum SHA-256 escrito en: backups/physical/20260621_232853.sha256
2026-06-21 23:28:53 [INFO    ] Backup físico completado en 0.6s
2026-06-21 23:28:53 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:28:53 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 23:28:53 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:28:53 [INFO    ]   Modo      : physical
  Estado    : ✓ OK
  Duración  : 0.6s
  Ruta      : backups/physical/20260621_232853
  Tamaño    : 46.0 MB
  SHA-256   : 0a24b8a476d19ec9…
2026-06-21 23:28:53 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 23:28:53 [INFO    ] Resultado: 1 OK / 0 FAIL

```

**Qué hace:**
- Ejecuta `pg_basebackup --wal-method=stream --checkpoint=fast --compress=0`
- Verifica `backup_label` en el directorio resultante
- Calcula SHA-256 de todos los ficheros del directorio

---

### Backup físico con WAL fetch y Checkpoint spread

```bash
$ python3 pg_backup.py   --mode physical   --db ecommercedb   --password ecommerce_pass   --user ecommerce_user   --wal-method fetch --checkpoint spread --backup-dir ./backups   --compress 0
2026-06-21 23:43:08 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:43:08 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 23:43:08 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:43:08 [INFO    ] Modo        : physical
2026-06-21 23:43:08 [INFO    ] Directorio  : backups
2026-06-21 23:43:08 [INFO    ] Retención   : 7 días
2026-06-21 23:43:08 [INFO    ] Verificación: sí
2026-06-21 23:43:08 [INFO    ] ── BACKUP FÍSICO ─────────────────────────────────
2026-06-21 23:43:08 [INFO    ] Host       : localhost:5432
2026-06-21 23:43:08 [INFO    ] Usuario    : ecommerce_user (debe tener rol REPLICATION)
2026-06-21 23:43:08 [INFO    ] WAL method : fetch
2026-06-21 23:43:08 [INFO    ] Checkpoint : spread
2026-06-21 23:43:08 [INFO    ] Destino    : backups/physical/20260621_234308
2026-06-21 23:43:08 [INFO    ] Verificando integridad del backup físico…
2026-06-21 23:43:08 [INFO    ] backup_label — START WAL : 0/4000028 (file 000000010000000000000004)
2026-06-21 23:43:08 [INFO    ] backup_label — START TIME: 2026-06-21 21:43:08 UTC
2026-06-21 23:43:08 [INFO    ] backup_label — BACKUP FROM: primary
2026-06-21 23:43:08 [INFO    ] Verificación OK: backup_label y pg_wal presentes
2026-06-21 23:43:08 [INFO    ] Checksum SHA-256 escrito en: backups/physical/20260621_234308.sha256
2026-06-21 23:43:08 [INFO    ] Backup físico completado en 0.6s
2026-06-21 23:43:08 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:43:08 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 23:43:08 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:43:08 [INFO    ]   Modo      : physical
  Estado    : ✓ OK
  Duración  : 0.6s
  Ruta      : backups/physical/20260621_234308
  Tamaño    : 46.0 MB
  SHA-256   : 7dd1f82674e5b1df…
2026-06-21 23:43:08 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 23:43:08 [INFO    ] Resultado: 1 OK / 0 FAIL

```

---

### Backup completo (lógico + físico) contra servidor remoto

```bash
sudo python3 pg_backup.py \
  --mode both \
  --host localhost \
  --port 5432 \
  --user ecommerce_user \
  --password ecommerce_pass \
  --db ecommercedb \
  --backup-dir /backup/produccion \
  --retention-days 30 \
  --log-file /var/log/pg_backup.log

2026-06-21 23:51:10 [INFO    ] Log adicional en: /var/log/pg_backup.log
2026-06-21 23:51:10 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:51:10 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 23:51:10 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:51:10 [INFO    ] Modo        : both
2026-06-21 23:51:10 [INFO    ] Directorio  : /backup/produccion
2026-06-21 23:51:10 [INFO    ] Retención   : 30 días
2026-06-21 23:51:10 [INFO    ] Verificación: sí
2026-06-21 23:51:10 [INFO    ] ── BACKUP LÓGICO ─────────────────────────────────
2026-06-21 23:51:10 [INFO    ] Host     : localhost:5432
2026-06-21 23:51:10 [INFO    ] Base     : ecommercedb
2026-06-21 23:51:10 [INFO    ] Formato  : custom
2026-06-21 23:51:10 [INFO    ] Compresión: 9
2026-06-21 23:51:10 [INFO    ] Destino  : /backup/produccion/logical/ecommercedb_20260621_235110.dump
2026-06-21 23:51:10 [INFO    ] Verificando integridad del dump…
2026-06-21 23:51:10 [INFO    ] Verificación OK: 61 objetos en el dump
2026-06-21 23:51:10 [INFO    ] Checksum SHA-256 escrito en: /backup/produccion/logical/ecommercedb_20260621_235110.dump.sha256
2026-06-21 23:51:10 [INFO    ] Backup lógico completado en 0.2s
2026-06-21 23:51:10 [INFO    ] ── BACKUP FÍSICO ─────────────────────────────────
2026-06-21 23:51:10 [INFO    ] Host       : localhost:5432
2026-06-21 23:51:10 [INFO    ] Usuario    : ecommerce_user (debe tener rol REPLICATION)
2026-06-21 23:51:10 [INFO    ] WAL method : stream
2026-06-21 23:51:10 [INFO    ] Checkpoint : fast
2026-06-21 23:51:10 [INFO    ] Destino    : /backup/produccion/physical/20260621_235110
2026-06-21 23:51:10 [WARNING ] stderr: pg_basebackup: error: only tar mode backups can be compressed
2026-06-21 23:51:10 [WARNING ] stderr: pg_basebackup: hint: Try "pg_basebackup --help" for more information.
2026-06-21 23:51:10 [ERROR   ] Error en backup físico: pg_basebackup terminó con código 1:
pg_basebackup: error: only tar mode backups can be compressed
pg_basebackup: hint: Try "pg_basebackup --help" for more information.

2026-06-21 23:51:10 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:51:10 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 23:51:10 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:51:10 [INFO    ]   Modo      : logical
  Estado    : ✓ OK
  Duración  : 0.2s
  Ruta      : /backup/produccion/logical/ecommercedb_20260621_235110.dump
  Tamaño    : 16.9 KB
  SHA-256   : aafc37c53fd65ef9…
2026-06-21 23:51:10 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 23:51:10 [INFO    ]   Modo      : physical
  Estado    : ✗ FAIL
  Duración  : 0.0s
  Error     : pg_basebackup terminó con código 1:
pg_basebackup: error: only tar mode backups can be compressed
pg_basebackup: hint: Try "pg_basebackup --help" for more information.

2026-06-21 23:51:10 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 23:51:10 [INFO    ] Resultado: 1 OK / 1 FAIL

```

---

### Usando variables de entorno

```bash
export PGHOST=db.empresa.com
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=secreto
export PGDATABASE=produccion

python3 pg_backup.py --mode both --backup-dir /backup --retention-days 14
```

---

### Simulación sin ejecutar nada (dry-run)

```bash
$ sudo python3 pg_backup.py \
  --mode both \
  --host localhost \
  --db ecommercedb \
  --dry-run
2026-06-21 23:45:04 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:45:04 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 23:45:04 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:45:04 [INFO    ] Modo        : both
2026-06-21 23:45:04 [INFO    ] Directorio  : /backup
2026-06-21 23:45:04 [INFO    ] Retención   : 7 días
2026-06-21 23:45:04 [INFO    ] Verificación: sí
2026-06-21 23:45:04 [WARNING ] ⚠ DRY-RUN activado — no se realizará ningún backup real
2026-06-21 23:45:04 [INFO    ] ── BACKUP LÓGICO ─────────────────────────────────
2026-06-21 23:45:04 [INFO    ] Host     : localhost:5432
2026-06-21 23:45:04 [INFO    ] Base     : ecommercedb
2026-06-21 23:45:04 [INFO    ] Formato  : custom
2026-06-21 23:45:04 [INFO    ] Compresión: 9
2026-06-21 23:45:04 [INFO    ] Destino  : /backup/logical/ecommercedb_20260621_234504.dump
2026-06-21 23:45:04 [INFO    ] [DRY-RUN] /usr/bin/pg_dump --host=localhost --port=5432 --username=postgres --dbname=ecommercedb --format=custom --no-password --verbose --compress=9 --file=/backup/logical/ecommercedb_20260621_234504.dump
2026-06-21 23:45:04 [INFO    ] Backup lógico completado en 0.0s
2026-06-21 23:45:04 [INFO    ] ── BACKUP FÍSICO ─────────────────────────────────
2026-06-21 23:45:04 [INFO    ] Host       : localhost:5432
2026-06-21 23:45:04 [INFO    ] Usuario    : postgres (debe tener rol REPLICATION)
2026-06-21 23:45:04 [INFO    ] WAL method : stream
2026-06-21 23:45:04 [INFO    ] Checkpoint : fast
2026-06-21 23:45:04 [INFO    ] Destino    : /backup/physical/20260621_234504
2026-06-21 23:45:04 [INFO    ] [DRY-RUN] /usr/bin/pg_basebackup --host=localhost --port=5432 --username=postgres --pgdata=/backup/physical/20260621_234504 --wal-method=stream --checkpoint=fast --compress=9 --progress --verbose --no-password
2026-06-21 23:45:04 [INFO    ] Backup físico completado en 0.0s
2026-06-21 23:45:04 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:45:04 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 23:45:04 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:45:04 [INFO    ]   Modo      : logical
  Estado    : ✓ OK
  Duración  : 0.0s
  Ruta      : /backup/logical/ecommercedb_20260621_234504.dump
  Tamaño    : 0.0 B
2026-06-21 23:45:04 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 23:45:04 [INFO    ]   Modo      : physical
  Estado    : ✓ OK
  Duración  : 0.0s
  Ruta      : /backup/physical/20260621_234504
  Tamaño    : 0.0 B
2026-06-21 23:45:04 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 23:45:04 [INFO    ] Resultado: 2 OK / 0 FAIL

```

---

### Backup solo del schema `public`, sin compresión, con log verbose

```bash
$ sudo python3 pg_backup.py   --mode logical   --db ecommercedb   --password ecommerce_pass   --user ecommerce_user   --schemas public   --compress 0   --log-file /var/log/pg_backup_raw.log   --verbose
[sudo] contraseña para linux:      
2026-06-21 23:48:23 [INFO    ] Log adicional en: /var/log/pg_backup_raw.log
2026-06-21 23:48:23 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:48:23 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 23:48:23 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:48:23 [INFO    ] Modo        : logical
2026-06-21 23:48:23 [INFO    ] Directorio  : /backup
2026-06-21 23:48:23 [INFO    ] Retención   : 7 días
2026-06-21 23:48:23 [INFO    ] Verificación: sí
2026-06-21 23:48:23 [INFO    ] ── BACKUP LÓGICO ─────────────────────────────────
2026-06-21 23:48:23 [INFO    ] Host     : localhost:5432
2026-06-21 23:48:23 [INFO    ] Base     : ecommercedb
2026-06-21 23:48:23 [INFO    ] Formato  : custom
2026-06-21 23:48:23 [INFO    ] Compresión: 0
2026-06-21 23:48:23 [INFO    ] Destino  : /backup/logical/ecommercedb_20260621_234823.dump
2026-06-21 23:48:23 [DEBUG   ] Comando: /usr/bin/pg_dump --host=localhost --port=5432 --username=ecommerce_user --dbname=ecommercedb --format=custom --no-password --verbose --compress=0 --schema public --file=/backup/logical/ecommercedb_20260621_234823.dump
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: last built-in OID is 16383
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading extensions
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: identifying extension members
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading schemas
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined tables
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined functions
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined types
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading procedural languages
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined aggregate functions
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined operators
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined access methods
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined operator classes
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined operator families
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined text search parsers
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined text search templates
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined text search dictionaries
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined text search configurations
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined foreign-data wrappers
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined foreign servers
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading default privileges
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined collations
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading user-defined conversions
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading type casts
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading transforms
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading table inheritance information
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading event triggers
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: finding extension tables
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: finding inheritance relationships
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading column info for interesting tables
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: finding table default expressions
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: finding table check constraints
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: flagging inherited columns in subtables
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading partitioning data
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading indexes
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: flagging indexes in partitioned tables
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading extended statistics
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading constraints
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading triggers
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading rewrite rules
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading policies
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading row-level security policies
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading publications
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading publication membership of tables
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading publication membership of schemas
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading subscriptions
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: reading dependency data
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: saving encoding = UTF8
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: saving standard_conforming_strings = on
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: saving search_path = 
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: saving database definition
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: dumping contents of table "public.categories"
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: dumping contents of table "public.customers"
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: dumping contents of table "public.order_items"
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: dumping contents of table "public.orders"
2026-06-21 23:48:23 [DEBUG   ] stderr: pg_dump: dumping contents of table "public.products"
2026-06-21 23:48:23 [INFO    ] Verificando integridad del dump…
2026-06-21 23:48:23 [INFO    ] Verificación OK: 63 objetos en el dump
2026-06-21 23:48:23 [INFO    ] Checksum SHA-256 escrito en: /backup/logical/ecommercedb_20260621_234823.dump.sha256
2026-06-21 23:48:23 [INFO    ] Backup lógico completado en 0.1s
2026-06-21 23:48:23 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:48:23 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 23:48:23 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:48:23 [INFO    ]   Modo      : logical
  Estado    : ✓ OK
  Duración  : 0.1s
  Ruta      : /backup/logical/ecommercedb_20260621_234823.dump
  Tamaño    : 19.5 KB
  SHA-256   : d0f9fd7dd8adc31a…
2026-06-21 23:48:23 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 23:48:23 [INFO    ] Resultado: 1 OK / 0 FAIL

```

---

### Sin verificación de integridad

```bash
$ sudo python3 pg_backup.py   --mode logical   --db ecommercedb   --password ecommerce_pass   --user ecommerce_user   --no-verify
2026-06-21 23:49:14 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:49:14 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2026-06-21 23:49:14 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:49:14 [INFO    ] Modo        : logical
2026-06-21 23:49:14 [INFO    ] Directorio  : /backup
2026-06-21 23:49:14 [INFO    ] Retención   : 7 días
2026-06-21 23:49:14 [INFO    ] Verificación: no
2026-06-21 23:49:14 [INFO    ] ── BACKUP LÓGICO ─────────────────────────────────
2026-06-21 23:49:14 [INFO    ] Host     : localhost:5432
2026-06-21 23:49:14 [INFO    ] Base     : ecommercedb
2026-06-21 23:49:14 [INFO    ] Formato  : custom
2026-06-21 23:49:14 [INFO    ] Compresión: 9
2026-06-21 23:49:14 [INFO    ] Destino  : /backup/logical/ecommercedb_20260621_234914.dump
2026-06-21 23:49:14 [INFO    ] Checksum SHA-256 escrito en: /backup/logical/ecommercedb_20260621_234914.dump.sha256
2026-06-21 23:49:14 [INFO    ] Backup lógico completado en 0.1s
2026-06-21 23:49:14 [INFO    ] ╔══════════════════════════════════════════════════╗
2026-06-21 23:49:14 [INFO    ] ║                   RESUMEN                       ║
2026-06-21 23:49:14 [INFO    ] ╚══════════════════════════════════════════════════╝
2026-06-21 23:49:14 [INFO    ]   Modo      : logical
  Estado    : ✓ OK
  Duración  : 0.1s
  Ruta      : /backup/logical/ecommercedb_20260621_234914.dump
  Tamaño    : 16.9 KB
  SHA-256   : 5ddc1308343e3ccc…
2026-06-21 23:49:14 [INFO    ] ──────────────────────────────────────────────────
2026-06-21 23:49:14 [INFO    ] Resultado: 1 OK / 0 FAIL

```

---

## 8. Estructura de directorios generada

Tras ejecutar el script, el directorio de backups queda organizado así:

```
/backup/
├── logical/
│   ├── dwh_20250901_020000.dump       ← backup lógico (formato custom)
│   ├── dwh_20250901_020000.dump.sha256← checksum SHA-256
│   ├── dwh_20250902_020000.dump
│   └── dwh_20250902_020000.dump.sha256
│
└── physical/
    ├── 20250901_030000/               ← backup físico (directorio)
    │   ├── backup_label               ← metadatos del backup (LSN, timestamp)
    │   ├── pg_wal/                    ← segmentos WAL para consistencia
    │   ├── base/                      ← ficheros de datos del clúster
    │   └── 20250901_030000.sha256     ← checksum del directorio completo
    └── 20250902_030000/
```

### Fichero `backup_label` (backup físico)

```
START WAL LOCATION: 0/5000028 (file 000000010000000000000005)
CHECKPOINT LOCATION: 0/5000060
BACKUP METHOD: streamed
BACKUP FROM: primary
START TIME: 2025-09-01 03:00:05 UTC
LABEL: pg_basebackup base backup
START TIMELINE: 1
```

---

## 9. Salida y logging

### Formato de log

```
YYYY-MM-DD HH:MM:SS [NIVEL   ] Mensaje
```

### Ejemplo de ejecución exitosa (modo `both`)

```
2025-09-01 02:00:00 [INFO    ] ╔══════════════════════════════════════════════════╗
2025-09-01 02:00:00 [INFO    ] ║          PostgreSQL Backup Tool                  ║
2025-09-01 02:00:00 [INFO    ] ╚══════════════════════════════════════════════════╝
2025-09-01 02:00:00 [INFO    ] Modo        : both
2025-09-01 02:00:00 [INFO    ] Directorio  : /backup
2025-09-01 02:00:00 [INFO    ] Retención   : 7 días
2025-09-01 02:00:00 [INFO    ] ── BACKUP LÓGICO ─────────────────────────────────
2025-09-01 02:00:00 [INFO    ] Host     : localhost:5432
2025-09-01 02:00:00 [INFO    ] Base     : dwh
2025-09-01 02:00:00 [INFO    ] Formato  : custom
2025-09-01 02:00:00 [INFO    ] Destino  : /backup/logical/dwh_20250901_020000.dump
2025-09-01 02:00:05 [INFO    ] Verificando integridad del dump…
2025-09-01 02:00:05 [INFO    ] Verificación OK: 142 objetos en el dump
2025-09-01 02:00:05 [INFO    ] Checksum SHA-256 escrito en: dwh_20250901_020000.dump.sha256
2025-09-01 02:00:05 [INFO    ] Rotación : 1 backup(s) antiguo(s) eliminados
2025-09-01 02:00:05 [INFO    ] Backup lógico completado en 5.2s
2025-09-01 02:00:05 [INFO    ] ── BACKUP FÍSICO ─────────────────────────────────
2025-09-01 02:00:05 [INFO    ] Host       : localhost:5432
2025-09-01 02:00:05 [INFO    ] WAL method : stream
2025-09-01 02:00:05 [INFO    ] Destino    : /backup/physical/20250901_020005
2025-09-01 02:01:20 [INFO    ] Verificando integridad del backup físico…
2025-09-01 02:01:20 [INFO    ] backup_label — START WAL : 0/5000028
2025-09-01 02:01:20 [INFO    ] backup_label — START TIME: 2025-09-01 02:00:05 UTC
2025-09-01 02:01:20 [INFO    ] Verificación OK: backup_label y pg_wal presentes
2025-09-01 02:01:20 [INFO    ] Checksum SHA-256 escrito en: 20250901_020005.sha256
2025-09-01 02:01:20 [INFO    ] Backup físico completado en 75.3s
2025-09-01 02:01:20 [INFO    ] ╔══════════════════════════════════════════════════╗
2025-09-01 02:01:20 [INFO    ] ║                   RESUMEN                       ║
2025-09-01 02:01:20 [INFO    ] ╚══════════════════════════════════════════════════╝
2025-09-01 02:01:20 [INFO    ]   Modo      : logical
2025-09-01 02:01:20 [INFO    ]   Estado    : ✓ OK
2025-09-01 02:01:20 [INFO    ]   Duración  : 5.2s
2025-09-01 02:01:20 [INFO    ]   Ruta      : /backup/logical/dwh_20250901_020000.dump
2025-09-01 02:01:20 [INFO    ]   Tamaño    : 48.3 MB
2025-09-01 02:01:20 [INFO    ]   SHA-256   : a3f9c1e2b4d7…
2025-09-01 02:01:20 [INFO    ]   Modo      : physical
2025-09-01 02:01:20 [INFO    ]   Estado    : ✓ OK
2025-09-01 02:01:20 [INFO    ]   Duración  : 75.3s
2025-09-01 02:01:20 [INFO    ]   Ruta      : /backup/physical/20250901_020005
2025-09-01 02:01:20 [INFO    ]   Tamaño    : 1.2 GB
2025-09-01 02:01:20 [INFO    ]   SHA-256   : f7b2d8a1c0e5…
2025-09-01 02:01:20 [INFO    ] Resultado: 2 OK / 0 FAIL
```

### Códigos de salida

| Código | Significado |
|---|---|
| `0` | Todos los backups completados correctamente |
| `1` | Uno o más backups fallaron |

---

## 10. Automatización con cron

### Crontab del sistema (`/etc/cron.d/pg_backup`)

```bash
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
PGPASSWORD=mi_contraseña

# Backup lógico diario a las 02:00
0 2 * * *  postgres  python3 /usr/local/bin/pg_backup.py \
    --mode logical --db dwh --backup-dir /backup \
    --retention-days 30 --log-file /var/log/pg_backup.log

# Backup físico diario a las 03:00
0 3 * * *  postgres  python3 /usr/local/bin/pg_backup.py \
    --mode physical --user replicator \
    --backup-dir /backup --retention-days 7 \
    --log-file /var/log/pg_backup.log

# Ambos el primer día del mes
0 1 1 * *  postgres  python3 /usr/local/bin/pg_backup.py \
    --mode both --db dwh --user replicator \
    --backup-dir /backup/mensual --retention-days 90 \
    --log-file /var/log/pg_backup_mensual.log
```

### Desde pg_cron (dentro de PostgreSQL)

```sql
-- Requiere que pg_cron pueda ejecutar comandos shell
-- Se recomienda usar pg_cron para llamar a un wrapper de shell
SELECT cron.schedule(
    'backup-logico-diario',
    '0 2 * * *',
    $$COPY (SELECT 1) TO PROGRAM
      'python3 /usr/local/bin/pg_backup.py --mode logical --db dwh'$$
);
```

---

## 11. Errores comunes

### `pg_dump` o `pg_basebackup` no encontrado

```
FileNotFoundError: 'pg_dump' no encontrado en PATH.
```

```bash
# Solución: instalar cliente PostgreSQL
sudo apt-get install postgresql-client-16

# O añadir al PATH si está instalado en una ruta no estándar
export PATH=$PATH:/usr/lib/postgresql/16/bin
```

---

### Error de autenticación

```
pg_dump: error: connection to server at "localhost" failed: FATAL: password authentication failed
```

```bash
# Opción 1: pasar contraseña por argumento
python pg_backup.py --mode logical --password mi_pass

# Opción 2: variable de entorno
export PGPASSWORD=mi_pass && python pg_backup.py --mode logical

# Opción 3: fichero .pgpass en el home del usuario
echo "localhost:5432:dwh:postgres:mi_pass" >> ~/.pgpass
chmod 600 ~/.pgpass
```

---

### `pg_basebackup` falla por permisos de replicación

```
pg_basebackup: error: FATAL: must be superuser or replication role to start walsender
```

```sql
-- Solución: crear rol con permiso de replicación
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'repl_pass';

-- Y añadir en pg_hba.conf:
-- host  replication  replicator  127.0.0.1/32  md5
```

---

### Verificación fallida: `backup_label` no encontrado

```
RuntimeError: Verificación fallida: 'backup_label' no encontrado
```

El backup puede haberse interrumpido antes de completarse. Revisar espacio en
disco y logs de PostgreSQL. Usar `--no-verify` para omitir la verificación
si se sabe que el backup es válido.

---

### Error de permisos en el directorio de backup

```
PermissionError: [Errno 13] Permission denied: '/backup/logical'
```

```bash
# Solución: asignar el directorio al usuario que ejecuta el script
sudo chown -R postgres:postgres /backup
sudo chmod -R 750 /backup
```

---

## 📚 Referencias

- [`pg_dump` — Documentación oficial](https://www.postgresql.org/docs/current/app-pgdump.html)
- [`pg_basebackup` — Documentación oficial](https://www.postgresql.org/docs/current/app-pgbasebackup.html)
- [`pg_restore` — Documentación oficial](https://www.postgresql.org/docs/current/app-pgrestore.html)
- [Continuous Archiving and PITR](https://www.postgresql.org/docs/current/continuous-archiving.html)
