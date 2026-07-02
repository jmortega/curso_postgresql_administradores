"""
=============================================================
  PostgreSQL Application Logs Manager
  Script interactivo para gestión de logs de aplicaciones
=============================================================
"""

import sys
import os
import random
from datetime import datetime, timedelta

try:
    import psycopg2
    from psycopg2 import sql, OperationalError, errors
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("\n[ERROR] psycopg2 no está instalado.")
    print("Ejecuta: pip install psycopg2-binary")
    sys.exit(1)

# ── Colores ANSI ──────────────────────────────────────────
RED    = "\033[91m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

# ── Configuración de conexión ─────────────────────────────
DB_CONFIG = {
    "host":     os.environ.get("PG_HOST",     "localhost"),
    "port":     int(os.environ.get("PG_PORT", "5432")),
    "user":     os.environ.get("PG_USER",     "postgres"),
    "password": os.environ.get("PG_PASSWORD", "postgres_lab"),
    "dbname":   os.environ.get("PG_DBNAME",   "postgres"),
}

TARGET_DB   = "app_logs_db"  # Nombre de la base de datos a crear
TARGET_TABLE = "application_logs"

# ── Datos de muestra para generar logs ───────────────────
APPLICATIONS = [
    "api-gateway", "auth-service", "payment-service",
    "user-service", "notification-service", "inventory-service",
    "reporting-service", "file-upload-service"
]

ENVIRONMENTS = ["production", "staging", "development", "testing"]

LOG_LEVELS = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
LOG_LEVEL_WEIGHTS = [10, 50, 20, 15, 5]   # probabilidades relativas

SERVERS = [
    "srv-web-01", "srv-web-02", "srv-api-01",
    "srv-api-02", "srv-db-01", "srv-worker-01"
]

MESSAGES = {
    "DEBUG":    [
        "Variable checkout_id = {val}",
        "Cache hit ratio: {val}%",
        "Query executed in {val}ms",
        "Session token refreshed for user_{val}",
        "Worker thread {val} started",
    ],
    "INFO": [
        "User user_{val} logged in successfully",
        "Order #{val} processed successfully",
        "Email sent to user_{val}@example.com",
        "File upload completed: file_{val}.pdf",
        "Scheduled job completed in {val}s",
        "API request processed: GET /api/v1/resource/{val}",
        "Payment of ${val} confirmed for order #{val}",
    ],
    "WARNING": [
        "High memory usage detected: {val}%",
        "Slow query detected: {val}ms (threshold: 500ms)",
        "Rate limit approaching for client_{val}",
        "Retry attempt {val}/3 for external API call",
        "Disk usage at {val}% on /var/data",
        "Deprecated endpoint called by client_{val}",
    ],
    "ERROR": [
        "Database connection failed: timeout after {val}ms",
        "Payment gateway error: transaction_{val} declined",
        "File not found: /uploads/report_{val}.csv",
        "Authentication failed for user_{val}: invalid token",
        "External API returned 503 after {val} retries",
        "Queue overflow: {val} messages dropped",
    ],
    "CRITICAL": [
        "Service unavailable: {app} down for {val}s",
        "Data corruption detected in table orders_{val}",
        "Security breach attempt from IP 192.168.{val}.1",
        "Out of memory: process killed (PID {val})",
        "SSL certificate expired {val} days ago",
    ],
}

HTTP_METHODS  = ["GET", "POST", "PUT", "DELETE", "PATCH"]
HTTP_STATUSES = [200, 201, 204, 301, 400, 401, 403, 404, 429, 500, 502, 503]
ENDPOINTS     = [
    "/api/v1/users", "/api/v1/orders", "/api/v1/payments",
    "/api/v1/products", "/api/v1/auth/login", "/api/v1/auth/logout",
    "/api/v1/reports", "/api/v1/files", "/health", "/metrics"
]

STACK_TRACES = [
    None, None, None,   # La mayoría sin stack trace
    "Traceback (most recent call last):\n  File 'app.py', line 142\n  raise ConnectionError('DB timeout')",
    "Traceback (most recent call last):\n  File 'payment.py', line 89\n  raise PaymentError('Gateway refused')",
    "java.lang.NullPointerException\n\tat com.service.UserService.getUser(UserService.java:234)",
    "Error: ENOENT: no such file or directory, open '/data/config.json'",
]


