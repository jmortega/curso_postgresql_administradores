"""
=============================================================
  PostgreSQL Advanced Monitoring Manager
  pg_stat_statements + pg_wait_sampling
=============================================================

Requisitos:
    pip install psycopg2-binary tabulate

Uso:
    python pgmon_manager.py
"""

import sys
import os
import json
import time
import subprocess
import shutil
import platform
from datetime import datetime, timedelta

try:
    import psycopg2
    from psycopg2 import sql, OperationalError
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("\n[ERROR] psycopg2 no instalado. Ejecuta: pip install psycopg2-binary")
    sys.exit(1)

try:
    from tabulate import tabulate
    TABULATE_OK = True
except ImportError:
    TABULATE_OK = False

# ── Colores ANSI ──────────────────────────────────────────
RED     = "\033[91m"
GREEN   = "\033[92m"
YELLOW  = "\033[93m"
CYAN    = "\033[96m"
MAGENTA = "\033[95m"
BLUE    = "\033[94m"
BOLD    = "\033[1m"
DIM     = "\033[2m"
RESET   = "\033[0m"

# ── Configuración ─────────────────────────────────────────
DB_CONFIG = {
    "host":     os.environ.get("PG_HOST",     "localhost"),
    "port":     int(os.environ.get("PG_PORT", "5432")),
    "user":     os.environ.get("PG_USER",     "postgres"),
    "password": os.environ.get("PG_PASSWORD", "postgres_lab"),
    "dbname":   os.environ.get("PG_DBNAME",   "postgres"),
}

# Umbrales de alerta configurables
THRESHOLDS = {
    "mean_exec_critical_ms":  1000,   # Query media > 1 segundo → crítico
    "mean_exec_warn_ms":       100,   # Query media > 100ms → atención
    "cache_hit_critical_pct":   95,   # Cache hit < 95% → crítico
    "cache_hit_warn_pct":        99,   # Cache hit < 99% → atención
    "lock_waits_critical":     1000,  # > 1000 lock waits → crítico
    "lock_waits_warn":          100,  # > 100 lock waits → atención
    "temp_blks_warn":           100,  # > 100 bloques temporales → atención
    "blocked_connections_warn":   3,  # > 3 conexiones bloqueadas → atención
    "io_wait_pct_warn":          10,  # > 10% en I/O waits → atención
    "io_wait_pct_critical":      30,  # > 30% en I/O waits → crítico
}

# ══════════════════════════════════════════════════════════
# HELPERS GENERALES
# ══════════════════════════════════════════════════════════

def get_connection(dbname=None):
    cfg = {**DB_CONFIG}
    if dbname:
        cfg["dbname"] = dbname
    return psycopg2.connect(**cfg)


def print_separator(char="─", color=CYAN, width=70):
    print(f"{color}{char * width}{RESET}")


def wait():
    input(f"\n{YELLOW}[↵ Pulsa Enter para continuar...]{RESET}\n")


def print_error(msg):
    print(f"\n{RED}✗  {msg}{RESET}")


def print_success(msg):
    print(f"\n{GREEN}✔  {msg}{RESET}")


def print_info(msg):
    print(f"\n{CYAN}ℹ  {msg}{RESET}")


def print_warn(msg):
    print(f"\n{YELLOW}⚠  {msg}{RESET}")


def severity_color(sev: str) -> str:
    return {
        "CRITICO":  RED   + BOLD,
        "ATENCION": YELLOW,
        "OK":       GREEN,
    }.get(sev, RESET)


def severity_icon(sev: str) -> str:
    return {"CRITICO": "🔴", "ATENCION": "🟡", "OK": "🟢"}.get(sev, "⚪")


def ms_label(ms: float) -> str:
    """Formatea milisegundos con color según umbral."""
    if ms >= THRESHOLDS["mean_exec_critical_ms"]:
        return f"{RED}{BOLD}{ms:.2f} ms{RESET}"
    elif ms >= THRESHOLDS["mean_exec_warn_ms"]:
        return f"{YELLOW}{ms:.2f} ms{RESET}"
    return f"{GREEN}{ms:.2f} ms{RESET}"


def pct_bar(value: float, width: int = 20, invert: bool = False) -> str:
    """Barra de progreso porcentual."""
    filled = int(min(value, 100) / 100 * width)
    if invert:   # Peor cuando más alto (ej: tiempo en waits)
        color = RED if value > 30 else YELLOW if value > 10 else GREEN
    else:        # Mejor cuando más alto (ej: cache hit)
        color = GREEN if value > 99 else YELLOW if value > 95 else RED
    return f"{color}{'█' * filled}{'░' * (width - filled)}{RESET} {value:.1f}%"


def fmt_table(rows, headers, fmt="simple"):
    """Formatea tabla con tabulate si está disponible."""
    if TABULATE_OK:
        return tabulate(rows, headers=headers, tablefmt=fmt,
                        floatfmt=".2f", missingval="—")
    # Fallback manual
    col_w = [max(len(str(h)), max((len(str(r[i])) for r in rows), default=0))
             for i, h in enumerate(headers)]
    sep = "  ".join("─" * w for w in col_w)
    lines = ["  ".join(str(h).ljust(w) for h, w in zip(headers, col_w)),
             sep]
    for row in rows:
        lines.append("  ".join(str(v).ljust(w) for v, w in zip(row, col_w)))
    return "\n".join(lines)


def check_extension(cur, extname: str) -> bool:
    """
    Comprueba si una extensión está activa.

    FIX: row[0] fallaba con KeyError cuando el cursor se crea con
    cursor_factory=RealDictCursor, porque fetchone() devuelve un dict
    (p.ej. {'extversion': '1.2'}) en lugar de una tupla, y los dicts
    no se indexan por posición entera. Se usa row["extversion"] cuando
    el resultado es un dict, y row[0] cuando es una tupla normal, para
    que la función funcione con cualquier tipo de cursor.
    """
    cur.execute(
        "SELECT extversion FROM pg_extension WHERE extname = %s", (extname,)
    )
    row = cur.fetchone()
    if not row:
        return None
    if isinstance(row, dict):
        return row["extversion"]
    return row[0]


# ══════════════════════════════════════════════════════════
# OPCIÓN 0 — INSTALAR Y CONFIGURAR EXTENSIONES
# ══════════════════════════════════════════════════════════

def install_extensions():
    print_separator(char="═", color=MAGENTA)
    print(f"{MAGENTA}{BOLD}  0. Instalar y configurar extensiones de monitorización{RESET}")
    print_separator(char="═", color=MAGENTA)

    sistema = platform.system()

    # ── Verificar estado actual ───────────────────────────
    try:
        conn = get_connection()
        cur  = conn.cursor()

        ver_pss = check_extension(cur, "pg_stat_statements")
        ver_pws = check_extension(cur, "pg_wait_sampling")

        cur.execute("SHOW server_version;")
        pg_ver_full = cur.fetchone()[0]

        cur.execute("SHOW shared_preload_libraries;")
        preload = cur.fetchone()[0]

        cur.close(); conn.close()

        import re
        pg_ver = int(re.search(r"(\d+)\.", pg_ver_full).group(1))

    except OperationalError as e:
        print_error(f"No se pudo conectar a PostgreSQL: {e}")
        wait(); return

    # ── Mostrar estado ────────────────────────────────────
    print(f"\n{BOLD}Estado actual:{RESET}")
    print(f"  PostgreSQL versión      : {CYAN}{pg_ver_full}{RESET}")
    print(f"  shared_preload_libraries: {DIM}{preload}{RESET}")
    print()

    # pg_stat_statements
    if ver_pss:
        print(f"  pg_stat_statements : {GREEN}✔ Activa (v{ver_pss}){RESET}")
    elif "pg_stat_statements" in preload:
        print(f"  pg_stat_statements : {YELLOW}⚠ En preload pero no activada → ejecutar CREATE EXTENSION{RESET}")
    else:
        print(f"  pg_stat_statements : {RED}✗ No configurada{RESET}")

    # pg_wait_sampling
    if ver_pws:
        print(f"  pg_wait_sampling   : {GREEN}✔ Activa (v{ver_pws}){RESET}")
    elif "pg_wait_sampling" in preload:
        print(f"  pg_wait_sampling   : {YELLOW}⚠ En preload pero no activada → ejecutar CREATE EXTENSION{RESET}")
    else:
        print(f"  pg_wait_sampling   : {RED}✗ No configurada{RESET}")

    # ── Menú de acciones ──────────────────────────────────
    print(f"\n{BOLD}¿Qué deseas hacer?{RESET}")
    print(f"  {YELLOW}[1]{RESET}  Activar pg_stat_statements (solo CREATE EXTENSION)")
    print(f"  {YELLOW}[2]{RESET}  Instalar pg_wait_sampling en el SO")
    print(f"  {YELLOW}[3]{RESET}  Mostrar configuración recomendada para postgresql.conf")
    print(f"  {YELLOW}[4]{RESET}  Verificar configuración actual completa")
    print(f"  {YELLOW}[5]{RESET}  Activar ambas extensiones con CREATE EXTENSION")
    action = input(f"\n{BOLD}Elige: {RESET}").strip()

    if action == "1":
        _activate_pss()
    elif action == "2":
        _install_pws_on_os(sistema, pg_ver)
    elif action == "3":
        _show_recommended_config()
    elif action == "4":
        _verify_full_config()
    elif action == "5":
        _activate_pss()
        _activate_pws()

    wait()