# ══════════════════════════════════════════════════════════
# HELPERS DE CONEXIÓN
# ══════════════════════════════════════════════════════════

def get_connection(dbname=None):
    """Devuelve una conexión psycopg2."""
    cfg = {**DB_CONFIG}
    if dbname:
        cfg["dbname"] = dbname
    return psycopg2.connect(**cfg)


def print_separator(char="─", color=CYAN):
    print(f"{color}{char * 64}{RESET}")


def wait():
    input(f"\n{YELLOW}[↵ Pulsa Enter para continuar...]{RESET}\n")


def print_error(msg):
    print(f"\n{RED}✗  {msg}{RESET}")


def print_success(msg):
    print(f"\n{GREEN}✔  {msg}{RESET}")


def print_info(msg):
    print(f"\n{CYAN}ℹ  {msg}{RESET}")


# ══════════════════════════════════════════════════════════
# GENERADOR DE DATOS DE MUESTRA
# ══════════════════════════════════════════════════════════

def generate_log_entry():
    """Genera un registro de log aleatorio y realista."""
    level = random.choices(LOG_LEVELS, weights=LOG_LEVEL_WEIGHTS, k=1)[0]
    app   = random.choice(APPLICATIONS)
    msg_template = random.choice(MESSAGES[level])
    val  = random.randint(1, 9999)
    message = msg_template.format(val=val, app=app)

    # Timestamp aleatorio en los últimos 30 días
    days_ago  = random.randint(0, 30)
    hours_ago = random.randint(0, 23)
    mins_ago  = random.randint(0, 59)
    ts = datetime.now() - timedelta(days=days_ago, hours=hours_ago, minutes=mins_ago)

    return {
        "timestamp":       ts,
        "log_level":       level,
        "application":     app,
        "environment":     random.choice(ENVIRONMENTS),
        "server":          random.choice(SERVERS),
        "message":         message,
        "http_method":     random.choice(HTTP_METHODS + [None, None]),
        "http_status":     random.choice(HTTP_STATUSES + [None, None]),
        "endpoint":        random.choice(ENDPOINTS + [None, None]),
        "response_time_ms": random.randint(5, 8000) if random.random() > 0.2 else None,
        "user_id":         f"user_{random.randint(1000, 9999)}" if random.random() > 0.3 else None,
        "session_id":      f"sess_{random.randint(100000, 999999)}" if random.random() > 0.4 else None,
        "ip_address":      f"{random.randint(1,254)}.{random.randint(1,254)}.{random.randint(1,254)}.{random.randint(1,254)}",
        "stack_trace":     random.choice(STACK_TRACES),
        "additional_data": f'{{"request_id": "req_{random.randint(10000,99999)}", "version": "1.{random.randint(0,9)}.{random.randint(0,9)}"}}'
    }


# ══════════════════════════════════════════════════════════
# OPCIÓN 1 — CREAR BASE DE DATOS Y TABLA
# ══════════════════════════════════════════════════════════