def _activate_pss():
    """Activa pg_stat_statements en la BD actual."""
    try:
        conn = get_connection()
        cur  = conn.cursor()
        # Verificar preload
        cur.execute("SHOW shared_preload_libraries;")
        preload = cur.fetchone()[0]
        if "pg_stat_statements" not in preload:
            print_warn(
                "pg_stat_statements no está en shared_preload_libraries.\n"
                "  Añade la siguiente línea a postgresql.conf y reinicia:\n"
                f"  {CYAN}shared_preload_libraries = 'pg_stat_statements'{RESET}"
            )
            cur.close(); conn.close()
            return

        cur.execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements;")
        conn.commit()
        ver = check_extension(cur, "pg_stat_statements")
        print_success(f"pg_stat_statements activada (v{ver}).")
        cur.close(); conn.close()
    except Exception as e:
        print_error(f"Error al activar pg_stat_statements: {e}")
        _show_preload_hint("pg_stat_statements")


def _activate_pws():
    """Activa pg_wait_sampling en la BD actual."""
    try:
        conn = get_connection()
        cur  = conn.cursor()
        cur.execute("SHOW shared_preload_libraries;")
        preload = cur.fetchone()[0]
        if "pg_wait_sampling" not in preload:
            print_warn(
                "pg_wait_sampling no está en shared_preload_libraries.\n"
                "  Añade la siguiente línea a postgresql.conf y reinicia:\n"
                f"  {CYAN}shared_preload_libraries = 'pg_stat_statements, pg_wait_sampling'{RESET}"
            )
            cur.close(); conn.close()
            return

        cur.execute("CREATE EXTENSION IF NOT EXISTS pg_wait_sampling;")
        conn.commit()
        ver = check_extension(cur, "pg_wait_sampling")
        print_success(f"pg_wait_sampling activada (v{ver}).")
        cur.close(); conn.close()
    except Exception as e:
        print_error(f"Error al activar pg_wait_sampling: {e}")
        _show_preload_hint("pg_wait_sampling")


def _show_preload_hint(extname: str):
    print(f"\n{BOLD}Pasos necesarios:{RESET}")
    print(f"  1. Edita postgresql.conf:")
    print(f"     {CYAN}shared_preload_libraries = 'pg_stat_statements, pg_wait_sampling'{RESET}")
    print(f"  2. Reinicia PostgreSQL:")
    print(f"     {CYAN}sudo systemctl restart postgresql{RESET}")
    print(f"  3. Ejecuta de nuevo esta opción.")


def _install_pws_on_os(sistema: str, pg_ver: int):
    """Intenta instalar pg_wait_sampling en el SO."""
    pkg = f"postgresql-{pg_ver}-pg-wait-sampling"
    print(f"\n{BOLD}Instalación de pg_wait_sampling en el sistema{RESET}")
    print(f"  Sistema   : {sistema}")
    print(f"  Paquete   : {CYAN}{pkg}{RESET}\n")

    if sistema == "Linux" and shutil.which("apt-get"):
        confirm = input(
            f"{YELLOW}¿Ejecutar 'sudo apt-get install {pkg}'? (s/n): {RESET}"
        ).strip().lower()
        if confirm == "s":
            print(f"\n{YELLOW}⏳ Instalando...{RESET}")
            rc = subprocess.run(
                ["sudo", "apt-get", "install", "-y", pkg],
                capture_output=False
            )
            if rc.returncode == 0:
                print_success(f"'{pkg}' instalado. Reinicia PostgreSQL y activa la extensión.")
            else:
                print_error("Instalación fallida.")
                _show_pws_manual()
        else:
            _show_pws_manual()

    elif sistema == "Darwin" and shutil.which("brew"):
        confirm = input(
            f"{YELLOW}¿Ejecutar 'brew install pg_wait_sampling'? (s/n): {RESET}"
        ).strip().lower()
        if confirm == "s":
            rc = subprocess.run(
                ["brew", "install", "pg_wait_sampling"], capture_output=False
            )
            if rc.returncode != 0:
                _show_pws_manual()
        else:
            _show_pws_manual()
    else:
        _show_pws_manual()


def _show_pws_manual():
    print(f"\n{BOLD}Instalación manual de pg_wait_sampling:{RESET}")
    print(f"  {CYAN}Desde paquete (Debian/Ubuntu):{RESET}")
    print(f"  $ sudo apt-get install postgresql-$(pg_config --major-version)-pg-wait-sampling")
    print(f"\n  {CYAN}Compilar desde fuente:{RESET}")
    print(f"  $ git clone https://github.com/postgrespro/pg_wait_sampling.git")
    print(f"  $ cd pg_wait_sampling")
    print(f"  $ make PG_CONFIG=$(which pg_config)")
    print(f"  $ sudo make install")
    print(f"\n  {CYAN}Documentación:{RESET} https://github.com/postgrespro/pg_wait_sampling")


def _show_recommended_config():
    print(f"\n{BOLD}Configuración recomendada para postgresql.conf:{RESET}")
    print_separator("─")
    config = """
# ── Extensiones de monitorización ────────────────────────────
shared_preload_libraries = 'pg_stat_statements, pg_wait_sampling'

# pg_stat_statements
pg_stat_statements.max             = 10000   # Queries distintas a almacenar
pg_stat_statements.track           = all     # all | top | none
pg_stat_statements.track_utility   = on      # VACUUM, COPY, DDL, etc.
pg_stat_statements.track_planning  = on      # Tiempo de planificación (PG>=13)
pg_stat_statements.save            = on      # Persistir entre reinicios

# pg_wait_sampling
pg_wait_sampling.history_size      = 5000    # Muestras en historial circular
pg_wait_sampling.history_period    = 10      # ms entre muestras (historial)
pg_wait_sampling.profile_period    = 10      # ms entre muestras (perfil)
pg_wait_sampling.profile_pid       = on      # Perfil por PID
pg_wait_sampling.profile_queries   = on      # Asociar waits con queries

# ── Logging de queries lentas ─────────────────────────────────
log_min_duration_statement         = 1000    # Loguear queries > 1 segundo
log_checkpoints                    = on
log_lock_waits                     = on
log_temp_files                     = 0       # Loguear todos los temp files
"""
    print(f"{CYAN}{config}{RESET}")
    print_separator("─")
    print(f"\n{YELLOW}ℹ  Después de editar postgresql.conf ejecuta:{RESET}")
    print(f"   {CYAN}sudo systemctl restart postgresql{RESET}")
    print(f"   O para parámetros sin restart:")
    print(f"   {CYAN}SELECT pg_reload_conf();{RESET}")


def _verify_full_config():
    """Verifica la configuración completa de las extensiones."""
    try:
        conn = get_connection()
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        params = [
            "shared_preload_libraries",
            "pg_stat_statements.max",
            "pg_stat_statements.track",
            "pg_stat_statements.track_utility",
            "pg_stat_statements.track_planning",
            "pg_stat_statements.save",
        ]

        print(f"\n{BOLD}Configuración actual de PostgreSQL:{RESET}")
        print_separator("─")
        for p in params:
            try:
                cur.execute(f"SHOW {p};")
                val = cur.fetchone()[p]
                print(f"  {CYAN}{p:<45}{RESET} {val}")
            except Exception:
                print(f"  {DIM}{p:<45} (no disponible){RESET}")

        # pg_wait_sampling params
        pws_params = [
            "pg_wait_sampling.history_size",
            "pg_wait_sampling.history_period",
            "pg_wait_sampling.profile_period",
            "pg_wait_sampling.profile_queries",
        ]
        print()
        for p in pws_params:
            try:
                cur.execute(f"SHOW {p};")
                val = cur.fetchone()[p]
                print(f"  {CYAN}{p:<45}{RESET} {val}")
            except Exception:
                print(f"  {YELLOW}{p:<45} (pg_wait_sampling no cargada){RESET}")

        print_separator("─")
        cur.close(); conn.close()

    except OperationalError as e:
        print_error(f"Error de conexión: {e}")


# ══════════════════════════════════════════════════════════
# OPCIÓN 1 — pg_stat_statements: QUERIES LENTAS
# ══════════════════════════════════════════════════════════

def analyze_slow_queries():
    print_separator(char="═", color=BLUE)
    print(f"{BLUE}{BOLD}  1. pg_stat_statements — Análisis de queries{RESET}")
    print_separator(char="═", color=BLUE)

    print(f"\n  {YELLOW}[1]{RESET}  Top 10 por tiempo total")
    print(f"  {YELLOW}[2]{RESET}  Top 10 por tiempo medio (candidatas a optimizar)")
    print(f"  {YELLOW}[3]{RESET}  Queries con mayor I/O (lecturas de disco)")
    print(f"  {YELLOW}[4]{RESET}  Queries con archivos temporales (work_mem bajo)")
    print(f"  {YELLOW}[5]{RESET}  Queries más frecuentes")
    print(f"  {YELLOW}[6]{RESET}  Ratio de cache hit por query")
    print(f"  {YELLOW}[7]{RESET}  Queries con mayor generación de WAL")
    print(f"  {YELLOW}[8]{RESET}  Resumen global del sistema")
    print(f"  {YELLOW}[9]{RESET}  Resetear estadísticas")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection()
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        # Verificar extensión
        ver = check_extension(cur, "pg_stat_statements")
        if not ver:
            print_error(
                "pg_stat_statements no está activa.\n"
                "  Ejecuta la opción [0] para instalarla."
            )
            cur.close(); conn.close(); wait(); return

        if choice == "1":
            _pss_top_by_total_time(cur)
        elif choice == "2":
            _pss_top_by_mean_time(cur)
        elif choice == "3":
            _pss_top_io(cur)
        elif choice == "4":
            _pss_temp_files(cur)
        elif choice == "5":
            _pss_most_frequent(cur)
        elif choice == "6":
            _pss_cache_hit(cur)
        elif choice == "7":
            _pss_wal_generation(cur)
        elif choice == "8":
            _pss_global_summary(cur)
        elif choice == "9":
            _pss_reset(cur, conn)
        else:
            print_error("Opción no válida.")

        cur.close(); conn.close()
    except OperationalError as e:
        print_error(f"Error de conexión: {e}")
    except Exception as e:
        print_error(f"Error: {e}")
        import traceback; traceback.print_exc()

    wait()


def _pss_top_by_total_time(cur):
    n = int(input("Número de resultados [10]: ").strip() or "10")
    cur.execute("""
        SELECT
            LEFT(query, 90)                        AS query,
            calls,
            ROUND(total_exec_time::numeric, 2)     AS total_ms,
            ROUND(mean_exec_time::numeric, 2)      AS media_ms,
            ROUND(max_exec_time::numeric, 2)       AS max_ms,
            ROUND(stddev_exec_time::numeric, 2)    AS stddev_ms,
            rows,
            ROUND(
                (100.0 * total_exec_time /
                SUM(total_exec_time) OVER ())::numeric, 2
                )                                  AS pct_tiempo_total
        FROM pg_stat_statements
        WHERE query NOT ILIKE '%%pg_stat_statements%%'
          AND query NOT ILIKE '%%pg_wait_sampling%%'
          AND calls > 0
        ORDER BY total_exec_time DESC
        LIMIT %s
    """, (n,))
    rows = cur.fetchall()
    _print_pss_table(rows, "Top queries por tiempo TOTAL de ejecución",
                     ["Query", "Calls", "Total ms", "Media ms",
                      "Max ms", "Stddev ms", "Rows", "% Tiempo"])


def _pss_top_by_mean_time(cur):
    min_calls = int(input("Mínimo de llamadas para incluir [10]: ").strip() or "10")
    n = int(input("Número de resultados [10]: ").strip() or "10")
    cur.execute("""
        SELECT
            LEFT(query, 90)                         AS query,
            calls,
            ROUND(mean_exec_time::numeric, 2)       AS media_ms,
            ROUND(max_exec_time::numeric, 2)        AS max_ms,
            ROUND(stddev_exec_time::numeric, 2)     AS stddev_ms,
            CASE
                WHEN mean_exec_time > 1000 THEN 'CRITICO'
                WHEN mean_exec_time > 100  THEN 'ATENCION'
                ELSE 'OK'
            END                                      AS estado,
            CASE
                WHEN stddev_exec_time > mean_exec_time THEN 'Inestable'
                ELSE 'Estable'
            END                                      AS estabilidad
        FROM pg_stat_statements
        WHERE calls >= %s
          AND query NOT ILIKE '%%pg_stat_statements%%'
        ORDER BY mean_exec_time DESC
        LIMIT %s
    """, (min_calls, n))
    rows = cur.fetchall()
    _print_pss_table(rows, f"Top queries por tiempo MEDIO (min {min_calls} llamadas)",
                     ["Query", "Calls", "Media ms", "Max ms",
                      "Stddev ms", "Estado", "Estabilidad"])

    # Alertas
    criticas = [r for r in rows if r["estado"] == "CRITICO"]
    if criticas:
        print(f"\n  {RED}{BOLD}⚠ {len(criticas)} queries críticas (>1s media){RESET}")


def _pss_top_io(cur):
    n = int(input("Número de resultados [10]: ").strip() or "10")
    cur.execute("""
        SELECT
            LEFT(query, 90)                         AS query,
            calls,
            shared_blks_read                        AS blks_disco,
            shared_blks_hit                         AS blks_cache,
            ROUND(
                100.0 * shared_blks_hit /
                NULLIF(shared_blks_hit + shared_blks_read, 0), 2
            )                                        AS cache_pct,
            temp_blks_written                        AS temp_blks,
            ROUND(
                (blk_read_time + blk_write_time)::numeric, 2
            )                                        AS io_time_ms
        FROM pg_stat_statements
        WHERE shared_blks_read > 0
          AND query NOT ILIKE '%%pg_stat_statements%%'
        ORDER BY shared_blks_read DESC
        LIMIT %s
    """, (n,))
    rows = cur.fetchall()
    _print_pss_table(rows, "Queries con mayor lectura de disco (I/O)",
                     ["Query", "Calls", "Blks Disco", "Blks Cache",
                      "Cache %", "Temp Blks", "I/O Time ms"])

    # Advertencia de cache hit bajo
    bajo_cache = [r for r in rows
                  if r["cache_pct"] is not None and float(r["cache_pct"]) < 95]
    if bajo_cache:
        print_warn(
            f"{len(bajo_cache)} queries con cache hit < 95%.\n"
            "  Considera aumentar shared_buffers o añadir índices."
        )


def _pss_temp_files(cur):
    n = int(input("Número de resultados [10]: ").strip() or "10")
    cur.execute("""
        SELECT
            LEFT(query, 90)                                  AS query,
            calls,
            temp_blks_written,
            ROUND(temp_blks_written * 8.0 / 1024, 2)        AS temp_mb,
            ROUND(mean_exec_time::numeric, 2)                AS media_ms,
            ROUND(
                temp_blks_written::numeric / NULLIF(calls,0), 1
            )                                                 AS temp_blks_x_llamada
        FROM pg_stat_statements
        WHERE temp_blks_written > 0
          AND query NOT ILIKE '%%pg_stat_statements%%'
        ORDER BY temp_blks_written DESC
        LIMIT %s
    """, (n,))
    rows = cur.fetchall()
    _print_pss_table(rows, "Queries que generan archivos temporales (work_mem insuficiente)",
                     ["Query", "Calls", "Temp Blks", "Temp MB",
                      "Media ms", "Temp Blks/Llamada"])
    if rows:
        print_warn(
            "Estas queries necesitan más memoria para sorts/joins.\n"
            "  Solución: SET work_mem = '256MB'; o aumentar work_mem globalmente."
        )


def _pss_most_frequent(cur):
    n = int(input("Número de resultados [10]: ").strip() or "10")
    cur.execute("""
        SELECT
            LEFT(query, 90)                                      AS query,
            calls,
            ROUND(total_exec_time::numeric, 2)                   AS total_ms,
            ROUND(mean_exec_time::numeric, 4)                    AS media_ms,
            rows,
            ROUND(rows::numeric / NULLIF(calls, 0), 1)           AS filas_x_llamada
        FROM pg_stat_statements
        WHERE calls > 10
          AND query NOT ILIKE '%%pg_stat_statements%%'
        ORDER BY calls DESC
        LIMIT %s
    """, (n,))
    rows = cur.fetchall()
    _print_pss_table(rows, "Queries más frecuentes (mayor carga por volumen)",
                     ["Query", "Calls", "Total ms", "Media ms",
                      "Rows", "Filas/Llamada"])


def _pss_cache_hit(cur):
    n = int(input("Número de resultados [15]: ").strip() or "15")
    cur.execute("""
        SELECT
            LEFT(query, 90)                          AS query,
            calls,
            shared_blks_hit + shared_blks_read       AS total_blks,
            ROUND(
                100.0 * shared_blks_hit /
                NULLIF(shared_blks_hit + shared_blks_read, 0), 2
            )                                         AS cache_hit_pct
        FROM pg_stat_statements
        WHERE shared_blks_hit + shared_blks_read > 500
          AND query NOT ILIKE '%%pg_stat_statements%%'
        ORDER BY cache_hit_pct ASC
        LIMIT %s
    """, (n,))
    rows = cur.fetchall()
    print(f"\n{BOLD}Ratio de cache hit por query (peor primero):{RESET}")
    print_separator("─")
    for r in rows:
        pct = float(r["cache_hit_pct"] or 0)
        bar = pct_bar(pct, width=20)
        query_short = str(r["query"])[:60]
        print(f"\n  {query_short}")
        print(f"  {bar}  ({r['total_blks']:,} bloques totales, {r['calls']} llamadas)")


def _pss_wal_generation(cur):
    n = int(input("Número de resultados [10]: ").strip() or "10")
    try:
        cur.execute("""
            SELECT
                LEFT(query, 90)                              AS query,
                calls,
                wal_records,
                ROUND(wal_bytes / 1024.0 / 1024, 2)          AS wal_mb,
                ROUND(mean_exec_time::numeric, 2)             AS media_ms
            FROM pg_stat_statements
            WHERE wal_bytes > 0
              AND query NOT ILIKE '%%pg_stat_statements%%'
            ORDER BY wal_bytes DESC
            LIMIT %s
        """, (n,))
        rows = cur.fetchall()
        _print_pss_table(rows, "Queries con mayor generación de WAL (PG >= 13)",
                         ["Query", "Calls", "WAL Records", "WAL MB", "Media ms"])
    except psycopg2.errors.UndefinedColumn:
        print_warn("La columna wal_bytes requiere PostgreSQL >= 13.")