def create_database():
    print_separator()
    print(f"{BOLD}1. Crear base de datos y tabla de logs{RESET}\n")

    # ── Crear la base de datos ────────────────────────────
    try:
        conn = get_connection()
        conn.autocommit = True
        cur = conn.cursor()

        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (TARGET_DB,))
        exists = cur.fetchone()

        if exists:
            print_info(f"La base de datos '{TARGET_DB}' ya existe.")
        else:
            cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(TARGET_DB)))
            print_success(f"Base de datos '{TARGET_DB}' creada correctamente.")

        cur.close()
        conn.close()

    except OperationalError as e:
        print_error(f"No se pudo conectar a PostgreSQL: {e}")
        wait()
        return

    # ── Crear la tabla ────────────────────────────────────
    try:
        conn = get_connection(dbname=TARGET_DB)
        conn.autocommit = True
        cur = conn.cursor()

        create_table_sql = f"""
        CREATE TABLE IF NOT EXISTS {TARGET_TABLE} (
            id               SERIAL PRIMARY KEY,
            timestamp        TIMESTAMP NOT NULL DEFAULT NOW(),
            log_level        VARCHAR(10) NOT NULL
                             CHECK (log_level IN ('DEBUG','INFO','WARNING','ERROR','CRITICAL')),
            application      VARCHAR(100) NOT NULL,
            environment      VARCHAR(50) NOT NULL
                             CHECK (environment IN ('production','staging','development','testing')),
            server           VARCHAR(100),
            message          TEXT NOT NULL,
            http_method      VARCHAR(10),
            http_status      INTEGER,
            endpoint         VARCHAR(255),
            response_time_ms INTEGER,
            user_id          VARCHAR(50),
            session_id       VARCHAR(100),
            ip_address       VARCHAR(45),
            stack_trace      TEXT,
            additional_data  JSONB,
            created_at       TIMESTAMP DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS idx_logs_timestamp
            ON {TARGET_TABLE}(timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_logs_level
            ON {TARGET_TABLE}(log_level);
        CREATE INDEX IF NOT EXISTS idx_logs_application
            ON {TARGET_TABLE}(application);
        CREATE INDEX IF NOT EXISTS idx_logs_environment
            ON {TARGET_TABLE}(environment);
        """

        cur.execute(create_table_sql)
        print_success(f"Tabla '{TARGET_TABLE}' creada con índices correctamente.")

        # ── Insertar datos de muestra ─────────────────────
        print_info("Insertando datos de muestra (500 registros)...")

        entries = [generate_log_entry() for _ in range(500)]
        insert_sql = f"""
        INSERT INTO {TARGET_TABLE}
            (timestamp, log_level, application, environment, server,
             message, http_method, http_status, endpoint,
             response_time_ms, user_id, session_id, ip_address,
             stack_trace, additional_data)
        VALUES
            (%(timestamp)s, %(log_level)s, %(application)s, %(environment)s, %(server)s,
             %(message)s, %(http_method)s, %(http_status)s, %(endpoint)s,
             %(response_time_ms)s, %(user_id)s, %(session_id)s, %(ip_address)s,
             %(stack_trace)s, %(additional_data)s)
        """
        cur.executemany(insert_sql, entries)
        print_success("500 registros de logs insertados correctamente.")

        # ── Mostrar resumen ───────────────────────────────
        cur.execute(f"""
            SELECT log_level, COUNT(*) as total
            FROM {TARGET_TABLE}
            GROUP BY log_level
            ORDER BY total DESC
        """)
        rows = cur.fetchall()
        print(f"\n{BOLD}Resumen de logs insertados:{RESET}")
        print_separator("─")
        print(f"  {'Nivel':<12} {'Total':>8}")
        print_separator("─")
        for row in rows:
            level, count = row
            color = RED if level in ("ERROR", "CRITICAL") else \
                    YELLOW if level == "WARNING" else \
                    CYAN if level == "INFO" else RESET
            print(f"  {color}{level:<12}{RESET} {count:>8}")
        print_separator("─")

        cur.close()
        conn.close()

    except Exception as e:
        print_error(f"Error al crear la tabla o insertar datos: {e}")

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 2 — INSERTAR REGISTRO
# ══════════════════════════════════════════════════════════