def _pss_global_summary(cur):
    try:
        cur.execute("""
            SELECT
                COUNT(*)                                        AS queries_distintas,
                SUM(calls)                                      AS total_ejecuciones,
                ROUND(SUM(total_exec_time)::numeric / 1000 / 60, 2)
                                                                AS min_cpu_total,
                ROUND(AVG(mean_exec_time)::numeric, 2)          AS media_global_ms,
                SUM(shared_blks_read)                           AS blks_disco,
                SUM(shared_blks_hit)                            AS blks_cache,
                ROUND(
                    100.0 * SUM(shared_blks_hit) /
                    NULLIF(SUM(shared_blks_hit)+SUM(shared_blks_read),0), 2
                )                                               AS cache_hit_pct,
                SUM(temp_blks_written)                          AS total_temp_blks,
                COALESCE(ROUND(SUM(wal_bytes)/1024.0/1024,2),0) AS total_wal_mb
            FROM pg_stat_statements
            WHERE query NOT ILIKE '%%pg_stat_statements%%'
        """)
        r = cur.fetchone()
    except Exception:
        cur.execute("""
            SELECT
                COUNT(*)                                    AS queries_distintas,
                SUM(calls)                                  AS total_ejecuciones,
                ROUND(SUM(total_exec_time)::numeric/1000/60,2) AS min_cpu_total,
                ROUND(AVG(mean_exec_time)::numeric,2)       AS media_global_ms,
                SUM(shared_blks_read)                       AS blks_disco,
                SUM(shared_blks_hit)                        AS blks_cache,
                ROUND(100.0*SUM(shared_blks_hit)/
                      NULLIF(SUM(shared_blks_hit)+SUM(shared_blks_read),0),2)
                                                            AS cache_hit_pct,
                SUM(temp_blks_written)                      AS total_temp_blks,
                0                                           AS total_wal_mb
            FROM pg_stat_statements
            WHERE query NOT ILIKE '%%pg_stat_statements%%'
        """)
        r = cur.fetchone()

    cache_pct = float(r["cache_hit_pct"] or 0)
    print(f"\n{BOLD}{'═'*55}{RESET}")
    print(f"{BOLD}  RESUMEN GLOBAL — pg_stat_statements{RESET}")
    print(f"{BOLD}{'═'*55}{RESET}")
    print(f"\n  Queries distintas registradas : {CYAN}{r['queries_distintas']:,}{RESET}")
    print(f"  Total de ejecuciones          : {CYAN}{r['total_ejecuciones']:,}{RESET}")
    print(f"  Tiempo CPU total acumulado    : {CYAN}{r['min_cpu_total']} minutos{RESET}")
    print(f"  Tiempo medio global           : {ms_label(float(r['media_global_ms'] or 0))}")
    print(f"\n  Cache hit ratio               : {pct_bar(cache_pct)}")
    print(f"  Bloques leídos de disco       : {CYAN}{r['blks_disco']:,}{RESET}")
    print(f"  Bloques servidos de cache     : {CYAN}{r['blks_cache']:,}{RESET}")
    print(f"\n  Archivos temporales (bloques) : ", end="")
    temp = int(r["total_temp_blks"] or 0)
    if temp > 10000:
        print(f"{RED}{BOLD}{temp:,}{RESET} {RED}⚠ work_mem posiblemente bajo{RESET}")
    elif temp > 0:
        print(f"{YELLOW}{temp:,}{RESET}")
    else:
        print(f"{GREEN}0 ✔{RESET}")

    wal_mb = float(r["total_wal_mb"] or 0)
    if wal_mb > 0:
        print(f"  WAL generado (total)          : {CYAN}{wal_mb:.2f} MB{RESET}")
    print(f"\n{'═'*55}")


def _pss_reset(cur, conn):
    confirm = input(
        f"\n{RED}¿Confirmar reset de todas las estadísticas? (escribe RESET): {RESET}"
    ).strip()
    if confirm == "RESET":
        cur.execute("SELECT pg_stat_statements_reset();")
        conn.commit()
        print_success("Estadísticas de pg_stat_statements reseteadas.")
    else:
        print_info("Operación cancelada.")


def _print_pss_table(rows, title: str, headers: list):
    print(f"\n{BOLD}{title}{RESET}")
    print_separator("─")
    if not rows:
        print_info("No se encontraron datos.")
        return
    # Convertir rows de RealDictRow a listas
    data = []
    for r in rows:
        row = []
        for k in r.keys():
            v = r[k]
            # Colorear campo de estado
            if k == "estado":
                icon = severity_icon(str(v))
                c    = severity_color(str(v))
                v    = f"{icon} {c}{v}{RESET}"
            elif k == "media_ms" and v is not None:
                v = ms_label(float(v))
            row.append(v if v is not None else "—")
        data.append(row)

    if TABULATE_OK:
        print(tabulate(data, headers=headers, tablefmt="simple",
                       floatfmt=".2f", missingval="—"))
    else:
        # Fallback simple
        w = [max(len(str(h)), max((len(str(r[i])) for r in data), default=0))
             for i, h in enumerate(headers)]
        print("  " + "  ".join(str(h).ljust(w[i]) for i, h in enumerate(headers)))
        print("  " + "  ".join("─" * wi for wi in w))
        for row in data:
            print("  " + "  ".join(str(v).ljust(w[i]) for i, v in enumerate(row)))
    print(f"\n  {DIM}Total: {len(rows)} registros{RESET}")


# ══════════════════════════════════════════════════════════
# OPCIÓN 2 — pg_wait_sampling: EVENTOS DE ESPERA
# ══════════════════════════════════════════════════════════

def analyze_wait_events():
    print_separator(char="═", color=MAGENTA)
    print(f"{MAGENTA}{BOLD}  2. pg_wait_sampling — Análisis de eventos de espera{RESET}")
    print_separator(char="═", color=MAGENTA)

    print(f"\n  {YELLOW}[1]{RESET}  Distribución de waits por tipo (perfil acumulado)")
    print(f"  {YELLOW}[2]{RESET}  Historial reciente de esperas")
    print(f"  {YELLOW}[3]{RESET}  Procesos con más esperas ahora mismo")
    print(f"  {YELLOW}[4]{RESET}  Queries asociadas a eventos de espera")
    print(f"  {YELLOW}[5]{RESET}  Detección de Lock Contention")
    print(f"  {YELLOW}[6]{RESET}  Análisis de I/O waits")
    print(f"  {YELLOW}[7]{RESET}  Mapa de calor por categoría de wait")
    print(f"  {YELLOW}[8]{RESET}  Resetear perfil de esperas")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection()
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        ver_pws = check_extension(cur, "pg_wait_sampling")
        if not ver_pws:
            print_error(
                "pg_wait_sampling no está activa.\n"
                "  Ejecuta la opción [0] para instalarla."
            )
            cur.close(); conn.close(); wait(); return

        if choice == "1":
            _pws_profile_distribution(cur)
        elif choice == "2":
            _pws_recent_history(cur)
        elif choice == "3":
            _pws_active_processes(cur)
        elif choice == "4":
            _pws_queries_with_waits(cur)
        elif choice == "5":
            _pws_lock_contention(cur)
        elif choice == "6":
            _pws_io_analysis(cur)
        elif choice == "7":
            _pws_heatmap(cur)
        elif choice == "8":
            _pws_reset(cur, conn)
        else:
            print_error("Opción no válida.")

        cur.close(); conn.close()
    except OperationalError as e:
        print_error(f"Error de conexión: {e}")
    except Exception as e:
        print_error(f"Error: {e}")
        import traceback; traceback.print_exc()

    wait()


def _pws_profile_distribution(cur):
    cur.execute("""
        SELECT
            COALESCE(event_type, 'CPU') AS event_type,
            COALESCE(event, '—')        AS event,
            SUM(count)                  AS total_samples,
            ROUND(
                100.0 * SUM(count) /
                SUM(SUM(count)) OVER (), 2
            )                           AS pct_total
        FROM pg_wait_sampling_profile
        GROUP BY event_type, event
        ORDER BY total_samples DESC
        LIMIT 25
    """)
    rows = cur.fetchall()
    print(f"\n{BOLD}Distribución de eventos de espera (perfil acumulado):{RESET}")
    print_separator("─")
    print(f"  {'Tipo':<16} {'Evento':<35} {'Muestras':>10} {'%':>8}  {'Barra'}")
    print_separator("─")
    total = sum(int(r["total_samples"]) for r in rows)
    for r in rows:
        pct  = float(r["pct_total"] or 0)
        etype = str(r["event_type"])
        color = (RED    if etype == "Lock"   else
                 YELLOW if etype == "LWLock" else
                 BLUE   if etype == "IO"     else
                 CYAN   if etype == "Client" else RESET)
        bar = "█" * int(pct / 2)
        print(
            f"  {color}{etype:<16}{RESET} "
            f"{str(r['event']):<35} "
            f"{int(r['total_samples']):>10,} "
            f"{pct:>7.1f}%  "
            f"{color}{bar}{RESET}"
        )
    print_separator("─")
    print(f"  Total muestras: {CYAN}{total:,}{RESET}")


def _pws_recent_history(cur):
    n = int(input("Número de entradas del historial [20]: ").strip() or "20")
    cur.execute("""
        SELECT
            pid,
            COALESCE(event_type, 'CPU')  AS event_type,
            COALESCE(event, 'CPU active') AS event,
            COUNT(*)                      AS muestras
        FROM pg_wait_sampling_history
        GROUP BY pid, event_type, event
        ORDER BY muestras DESC
        LIMIT %s
    """, (n,))
    rows = cur.fetchall()
    print(f"\n{BOLD}Historial reciente de esperas (agregado por PID + evento):{RESET}")
    _print_wait_table(rows, ["PID", "Tipo", "Evento", "Muestras"])


def _pws_active_processes(cur):
    cur.execute("""
        SELECT
            a.pid,
            a.usename,
            a.state,
            a.wait_event_type,
            a.wait_event,
            LEFT(a.query, 70)       AS query_actual,
            h.muestras,
            EXTRACT(EPOCH FROM (NOW() - a.query_start))::int AS secs
        FROM pg_stat_activity a
        JOIN (
            SELECT pid, COUNT(*) AS muestras
            FROM pg_wait_sampling_history
            WHERE event IS NOT NULL
            GROUP BY pid
        ) h ON h.pid = a.pid
        WHERE a.pid != pg_backend_pid()
          AND a.state != 'idle'
        ORDER BY h.muestras DESC
        LIMIT 15
    """)
    rows = cur.fetchall()
    print(f"\n{BOLD}Procesos activos con más eventos de espera:{RESET}")
    print_separator("─")
    if not rows:
        print_info("No hay procesos activos con esperas registradas.")
        return
    for r in rows:
        etype = str(r["wait_event_type"] or "")
        color = (RED if etype == "Lock" else YELLOW if etype == "LWLock"
                 else BLUE if etype == "IO" else CYAN)
        print(f"\n  {BOLD}PID {r['pid']}{RESET}  "
              f"{DIM}{r['usename']}{RESET}  "
              f"state={r['state']}  "
              f"{CYAN}{r['secs'] or 0}s{RESET}")
        print(f"  Wait: {color}{etype}/{r['wait_event'] or '—'}{RESET}  "
              f"Muestras: {YELLOW}{r['muestras']}{RESET}")
        print(f"  Query: {DIM}{r['query_actual']}{RESET}")


def _pws_queries_with_waits(cur):
    ver_pss = check_extension(cur, "pg_stat_statements")
    if not ver_pss:
        print_warn(
            "pg_stat_statements no está activa.\n"
            "  Esta vista requiere ambas extensiones. Activa pg_stat_statements."
        )
        return

    cur.execute("""
        SELECT
            p.queryid,
            LEFT(s.query, 80)               AS query,
            p.event_type,
            p.event,
            SUM(p.count)                    AS total_waits,
            ROUND(s.mean_exec_time::numeric, 2) AS media_ms
        FROM pg_wait_sampling_profile p
        JOIN pg_stat_statements s ON s.queryid = p.queryid
        WHERE p.event IS NOT NULL
        GROUP BY p.queryid, s.query, p.event_type, p.event, s.mean_exec_time
        ORDER BY total_waits DESC
        LIMIT 15
    """)
    rows = cur.fetchall()
    print(f"\n{BOLD}Queries con más eventos de espera asociados:{RESET}")
    _print_wait_table(rows, ["QueryID", "Query", "Tipo Wait", "Evento", "Waits", "Media ms"])


def _pws_lock_contention(cur):
    print(f"\n{BOLD}Análisis de Lock Contention{RESET}")

    # Locks activos desde pg_wait_sampling
    cur.execute("""
        SELECT
            COALESCE(event, 'Unknown') AS lock_type,
            SUM(count)                  AS total_waits,
            COUNT(DISTINCT pid)         AS pids_afectados
        FROM pg_wait_sampling_profile
        WHERE event_type = 'Lock'
        GROUP BY event
        ORDER BY total_waits DESC
    """)
    rows_profile = cur.fetchall()

    # Procesos bloqueados ahora
    cur.execute("""
        SELECT
            blocked.pid                         AS pid_bloqueado,
            blocked.usename,
            LEFT(blocked.query, 70)             AS query_bloqueada,
            blocking.pid                        AS pid_bloqueador,
            LEFT(blocking.query, 50)            AS query_bloqueadora,
            EXTRACT(EPOCH FROM
                (NOW() - blocked.query_start))::int AS secs_esperando,
            blocked.wait_event
        FROM pg_stat_activity blocked
        JOIN pg_stat_activity blocking
            ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
        WHERE blocked.wait_event_type = 'Lock'
        ORDER BY secs_esperando DESC
    """)
    blocked = cur.fetchall()

    print_separator("─")
    print(f"{BOLD}Historial de lock waits por tipo:{RESET}")
    if rows_profile:
        for r in rows_profile:
            print(f"  {RED}{str(r['lock_type']):<30}{RESET} "
                  f"{r['total_waits']:>8,} waits  "
                  f"{r['pids_afectados']} PIDs")
    else:
        print_info("No hay lock waits en el perfil acumulado.")

    print(f"\n{BOLD}Procesos bloqueados AHORA:{RESET}")
    if blocked:
        for b in blocked:
            print(
                f"\n  {RED}PID {b['pid_bloqueado']}{RESET} "
                f"({b['usename']}) lleva {RED}{b['secs_esperando']}s{RESET} esperando"
            )
            print(f"  Bloqueado por PID {YELLOW}{b['pid_bloqueador']}{RESET}")
            print(f"  Query bloqueada  : {DIM}{b['query_bloqueada']}{RESET}")
            print(f"  Query bloqueadora: {DIM}{b['query_bloqueadora']}{RESET}")
    else:
        print_success("No hay procesos bloqueados por locks en este momento.")


def _pws_io_analysis(cur):
    cur.execute("""
        SELECT
            COALESCE(event_type, 'CPU') AS categoria,
            COALESCE(event, 'activo')   AS evento,
            SUM(count)                  AS muestras,
            ROUND(
                100.0 * SUM(count) /
                SUM(SUM(count)) OVER (), 2
            )                           AS pct
        FROM pg_wait_sampling_profile
        GROUP BY event_type, event
        ORDER BY muestras DESC
    """)
    rows = cur.fetchall()

    total_io    = sum(int(r["muestras"]) for r in rows if r["categoria"] == "IO")
    total_lock  = sum(int(r["muestras"]) for r in rows if r["categoria"] == "Lock")
    total_cpu   = sum(int(r["muestras"]) for r in rows if r["categoria"] == "CPU")
    total_all   = sum(int(r["muestras"]) for r in rows) or 1
    pct_io      = total_io   / total_all * 100
    pct_lock    = total_lock / total_all * 100
    pct_cpu     = total_cpu  / total_all * 100

    print(f"\n{BOLD}Análisis de distribución de tiempo del servidor:{RESET}")
    print_separator("─")
    print(f"\n  {'CPU activa':<25} {pct_bar(pct_cpu,   width=25, invert=False)}")
    print(f"  {'I/O waits':<25} {pct_bar(pct_io,    width=25, invert=True)}")
    print(f"  {'Lock waits':<25} {pct_bar(pct_lock,  width=25, invert=True)}")

    print(f"\n{BOLD}Detalle de I/O events:{RESET}")
    io_rows = [r for r in rows if r["categoria"] == "IO"]
    if io_rows:
        for r in io_rows:
            print(f"  {BLUE}{str(r['evento']):<35}{RESET} "
                  f"{int(r['muestras']):>8,} muestras  ({r['pct']:.1f}%)")
    else:
        print_success("No se registraron I/O waits en el perfil actual.")

    # Diagnóstico automático
    print(f"\n{BOLD}Diagnóstico automático:{RESET}")
    if pct_io > THRESHOLDS["io_wait_pct_critical"]:
        print(f"  {RED}🔴 I/O crítico ({pct_io:.1f}%){RESET}")
        print(f"  Causas probables: shared_buffers insuficiente, disco lento,")
        print(f"  queries sin índice realizando sequential scans.")
    elif pct_io > THRESHOLDS["io_wait_pct_warn"]:
        print(f"  {YELLOW}🟡 I/O elevado ({pct_io:.1f}%){RESET}")
        print(f"  Considera revisar shared_buffers y los índices de las tablas más accedidas.")
    else:
        print(f"  {GREEN}🟢 I/O normal ({pct_io:.1f}%){RESET}")

    if pct_lock > 20:
        print(f"  {RED}🔴 Lock contention alta ({pct_lock:.1f}%){RESET}")
        print(f"  Revisa transacciones largas y patrones de actualización concurrente.")