def insert_log():
    print_separator()
    print(f"{BOLD}2. Insertar nuevo registro de log{RESET}\n")

    print(f"{YELLOW}Opciones de inserción:{RESET}")
    print(f"  {YELLOW}[1]{RESET}  Insertar manualmente")
    print(f"  {YELLOW}[2]{RESET}  Insertar N registros aleatorios")
    choice = input(f"\n{BOLD}Elige una opción: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor()

        if choice == "1":
            # ── Inserción manual ──────────────────────────
            print(f"\n{CYAN}Introduce los datos del log:{RESET}")

            print(f"Nivel ({'/'.join(LOG_LEVELS)}): ", end="")
            level = input().strip().upper()
            if level not in LOG_LEVELS:
                print_error(f"Nivel inválido. Usa uno de: {', '.join(LOG_LEVELS)}")
                wait()
                return

            print(f"Aplicación (ejemplo: api-gateway): ", end="")
            application = input().strip() or "api-gateway"

            print(f"Entorno ({'/'.join(ENVIRONMENTS)}): ", end="")
            environment = input().strip().lower()
            if environment not in ENVIRONMENTS:
                environment = "development"

            print(f"Servidor (ejemplo: srv-web-01): ", end="")
            server = input().strip() or random.choice(SERVERS)

            print(f"Mensaje del log: ", end="")
            message = input().strip() or "Log manual de prueba"

            entry = {
                "timestamp":        datetime.now(),
                "log_level":        level,
                "application":      application,
                "environment":      environment,
                "server":           server,
                "message":          message,
                "http_method":      None,
                "http_status":      None,
                "endpoint":         None,
                "response_time_ms": None,
                "user_id":          None,
                "session_id":       None,
                "ip_address":       "127.0.0.1",
                "stack_trace":      None,
                "additional_data":  '{"source": "manual_entry"}'
            }

        elif choice == "2":
            # ── Inserción masiva aleatoria ────────────────
            n_str = input(f"¿Cuántos registros insertar? [10]: ").strip()
            n = int(n_str) if n_str.isdigit() and int(n_str) > 0 else 10
            entries = [generate_log_entry() for _ in range(n)]

            insert_sql = f"""
            INSERT INTO {TARGET_TABLE}
                (timestamp, log_level, application, environment, server,
                 message, http_method, http_status, endpoint,
                 response_time_ms, user_id, session_id, ip_address,
                 stack_trace, additional_data)
            VALUES
                (%(timestamp)s, %(log_level)s, %(application)s, %(environment)s, %(server)s,
                 %(message)s, %(http_method)s, %(http_status)s, %(endpoint)s,
                 %(response_time_ms)s, %(user_id)s, %(session_id)s, %(ip_address)s,
                 %(stack_trace)s, %(additional_data)s)
            """
            cur.executemany(insert_sql, entries)
            conn.commit()
            print_success(f"{n} registros aleatorios insertados correctamente.")
            cur.close()
            conn.close()
            wait()
            return
        else:
            print_error("Opción no válida.")
            wait()
            return

        # Inserción del registro manual
        insert_sql = f"""
        INSERT INTO {TARGET_TABLE}
            (timestamp, log_level, application, environment, server,
             message, http_method, http_status, endpoint,
             response_time_ms, user_id, session_id, ip_address,
             stack_trace, additional_data)
        VALUES
            (%(timestamp)s, %(log_level)s, %(application)s, %(environment)s, %(server)s,
             %(message)s, %(http_method)s, %(http_status)s, %(endpoint)s,
             %(response_time_ms)s, %(user_id)s, %(session_id)s, %(ip_address)s,
             %(stack_trace)s, %(additional_data)s)
        RETURNING id
        """
        cur.execute(insert_sql, entry)
        new_id = cur.fetchone()[0]
        conn.commit()
        print_success(f"Registro insertado correctamente con ID = {new_id}.")

        cur.close()
        conn.close()

    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'. ¿Creaste la base de datos (opción 1)?")
    except Exception as e:
        print_error(f"Error al insertar: {e}")

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 3 — CONSULTAR / LISTAR REGISTROS
# ══════════════════════════════════════════════════════════

def list_logs():
    print_separator()
    print(f"{BOLD}3. Consultar registros de logs{RESET}\n")

    print(f"{YELLOW}Filtros disponibles:{RESET}")
    print(f"  {YELLOW}[1]{RESET}  Últimos N registros")
    print(f"  {YELLOW}[2]{RESET}  Filtrar por nivel de log")
    print(f"  {YELLOW}[3]{RESET}  Filtrar por aplicación")
    print(f"  {YELLOW}[4]{RESET}  Filtrar por entorno")
    print(f"  {YELLOW}[5]{RESET}  Buscar por ID")
    print(f"  {YELLOW}[6]{RESET}  Estadísticas generales")
    choice = input(f"\n{BOLD}Elige una opción: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            n_str = input("¿Cuántos registros mostrar? [20]: ").strip()
            n = int(n_str) if n_str.isdigit() and int(n_str) > 0 else 20
            cur.execute(f"""
                SELECT id, timestamp, log_level, application, environment, server, message
                FROM {TARGET_TABLE}
                ORDER BY timestamp DESC
                LIMIT %s
            """, (n,))

        elif choice == "2":
            print(f"Niveles disponibles: {', '.join(LOG_LEVELS)}")
            level = input("Nivel: ").strip().upper()
            cur.execute(f"""
                SELECT id, timestamp, log_level, application, environment, server, message
                FROM {TARGET_TABLE}
                WHERE log_level = %s
                ORDER BY timestamp DESC
                LIMIT 50
            """, (level,))

        elif choice == "3":
            print(f"Aplicaciones: {', '.join(APPLICATIONS)}")
            app = input("Aplicación: ").strip()
            cur.execute(f"""
                SELECT id, timestamp, log_level, application, environment, server, message
                FROM {TARGET_TABLE}
                WHERE application ILIKE %s
                ORDER BY timestamp DESC
                LIMIT 50
            """, (f"%{app}%",))

        elif choice == "4":
            print(f"Entornos: {', '.join(ENVIRONMENTS)}")
            env = input("Entorno: ").strip().lower()
            cur.execute(f"""
                SELECT id, timestamp, log_level, application, environment, server, message
                FROM {TARGET_TABLE}
                WHERE environment = %s
                ORDER BY timestamp DESC
                LIMIT 50
            """, (env,))

        elif choice == "5":
            log_id = input("ID del registro: ").strip()
            cur.execute(f"""
                SELECT * FROM {TARGET_TABLE} WHERE id = %s
            """, (log_id,))
            row = cur.fetchone()
            if row:
                print(f"\n{BOLD}Detalle del registro ID {log_id}:{RESET}")
                print_separator("─")
                for key, val in row.items():
                    if val is not None:
                        print(f"  {CYAN}{key:<20}{RESET} {val}")
            else:
                print_info(f"No se encontró ningún registro con ID = {log_id}.")
            cur.close()
            conn.close()
            wait()
            return

        elif choice == "6":
            # Estadísticas generales
            cur.execute(f"SELECT COUNT(*) as total FROM {TARGET_TABLE}")
            total = cur.fetchone()["total"]

            cur.execute(f"""
                SELECT log_level, COUNT(*) as total
                FROM {TARGET_TABLE}
                GROUP BY log_level ORDER BY total DESC
            """)
            by_level = cur.fetchall()

            cur.execute(f"""
                SELECT application, COUNT(*) as total
                FROM {TARGET_TABLE}
                GROUP BY application ORDER BY total DESC LIMIT 5
            """)
            by_app = cur.fetchall()

            cur.execute(f"""
                SELECT environment, COUNT(*) as total
                FROM {TARGET_TABLE}
                GROUP BY environment ORDER BY total DESC
            """)
            by_env = cur.fetchall()

            cur.execute(f"""
                SELECT ROUND(AVG(response_time_ms),1) as avg_ms,
                       MIN(response_time_ms) as min_ms,
                       MAX(response_time_ms) as max_ms
                FROM {TARGET_TABLE}
                WHERE response_time_ms IS NOT NULL
            """)
            timing = cur.fetchone()

            print(f"\n{BOLD}{'═'*50}{RESET}")
            print(f"{BOLD}  ESTADÍSTICAS GENERALES — {TARGET_DB}{RESET}")
            print(f"{BOLD}{'═'*50}{RESET}")
            print(f"\n  Total de registros: {BOLD}{total}{RESET}")

            print(f"\n  {BOLD}Por nivel:{RESET}")
            for r in by_level:
                bar = "█" * min(int(r["total"] / max(total, 1) * 30), 30)
                color = RED if r["log_level"] in ("ERROR","CRITICAL") else \
                        YELLOW if r["log_level"] == "WARNING" else CYAN
                print(f"  {color}{r['log_level']:<12}{RESET} {bar} {r['total']}")

            print(f"\n  {BOLD}Top 5 aplicaciones:{RESET}")
            for r in by_app:
                print(f"  {CYAN}{r['application']:<30}{RESET} {r['total']}")

            print(f"\n  {BOLD}Por entorno:{RESET}")
            for r in by_env:
                print(f"  {r['environment']:<20} {r['total']}")

            print(f"\n  {BOLD}Tiempos de respuesta (ms):{RESET}")
            print(f"  Promedio: {timing['avg_ms']}  |  Mín: {timing['min_ms']}  |  Máx: {timing['max_ms']}")
            print_separator()

            cur.close()
            conn.close()
            wait()
            return
        else:
            print_error("Opción no válida.")
            cur.close()
            conn.close()
            wait()
            return

        rows = cur.fetchall()
        if not rows:
            print_info("No se encontraron registros con ese filtro.")
        else:
            print(f"\n{BOLD}{'ID':<6} {'Timestamp':<22} {'Nivel':<10} {'Aplicación':<22} {'Mensaje':<40}{RESET}")
            print_separator("─")
            for row in rows:
                level = row["log_level"]
                color = RED    if level in ("ERROR", "CRITICAL") else \
                        YELLOW if level == "WARNING" else \
                        CYAN   if level == "INFO"    else RESET
                msg = str(row["message"])[:40]
                ts  = str(row["timestamp"])[:19]
                print(f"  {row['id']:<4} {ts:<22} {color}{level:<10}{RESET} "
                      f"{str(row['application']):<22} {msg}")
            print_separator("─")
            print(f"  Total mostrado: {BOLD}{len(rows)}{RESET} registros.")

        cur.close()
        conn.close()

    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'. ¿Creaste la base de datos (opción 1)?")
    except Exception as e:
        print_error(f"Error al consultar: {e}")

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 4 — ACTUALIZAR REGISTRO
# ══════════════════════════════════════════════════════════

def update_log():
    print_separator()
    print(f"{BOLD}4. Actualizar registro de log{RESET}\n")

    log_id = input(f"{YELLOW}Introduce el ID del registro a actualizar: {RESET}").strip()
    if not log_id.isdigit():
        print_error("El ID debe ser un número entero.")
        wait()
        return

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        # Mostrar el registro actual
        cur.execute(f"SELECT * FROM {TARGET_TABLE} WHERE id = %s", (log_id,))
        row = cur.fetchone()

        if not row:
            print_info(f"No se encontró ningún registro con ID = {log_id}.")
            cur.close()
            conn.close()
            wait()
            return

        print(f"\n{BOLD}Registro actual:{RESET}")
        print_separator("─")
        for key in ["id", "timestamp", "log_level", "application",
                    "environment", "server", "message", "http_status"]:
            print(f"  {CYAN}{key:<20}{RESET} {row[key]}")
        print_separator("─")

        print(f"\n{YELLOW}¿Qué campo deseas actualizar?{RESET}")
        print(f"  {YELLOW}[1]{RESET}  Nivel de log (log_level)")
        print(f"  {YELLOW}[2]{RESET}  Mensaje (message)")
        print(f"  {YELLOW}[3]{RESET}  Aplicación (application)")
        print(f"  {YELLOW}[4]{RESET}  Entorno (environment)")
        print(f"  {YELLOW}[5]{RESET}  Servidor (server)")
        print(f"  {YELLOW}[6]{RESET}  HTTP status (http_status)")
        field_choice = input(f"\n{BOLD}Elige una opción: {RESET}").strip()

        field_map = {
            "1": ("log_level",   f"Nuevo nivel ({'/'.join(LOG_LEVELS)}): "),
            "2": ("message",     "Nuevo mensaje: "),
            "3": ("application", "Nueva aplicación: "),
            "4": ("environment", f"Nuevo entorno ({'/'.join(ENVIRONMENTS)}): "),
            "5": ("server",      "Nuevo servidor: "),
            "6": ("http_status", "Nuevo HTTP status (ej. 200, 404, 500): "),
        }

        if field_choice not in field_map:
            print_error("Opción no válida.")
            cur.close()
            conn.close()
            wait()
            return

        field_name, prompt = field_map[field_choice]
        new_value = input(prompt).strip()

        if not new_value:
            print_error("El nuevo valor no puede estar vacío.")
            cur.close()
            conn.close()
            wait()
            return

        # Validaciones específicas
        if field_name == "log_level" and new_value.upper() not in LOG_LEVELS:
            print_error(f"Nivel inválido. Usa: {', '.join(LOG_LEVELS)}")
            cur.close()
            conn.close()
            wait()
            return

        if field_name == "environment" and new_value.lower() not in ENVIRONMENTS:
            print_error(f"Entorno inválido. Usa: {', '.join(ENVIRONMENTS)}")
            cur.close()
            conn.close()
            wait()
            return

        if field_name == "log_level":
            new_value = new_value.upper()

        if field_name == "environment":
            new_value = new_value.lower()

        if field_name == "http_status":
            if not new_value.isdigit():
                print_error("El HTTP status debe ser un número.")
                cur.close()
                conn.close()
                wait()
                return
            new_value = int(new_value)

        # Ejecutar actualización
        update_sql = sql.SQL(
            "UPDATE {} SET {} = %s WHERE id = %s"
        ).format(
            sql.Identifier(TARGET_TABLE),
            sql.Identifier(field_name)
        )
        cur.execute(update_sql, (new_value, log_id))
        conn.commit()

        print_success(f"Registro ID {log_id} actualizado: {field_name} = '{new_value}'.")

        cur.close()
        conn.close()

    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error al actualizar: {e}")

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 5 — ELIMINAR REGISTRO(S)
# ══════════════════════════════════════════════════════════

def delete_log():
    print_separator()
    print(f"{BOLD}5. Eliminar registro(s) de log{RESET}\n")

    print(f"{YELLOW}Opciones de eliminación:{RESET}")
    print(f"  {YELLOW}[1]{RESET}  Eliminar por ID")
    print(f"  {YELLOW}[2]{RESET}  Eliminar por nivel de log")
    print(f"  {YELLOW}[3]{RESET}  Eliminar registros antiguos (más de N días)")
    print(f"  {YELLOW}[4]{RESET}  Eliminar TODOS los registros (truncate)")
    choice = input(f"\n{BOLD}Elige una opción: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor()

        if choice == "1":
            log_id = input("ID del registro a eliminar: ").strip()
            if not log_id.isdigit():
                print_error("El ID debe ser un número.")
                cur.close()
                conn.close()
                wait()
                return

            cur.execute(f"SELECT id, log_level, application, message FROM {TARGET_TABLE} WHERE id = %s", (log_id,))
            row = cur.fetchone()
            if not row:
                print_info(f"No se encontró ningún registro con ID = {log_id}.")
                cur.close()
                conn.close()
                wait()
                return

            print(f"\n  {CYAN}ID:{RESET}          {row[0]}")
            print(f"  {CYAN}Nivel:{RESET}       {row[1]}")
            print(f"  {CYAN}Aplicación:{RESET}  {row[2]}")
            print(f"  {CYAN}Mensaje:{RESET}     {str(row[3])[:60]}")

            confirm = input(f"\n{RED}¿Confirmar eliminación? (s/n): {RESET}").strip().lower()
            if confirm != "s":
                print_info("Operación cancelada.")
                cur.close()
                conn.close()
                wait()
                return

            cur.execute(f"DELETE FROM {TARGET_TABLE} WHERE id = %s", (log_id,))
            conn.commit()
            print_success(f"Registro ID {log_id} eliminado correctamente.")

        elif choice == "2":
            print(f"Niveles disponibles: {', '.join(LOG_LEVELS)}")
            level = input("Nivel a eliminar: ").strip().upper()
            if level not in LOG_LEVELS:
                print_error("Nivel inválido.")
                cur.close()
                conn.close()
                wait()
                return

            cur.execute(f"SELECT COUNT(*) FROM {TARGET_TABLE} WHERE log_level = %s", (level,))
            count = cur.fetchone()[0]
            print_info(f"Se eliminarán {count} registros con nivel '{level}'.")

            confirm = input(f"{RED}¿Confirmar eliminación? (s/n): {RESET}").strip().lower()
            if confirm != "s":
                print_info("Operación cancelada.")
                cur.close()
                conn.close()
                wait()
                return

            cur.execute(f"DELETE FROM {TARGET_TABLE} WHERE log_level = %s", (level,))
            conn.commit()
            print_success(f"{count} registros con nivel '{level}' eliminados.")

        elif choice == "3":
            days_str = input("Eliminar registros más antiguos que (días): ").strip()
            if not days_str.isdigit():
                print_error("Introduce un número de días válido.")
                cur.close()
                conn.close()
                wait()
                return
            days = int(days_str)
            cutoff = datetime.now() - timedelta(days=days)

            cur.execute(
                f"SELECT COUNT(*) FROM {TARGET_TABLE} WHERE timestamp < %s",
                (cutoff,)
            )
            count = cur.fetchone()[0]
            print_info(f"Se eliminarán {count} registros anteriores a {cutoff.strftime('%Y-%m-%d %H:%M')}.")

            if count == 0:
                print_info("No hay registros que cumplan ese criterio.")
                cur.close()
                conn.close()
                wait()
                return

            confirm = input(f"{RED}¿Confirmar eliminación? (s/n): {RESET}").strip().lower()
            if confirm != "s":
                print_info("Operación cancelada.")
                cur.close()
                conn.close()
                wait()
                return

            cur.execute(f"DELETE FROM {TARGET_TABLE} WHERE timestamp < %s", (cutoff,))
            conn.commit()
            print_success(f"{count} registros antiguos eliminados correctamente.")

        elif choice == "4":
            cur.execute(f"SELECT COUNT(*) FROM {TARGET_TABLE}")
            total = cur.fetchone()[0]
            print_info(f"Esta operación eliminará TODOS los {total} registros de la tabla.")

            confirm1 = input(f"{RED}¿Estás seguro? (escribe 'CONFIRMAR'): {RESET}").strip()
            if confirm1 != "CONFIRMAR":
                print_info("Operación cancelada.")
                cur.close()
                conn.close()
                wait()
                return

            cur.execute(f"TRUNCATE TABLE {TARGET_TABLE} RESTART IDENTITY")
            conn.commit()
            print_success(f"Tabla '{TARGET_TABLE}' vaciada completamente. IDs reiniciados.")

        else:
            print_error("Opción no válida.")

        cur.close()
        conn.close()

    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error al eliminar: {e}")

    wait()


# ══════════════════════════════════════════════════════════
# MENÚ PRINCIPAL
# ══════════════════════════════════════════════════════════

BANNER = f"""
{CYAN}{BOLD}╔══════════════════════════════════════════════════════════════╗
║       PostgreSQL — Gestión de Logs de Aplicaciones          ║
║       Base de datos: {TARGET_DB:<38}║
╚══════════════════════════════════════════════════════════════╝{RESET}
"""

MENU = f"""
{CYAN}{BOLD}── MENÚ PRINCIPAL ──────────────────────────────────────────{RESET}

  {YELLOW}[1]{RESET}  Crear base de datos y tabla (con datos de muestra)
  {YELLOW}[2]{RESET}  Insertar registro(s)
  {YELLOW}[3]{RESET}  Consultar / listar registros
  {YELLOW}[4]{RESET}  Actualizar registro
  {YELLOW}[5]{RESET}  Eliminar registro(s)
  {YELLOW}[0]{RESET}  Salir

{CYAN}────────────────────────────────────────────────────────────{RESET}
"""


def main():
    print(BANNER)
    print(f"{CYAN}Conexión configurada:{RESET}")
    print(f"  Host:     {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print(f"  Usuario:  {DB_CONFIG['user']}")
    print(f"  Base de datos destino: {BOLD}{TARGET_DB}{RESET}")
    print(f"\n{YELLOW}ℹ  Edita DB_CONFIG en el script si necesitas cambiar la conexión.{RESET}")

    while True:
        print(MENU)
        choice = input(f"{BOLD}Elige una opción: {RESET}").strip()

        if choice == "0":
            print(f"\n{GREEN}¡Hasta luego!{RESET}\n")
            sys.exit(0)
        elif choice == "1":
            create_database()
        elif choice == "2":
            insert_log()
        elif choice == "3":
            list_logs()
        elif choice == "4":
            update_log()
        elif choice == "5":
            delete_log()
        else:
            print(f"\n{RED}Opción no válida. Intenta de nuevo.{RESET}")


if __name__ == "__main__":
    main()