def _pws_heatmap(cur):
    cur.execute("""
        SELECT
            CASE
                WHEN event_type IS NULL    THEN 'CPU'
                WHEN event_type = 'IO'     THEN 'I/O'
                WHEN event_type = 'Lock'   THEN 'Lock'
                WHEN event_type = 'LWLock' THEN 'LWLock'
                WHEN event_type = 'Client' THEN 'Client'
                WHEN event_type = 'IPC'    THEN 'IPC'
                ELSE event_type
            END         AS categoria,
            SUM(count)  AS muestras,
            ROUND(100.0 * SUM(count) / SUM(SUM(count)) OVER (), 2) AS pct
        FROM pg_wait_sampling_profile
        GROUP BY categoria
        ORDER BY muestras DESC
    """)
    rows = cur.fetchall()
    total = sum(int(r["muestras"]) for r in rows) or 1

    print(f"\n{BOLD}Mapa de calor de eventos de espera:{RESET}")
    print(f"{DIM}(basado en {total:,} muestras del perfil acumulado){RESET}\n")
    print_separator("─")

    cat_colors = {
        "CPU":     GREEN,  "I/O":    BLUE,   "Lock":   RED,
        "LWLock":  YELLOW, "Client": CYAN,   "IPC":    MAGENTA,
    }
    for r in rows:
        cat   = str(r["categoria"])
        pct   = float(r["pct"] or 0)
        color = cat_colors.get(cat, RESET)
        width = int(pct / 100 * 50)
        bar   = "█" * width
        print(f"  {color}{cat:<10}{RESET} "
              f"{color}{bar:<50}{RESET} "
              f"{pct:>6.1f}%  ({int(r['muestras']):,})")
    print_separator("─")

    # Interpretación
    top = rows[0] if rows else None
    if top:
        cat = str(top["categoria"])
        pct = float(top["pct"] or 0)
        interp = {
            "CPU":     f"El servidor está mayormente activo procesando ({pct:.0f}%). Normal.",
            "I/O":     f"I/O dominante ({pct:.0f}%). Revisar shared_buffers e índices.",
            "Lock":    f"Lock contention alta ({pct:.0f}%). Revisar transacciones largas.",
            "LWLock":  f"LWLock frecuente ({pct:.0f}%). Posible presión en shared_buffers.",
            "Client":  f"Espera al cliente alta ({pct:.0f}%). Revisar la aplicación.",
        }
        msg = interp.get(cat, f"Esperas en {cat} ({pct:.0f}%).")
        print(f"\n  {BOLD}Interpretación:{RESET} {msg}")


def _pws_reset(cur, conn):
    confirm = input(
        f"\n{RED}¿Confirmar reset del perfil de esperas? (escribe RESET): {RESET}"
    ).strip()
    if confirm == "RESET":
        cur.execute("SELECT pg_wait_sampling_reset_profile();")
        conn.commit()
        print_success("Perfil de pg_wait_sampling reseteado.")
    else:
        print_info("Operación cancelada.")


def _print_wait_table(rows, headers):
    if not rows:
        print_info("No se encontraron datos.")
        return
    data = [list(r.values()) for r in rows]
    if TABULATE_OK:
        print(tabulate(data, headers=headers, tablefmt="simple",
                       missingval="—"))
    else:
        for row in data:
            print("  " + "  |  ".join(str(v) for v in row))
    print(f"\n  {DIM}Total: {len(rows)} registros{RESET}")


# ══════════════════════════════════════════════════════════
# OPCIÓN 3 — ANÁLISIS COMBINADO
# ══════════════════════════════════════════════════════════

def combined_analysis():
    print_separator(char="═", color=GREEN)
    print(f"{GREEN}{BOLD}  3. Análisis combinado: queries + waits{RESET}")
    print_separator(char="═", color=GREEN)

    print(f"\n  {YELLOW}[1]{RESET}  Queries lentas con su perfil de esperas")
    print(f"  {YELLOW}[2]{RESET}  Dashboard ejecutivo del sistema")
    print(f"  {YELLOW}[3]{RESET}  Generar informe de alertas automáticas")
    print(f"  {YELLOW}[4]{RESET}  Guardar snapshot actual en tabla histórica")
    print(f"  {YELLOW}[5]{RESET}  Comparar con snapshot anterior")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection()
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            _combined_slow_with_waits(cur)
        elif choice == "2":
            _dashboard(cur)
        elif choice == "3":
            _auto_alerts(cur)
        elif choice == "4":
            _save_snapshot(cur, conn)
        elif choice == "5":
            _compare_snapshot(cur)
        else:
            print_error("Opción no válida.")

        cur.close(); conn.close()
    except OperationalError as e:
        print_error(f"Error de conexión: {e}")
    except Exception as e:
        print_error(f"Error: {e}")
        import traceback; traceback.print_exc()

    wait()


def _combined_slow_with_waits(cur):
    ver_pws = check_extension(cur, "pg_wait_sampling")
    ver_pss = check_extension(cur, "pg_stat_statements")
    if not ver_pss:
        print_error("pg_stat_statements no activa.")
        return
    if not ver_pws:
        print_warn("pg_wait_sampling no activa. Solo se muestran estadísticas de ejecución.")
        _pss_top_by_total_time(cur)
        return

    n = int(input("Top N queries a analizar [10]: ").strip() or "10")
    cur.execute("""
        WITH top_q AS (
            SELECT queryid,
                LEFT(query,80) AS query_text,
                calls,
                ROUND(mean_exec_time::numeric,2) AS media_ms,
                ROUND(total_exec_time::numeric,2) AS total_ms
            FROM pg_stat_statements
            WHERE calls > 5
              AND query NOT ILIKE '%%pg_stat_statements%%'
            ORDER BY total_exec_time DESC
            LIMIT %s
        ),
        waits AS (
            SELECT queryid,
                event_type,
                event,
                SUM(count) AS waits
            FROM pg_wait_sampling_profile
            WHERE event IS NOT NULL
            GROUP BY queryid, event_type, event
        )
        SELECT
            q.query_text,
            q.calls,
            q.media_ms,
            q.total_ms,
            COALESCE(w.event_type, '—') AS wait_type,
            COALESCE(w.event, '—')      AS wait_event,
            COALESCE(w.waits, 0)        AS wait_samples
        FROM top_q q
        LEFT JOIN waits w ON w.queryid = q.queryid
        ORDER BY q.total_ms DESC, w.waits DESC NULLS LAST
    """, (n,))
    rows = cur.fetchall()

    print(f"\n{BOLD}Top {n} queries con su perfil de esperas:{RESET}")
    print_separator("─")
    for r in rows:
        wait_info = ""
        if r["wait_type"] != "—":
            wcolor = (RED    if r["wait_type"] == "Lock"   else
                      BLUE   if r["wait_type"] == "IO"     else
                      YELLOW if r["wait_type"] == "LWLock" else CYAN)
            wait_info = (f" │ {wcolor}{r['wait_type']}/{r['wait_event']}{RESET}"
                         f" ({r['wait_samples']} samples)")

        print(f"\n  {DIM}{r['query_text'][:80]}{RESET}")
        print(f"  calls={r['calls']}  "
              f"media={ms_label(float(r['media_ms']))}  "
              f"total={CYAN}{r['total_ms']} ms{RESET}"
              f"{wait_info}")


def _dashboard(cur):
    print(f"\n{BOLD}{'═'*65}{RESET}")
    print(f"{BOLD}  DASHBOARD EJECUTIVO — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{RESET}")
    print(f"{BOLD}{'═'*65}{RESET}")

    # Conexiones
    cur.execute("""
        SELECT
            COUNT(*) FILTER (WHERE state = 'active')         AS activas,
            COUNT(*) FILTER (WHERE state = 'idle')            AS idle,
            COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_tx,
            COUNT(*) FILTER (WHERE wait_event_type = 'Lock')  AS bloqueadas,
            MAX(EXTRACT(EPOCH FROM (NOW() - query_start)))
                FILTER (WHERE state = 'active')               AS max_query_secs
        FROM pg_stat_activity
        WHERE pid != pg_backend_pid()
    """)
    c = cur.fetchone()

    print(f"\n  {BOLD}📡 Conexiones:{RESET}")
    print(f"  {'Activas':<20} {GREEN}{c['activas']}{RESET}")
    print(f"  {'Idle':<20} {DIM}{c['idle']}{RESET}")
    print(f"  {'Idle in transaction':<20} "
          f"{YELLOW if int(c['idle_tx'] or 0) > 3 else DIM}"
          f"{c['idle_tx']}{RESET}")
    if int(c["bloqueadas"] or 0) > 0:
        print(f"  {'Bloqueadas':<20} {RED}{BOLD}{c['bloqueadas']}{RESET}")
    if c["max_query_secs"] and float(c["max_query_secs"]) > 30:
        secs = int(c["max_query_secs"])
        print(f"  {'Query más larga':<20} {RED}{BOLD}{secs}s{RESET}")

    # Cache hit
    cur.execute("""
        SELECT ROUND(
            100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2
        ) AS hit_ratio
        FROM pg_stat_database
        WHERE datname = current_database()
    """)
    db = cur.fetchone()
    hit = float(db["hit_ratio"] or 0)
    print(f"\n  {BOLD}💾 Cache:{RESET}")
    print(f"  {'Buffer hit ratio':<20} {pct_bar(hit)}")

    # pg_stat_statements disponible?
    ver_pss = check_extension(cur, "pg_stat_statements")
    if ver_pss:
        cur.execute("""
            SELECT LEFT(query, 60) AS q, ROUND(mean_exec_time::numeric,1) AS ms
            FROM pg_stat_statements
            WHERE calls > 5 AND query NOT ILIKE '%%pg_stat%%'
            ORDER BY mean_exec_time DESC LIMIT 1
        """)
        worst = cur.fetchone()
        if worst:
            print(f"\n  {BOLD}🐢 Query más lenta:{RESET}")
            print(f"  {ms_label(float(worst['ms']))}  {DIM}{worst['q']}{RESET}")

    # pg_wait_sampling disponible?
    ver_pws = check_extension(cur, "pg_wait_sampling")
    if ver_pws:
        cur.execute("""
            SELECT COALESCE(event_type,'CPU') AS et, COALESCE(event,'—') AS ev,
                   SUM(count) AS n
            FROM pg_wait_sampling_profile
            GROUP BY et, ev ORDER BY n DESC LIMIT 1
        """)
        top_wait = cur.fetchone()
        if top_wait:
            print(f"\n  {BOLD}⏳ Principal evento de espera:{RESET}")
            wcolor = (RED    if top_wait["et"] == "Lock"   else
                      BLUE   if top_wait["et"] == "IO"     else
                      YELLOW if top_wait["et"] == "LWLock" else GREEN)
            print(f"  {wcolor}{top_wait['et']}/{top_wait['ev']}{RESET}  "
                  f"({int(top_wait['n']):,} muestras)")
    else:
        print(f"\n  {DIM}pg_wait_sampling no activa{RESET}")

    print(f"\n{'═'*65}")


def _auto_alerts(cur):
    alerts = []

    # Queries lentas
    ver_pss = check_extension(cur, "pg_stat_statements")
    if ver_pss:
        cur.execute("""
            SELECT LEFT(query,60) AS q,
                   ROUND(mean_exec_time::numeric,1) AS ms,
                   calls
            FROM pg_stat_statements
            WHERE mean_exec_time > %s AND calls > 10
              AND query NOT ILIKE '%%pg_stat%%'
            ORDER BY mean_exec_time DESC LIMIT 5
        """, (THRESHOLDS["mean_exec_warn_ms"],))
        for r in cur.fetchall():
            sev = ("CRITICO" if float(r["ms"]) >= THRESHOLDS["mean_exec_critical_ms"]
                   else "ATENCION")
            alerts.append({
                "tipo": "QUERY LENTA",
                "detalle": r["q"],
                "valor": f"{r['ms']} ms (x{r['calls']})",
                "sev": sev,
            })

        # Cache hit
        cur.execute("""
            SELECT ROUND(100.0*blks_hit/NULLIF(blks_hit+blks_read,0),2) AS pct
            FROM pg_stat_database WHERE datname = current_database()
        """)
        r = cur.fetchone()
        if r and r["pct"] is not None:
            pct = float(r["pct"])
            if pct < THRESHOLDS["cache_hit_critical_pct"]:
                alerts.append({
                    "tipo": "CACHE HIT BAJO",
                    "detalle": f"Base de datos {DB_CONFIG['dbname']}",
                    "valor": f"{pct}%",
                    "sev": "CRITICO",
                })
            elif pct < THRESHOLDS["cache_hit_warn_pct"]:
                alerts.append({
                    "tipo": "CACHE HIT BAJO",
                    "detalle": f"Base de datos {DB_CONFIG['dbname']}",
                    "valor": f"{pct}%",
                    "sev": "ATENCION",
                })

        # Archivos temporales
        cur.execute("""
            SELECT LEFT(query,60) AS q, temp_blks_written AS t
            FROM pg_stat_statements
            WHERE temp_blks_written > %s
              AND query NOT ILIKE '%%pg_stat%%'
            ORDER BY temp_blks_written DESC LIMIT 3
        """, (THRESHOLDS["temp_blks_warn"],))
        for r in cur.fetchall():
            alerts.append({
                "tipo": "TEMP FILES",
                "detalle": r["q"],
                "valor": f"{r['t']:,} bloques",
                "sev": "ATENCION",
            })

    # Lock waits
    ver_pws = check_extension(cur, "pg_wait_sampling")
    if ver_pws:
        cur.execute("""
            SELECT SUM(count) AS n FROM pg_wait_sampling_profile
            WHERE event_type = 'Lock'
        """)
        r = cur.fetchone()
        if r and r["n"]:
            n = int(r["n"])
            if n >= THRESHOLDS["lock_waits_critical"]:
                alerts.append({
                    "tipo": "LOCK CONTENTION",
                    "detalle": "Perfil acumulado de waits",
                    "valor": f"{n:,} lock waits",
                    "sev": "CRITICO",
                })
            elif n >= THRESHOLDS["lock_waits_warn"]:
                alerts.append({
                    "tipo": "LOCK CONTENTION",
                    "detalle": "Perfil acumulado de waits",
                    "valor": f"{n:,} lock waits",
                    "sev": "ATENCION",
                })

    # Conexiones bloqueadas ahora
    cur.execute("""
        SELECT COUNT(*) AS n FROM pg_stat_activity
        WHERE wait_event_type = 'Lock' AND pid != pg_backend_pid()
    """)
    r = cur.fetchone()
    if r and int(r["n"] or 0) >= THRESHOLDS["blocked_connections_warn"]:
        alerts.append({
            "tipo": "CONEXIONES BLOQUEADAS",
            "detalle": "pg_stat_activity ahora mismo",
            "valor": f"{r['n']} conexiones",
            "sev": "CRITICO" if int(r["n"]) > 10 else "ATENCION",
        })

    # Mostrar alertas
    print(f"\n{BOLD}{'═'*65}{RESET}")
    print(f"{BOLD}  INFORME DE ALERTAS — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{RESET}")
    print(f"{BOLD}{'═'*65}{RESET}\n")

    if not alerts:
        print_success("✅ No se detectaron alertas. El sistema está dentro de los umbrales normales.")
    else:
        criticas = [a for a in alerts if a["sev"] == "CRITICO"]
        atenciones = [a for a in alerts if a["sev"] == "ATENCION"]
        print(f"  {RED}{BOLD}{len(criticas)} alertas críticas{RESET}  "
              f"{YELLOW}{len(atenciones)} alertas de atención{RESET}\n")
        print_separator("─")
        for a in sorted(alerts, key=lambda x: x["sev"]):
            icon  = severity_icon(a["sev"])
            color = severity_color(a["sev"])
            print(f"\n  {icon} {color}[{a['sev']}]{RESET}  {BOLD}{a['tipo']}{RESET}")
            print(f"     {DIM}{a['detalle']}{RESET}")
            print(f"     Valor: {CYAN}{a['valor']}{RESET}")
    print_separator("─")


def _save_snapshot(cur, conn):
    """Guarda un snapshot de pg_stat_statements en una tabla histórica."""
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS mon_snapshot_pss (
                snapshot_id   SERIAL,
                captured_at   TIMESTAMP DEFAULT NOW(),
                queryid       BIGINT,
                query         TEXT,
                calls         BIGINT,
                total_exec_time FLOAT8,
                mean_exec_time  FLOAT8,
                stddev_exec_time FLOAT8,
                rows          BIGINT,
                shared_blks_read BIGINT,
                shared_blks_hit  BIGINT,
                temp_blks_written BIGINT
            );
        """)

        ver_pss = check_extension(cur, "pg_stat_statements")
        if not ver_pss:
            print_error("pg_stat_statements no activa.")
            return

        cur.execute("""
            INSERT INTO mon_snapshot_pss
                (queryid, query, calls, total_exec_time, mean_exec_time,
                 stddev_exec_time, rows, shared_blks_read, shared_blks_hit,
                 temp_blks_written)
            SELECT queryid, LEFT(query,200), calls, total_exec_time,
                   mean_exec_time, stddev_exec_time, rows,
                   shared_blks_read, shared_blks_hit, temp_blks_written
            FROM pg_stat_statements
            WHERE query NOT ILIKE '%%pg_stat_statements%%'
        """)
        count = cur.rowcount
        conn.commit()
        print_success(
            f"Snapshot guardado: {count} queries en 'mon_snapshot_pss' "
            f"a las {datetime.now().strftime('%H:%M:%S')}."
        )
    except Exception as e:
        conn.rollback()
        print_error(f"Error al guardar snapshot: {e}")


def _compare_snapshot(cur):
    """Compara el estado actual con el snapshot más reciente."""
    try:
        cur.execute("""
            SELECT COUNT(*), MAX(captured_at) AS last_snapshot
            FROM mon_snapshot_pss
        """)
        r = cur.fetchone()
        if not r or int(r["count"] or 0) == 0:
            print_warn("No hay snapshots guardados. Usa la opción [4] primero.")
            return

        print_info(
            f"Comparando estado actual con snapshot de {r['last_snapshot']}"
        )

        cur.execute("""
            SELECT
                curr.queryid,
                LEFT(curr.query, 80)                        AS query,
                curr.calls - base.calls                      AS calls_nuevas,
                ROUND((curr.mean_exec_time
                       - base.mean_exec_time)::numeric, 2)  AS delta_media_ms,
                ROUND(
                    100.0 * (curr.mean_exec_time - base.mean_exec_time)
                    / NULLIF(base.mean_exec_time, 0), 1
                )                                            AS pct_cambio
            FROM pg_stat_statements curr
            JOIN (
                SELECT DISTINCT ON (queryid) *
                FROM mon_snapshot_pss
                ORDER BY queryid, captured_at DESC
            ) base ON base.queryid = curr.queryid
            WHERE ABS(curr.mean_exec_time - base.mean_exec_time) > 20
              AND curr.calls > base.calls
            ORDER BY ABS(pct_cambio) DESC NULLS LAST
            LIMIT 15
        """)
        rows = cur.fetchall()

        print(f"\n{BOLD}Cambios en tiempo medio de ejecución vs snapshot:{RESET}")
        print_separator("─")
        if not rows:
            print_success("No se detectaron cambios significativos (>20ms).")
        else:
            for r in rows:
                delta = float(r["delta_media_ms"] or 0)
                pct   = float(r["pct_cambio"] or 0)
                arrow = f"{RED}▲ +{delta:.1f}ms (+{pct:.0f}%){RESET}" \
                        if delta > 0 \
                        else f"{GREEN}▼ {delta:.1f}ms ({pct:.0f}%){RESET}"
                print(f"\n  {DIM}{str(r['query'])[:78]}{RESET}")
                print(f"  {arrow}  ({int(r['calls_nuevas'] or 0)} llamadas nuevas)")
    except psycopg2.errors.UndefinedTable:
        print_warn("Tabla 'mon_snapshot_pss' no existe. Usa la opción [4] para crear un snapshot.")


# ══════════════════════════════════════════════════════════
# OPCIÓN 4 — MONITORIZACIÓN EN TIEMPO REAL
# ══════════════════════════════════════════════════════════

def realtime_monitor():
    print_separator(char="═", color=RED)
    print(f"{RED}{BOLD}  4. Monitorización en tiempo real (actualización cada N segundos){RESET}")
    print_separator(char="═", color=RED)

    try:
        interval = int(
            input(f"Intervalo de actualización en segundos [5]: ").strip() or "5"
        )
        cycles = int(
            input(f"Número de ciclos [0 = continuo, Ctrl+C para parar]: ").strip()
            or "0"
        )
    except ValueError:
        interval, cycles = 5, 0

    print(f"\n{YELLOW}Iniciando monitorización. Pulsa Ctrl+C para detener.{RESET}\n")
    time.sleep(1)

    cycle_count = 0
    try:
        while True:
            cycle_count += 1
            if cycles > 0 and cycle_count > cycles:
                break

            try:
                conn = get_connection()
                cur  = conn.cursor(cursor_factory=RealDictCursor)

                # Limpiar pantalla
                print("\033[2J\033[H", end="")

                now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                print(f"{BOLD}{'═'*65}{RESET}")
                print(f"{BOLD}  MONITORIZACIÓN EN TIEMPO REAL — {now}{RESET}")
                print(f"{DIM}  Ciclo {cycle_count}  |  Intervalo {interval}s  "
                      f"|  Ctrl+C para parar{RESET}")
                print(f"{BOLD}{'═'*65}{RESET}\n")

                # Conexiones activas
                cur.execute("""
                    SELECT state, wait_event_type, wait_event,
                           LEFT(query, 55) AS q,
                           EXTRACT(EPOCH FROM (NOW()-query_start))::int AS secs
                    FROM pg_stat_activity
                    WHERE pid != pg_backend_pid()
                      AND state != 'idle'
                    ORDER BY secs DESC NULLS LAST
                    LIMIT 8
                """)
                active = cur.fetchall()
                print(f"{BOLD}Procesos activos ({len(active)}):{RESET}")
                for p in active:
                    wt = p["wait_event_type"] or ""
                    we = p["wait_event"] or ""
                    color = (RED    if wt == "Lock"   else
                             BLUE   if wt == "IO"     else
                             YELLOW if wt == "LWLock" else
                             GREEN  if wt == ""       else CYAN)
                    wait_str = f"{color}{wt}/{we}{RESET}" if wt else f"{GREEN}CPU{RESET}"
                    print(f"  {wait_str:<30} {DIM}{p['secs'] or 0}s{RESET}  {DIM}{p['q']}{RESET}")

                # Top waits en tiempo real (si disponible)
                ver_pws = check_extension(cur, "pg_wait_sampling")
                if ver_pws:
                    cur.execute("""
                        SELECT COALESCE(event_type,'CPU') AS et,
                               COALESCE(event,'activo') AS ev,
                               COUNT(*) AS n
                        FROM pg_wait_sampling_history
                        GROUP BY et, ev
                        ORDER BY n DESC LIMIT 5
                    """)
                    waits = cur.fetchall()
                    print(f"\n{BOLD}Top waits (historial reciente):{RESET}")
                    for w in waits:
                        c = (RED if w["et"]=="Lock" else BLUE if w["et"]=="IO"
                             else YELLOW if w["et"]=="LWLock" else GREEN)
                        bar = "█" * min(int(w["n"]) // 5, 30)
                        print(f"  {c}{str(w['et']):<10}{RESET} {str(w['ev']):<28} "
                              f"{c}{bar}{RESET} {w['n']}")

                cur.close(); conn.close()

            except Exception as e:
                print_error(f"Error en ciclo {cycle_count}: {e}")

            time.sleep(interval)

    except KeyboardInterrupt:
        print(f"\n\n{GREEN}Monitorización detenida.{RESET}")

    wait()


# ══════════════════════════════════════════════════════════
# MENÚ PRINCIPAL
# ══════════════════════════════════════════════════════════

BANNER = f"""
{MAGENTA}{BOLD}╔══════════════════════════════════════════════════════════════╗
║   PostgreSQL Advanced Monitoring Manager                    ║
║   pg_stat_statements  +  pg_wait_sampling                   ║
╚══════════════════════════════════════════════════════════════╝{RESET}
"""

MENU = f"""
{CYAN}{BOLD}── MENÚ PRINCIPAL ──────────────────────────────────────────{RESET}

  {YELLOW}[0]{RESET}  Instalar / Verificar extensiones        ← {RED}Empieza aquí{RESET}
  {YELLOW}[1]{RESET}  {BLUE}pg_stat_statements{RESET} — Análisis de queries
       └─ Lentas · I/O · Temp files · Cache hit · WAL · Resumen global
  {YELLOW}[2]{RESET}  {MAGENTA}pg_wait_sampling{RESET} — Eventos de espera
       └─ Distribución · Historial · Lock contention · I/O waits · Heatmap
  {YELLOW}[3]{RESET}  {GREEN}Análisis combinado{RESET} — Queries + Waits
       └─ Dashboard ejecutivo · Alertas automáticas · Snapshots históricos
  {YELLOW}[4]{RESET}  {RED}Monitorización en tiempo real{RESET} (live refresh)
  {YELLOW}[q]{RESET}  Salir

{CYAN}────────────────────────────────────────────────────────────{RESET}
"""


def _startup_check():
    """Comprobación rápida de extensiones al arrancar."""
    try:
        conn = get_connection()
        cur  = conn.cursor()
        ver_pss = check_extension(cur, "pg_stat_statements")
        ver_pws = check_extension(cur, "pg_wait_sampling")
        cur.execute("SHOW server_version;")
        pg_ver = cur.fetchone()[0].split(" ")[0]
        cur.close(); conn.close()

        print(f"\n{BOLD}Estado del entorno:{RESET}")
        print(f"  PostgreSQL         : {CYAN}{pg_ver}{RESET}")
        print(f"  pg_stat_statements : "
              f"{GREEN + '✔ Activa v' + ver_pss + RESET if ver_pss else RED + '✗ No activa → opción [0]' + RESET}")
        print(f"  pg_wait_sampling   : "
              f"{GREEN + '✔ Activa v' + ver_pws + RESET if ver_pws else YELLOW + '⚠ No activa → opción [0]' + RESET}")
        if not TABULATE_OK:
            print(f"  tabulate           : {YELLOW}⚠ pip install tabulate (tablas más legibles){RESET}")
    except OperationalError as e:
        print_error(f"No se pudo conectar a PostgreSQL: {e}")
        print(f"  {YELLOW}Edita DB_CONFIG al inicio del script.{RESET}")


def main():
    print(BANNER)
    print(f"{CYAN}Configuración de conexión:{RESET}")
    print(f"  Host   : {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print(f"  Usuario: {DB_CONFIG['user']}")
    print(f"  BD     : {BOLD}{DB_CONFIG['dbname']}{RESET}")
    print(f"\n{YELLOW}ℹ  Edita DB_CONFIG al inicio del script para cambiar la conexión.{RESET}")

    _startup_check()

    while True:
        print(MENU)
        choice = input(f"{BOLD}Elige una opción: {RESET}").strip().lower()

        if   choice in ("q", "quit", "exit"):
            print(f"\n{GREEN}¡Hasta luego!{RESET}\n")
            sys.exit(0)
        elif choice == "0": install_extensions()
        elif choice == "1": analyze_slow_queries()
        elif choice == "2": analyze_wait_events()
        elif choice == "3": combined_analysis()
        elif choice == "4": realtime_monitor()
        else: print(f"\n{RED}Opción no válida.{RESET}")


if __name__ == "__main__":
    main()
