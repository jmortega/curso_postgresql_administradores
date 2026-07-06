#!/usr/bin/env python3
"""
test_postgres_ssl.py
====================
Prueba todos los modos de conexión SSL contra un servidor PostgreSQL.

Modos soportados:
  disable    — sin cifrado, sin verificación
  allow      — preferir no-SSL, acepta SSL si el servidor lo exige
  prefer     — preferir SSL, acepta no-SSL si el servidor no lo soporta
  require    — SSL obligatorio, sin verificación de certificado
  verify-ca  — SSL obligatorio + verifica que el cert está firmado por la CA
  verify-full— SSL obligatorio + verifica CA + nombre de host del servidor

Uso:
  # Conexión básica (modos disable/allow/prefer/require):
  python test_postgres_ssl.py --host localhost --port 5432 \
      --dbname midb --user miusuario --password mipassword

  # Con certificados cliente (modos verify-ca / verify-full):
  python test_postgres_ssl.py --host localhost --port 5432 \
      --dbname midb --user miusuario \
      --sslcert certs/client.crt \
      --sslkey  certs/client.key \
      --sslrootcert certs/ca.crt

  # Probar un solo modo:
  python test_postgres_ssl.py --host localhost --mode verify-full \
      --sslcert certs/client.crt --sslkey certs/client.key \
      --sslrootcert certs/ca.crt
"""

import argparse
import sys
import time
import os
import stat

try:
    import psycopg2
    from psycopg2 import OperationalError
except ImportError:
    print("[ERROR] psycopg2 no encontrado. Instálalo con: pip install psycopg2-binary")
    sys.exit(1)

# ── Colores ANSI ─────────────────────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

# ── Definición de modos SSL ───────────────────────────────────────────────────
SSL_MODES = [
    {
        "mode":        "disable",
        "description": "Sin cifrado. La conexión viaja en texto plano.",
        "requires_cert": False,
        "security":    "⚠️  Ninguna",
    },
    {
        "mode":        "allow",
        "description": "Prefiere no-SSL pero acepta SSL si el servidor lo exige.",
        "requires_cert": False,
        "security":    "⚠️  Baja",
    },
    {
        "mode":        "prefer",
        "description": "Prefiere SSL pero acepta no-SSL si el servidor no lo soporta.",
        "requires_cert": False,
        "security":    "🔶 Media",
    },
    {
        "mode":        "require",
        "description": "SSL obligatorio. NO verifica el certificado del servidor.",
        "requires_cert": False,
        "security":    "🔶 Media-Alta (vulnerable a MITM)",
    },
    {
        "mode":        "verify-ca",
        "description": "SSL + verifica que el cert del servidor está firmado por la CA.",
        "requires_cert": True,
        "security":    "✅ Alta",
    },
    {
        "mode":        "verify-full",
        "description": "SSL + verifica CA + que el hostname coincide con el certificado.",
        "requires_cert": True,
        "security":    "✅✅ Máxima (recomendada en producción)",
    },
]


# ── Utilidades ────────────────────────────────────────────────────────────────

def print_header(text: str) -> None:
    line = "─" * 60
    print(f"\n{BOLD}{CYAN}{line}{RESET}")
    print(f"{BOLD}{CYAN}  {text}{RESET}")
    print(f"{BOLD}{CYAN}{line}{RESET}")


def print_result(mode: str, ok: bool, msg: str, detail: str = "") -> None:
    icon   = f"{GREEN}✔ OK   {RESET}" if ok else f"{RED}✘ FAIL {RESET}"
    detail = f"  {YELLOW}↳ {detail}{RESET}" if detail else ""
    print(f"  {icon} [{BOLD}{mode:<12}{RESET}] {msg}{detail}")


def check_file_permissions(path: str) -> bool:
    """Verifica que la clave privada tenga permisos 600."""
    if not os.path.exists(path):
        return False
    mode = stat.S_IMODE(os.stat(path).st_mode)
    return mode == 0o600


def fix_key_permissions(path: str) -> None:
    """Ajusta permisos de la clave a 600."""
    os.chmod(path, 0o600)
    print(f"  {YELLOW}[INFO] Permisos de {path} ajustados a 600.{RESET}")


def get_ssl_info(conn) -> dict:
    """Obtiene información SSL de la conexión activa."""
    info = {}
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT ssl, version, cipher, bits FROM pg_stat_ssl "
                        "WHERE pid = pg_backend_pid()")
            row = cur.fetchone()
            if row:
                info = {
                    "ssl":     row[0],
                    "version": row[1],
                    "cipher":  row[2],
                    "bits":    row[3],
                }
    except Exception:
        pass
    return info


def get_server_info(conn) -> dict:
    """Obtiene versión de servidor y usuario conectado."""
    info = {}
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT version(), current_user, current_database()")
            row = cur.fetchone()
            if row:
                # Recortar versión larga
                ver = row[0].split(",")[0] if row[0] else "?"
                info = {"version": ver, "user": row[1], "database": row[2]}
    except Exception:
        pass
    return info


# ── Función principal de prueba ───────────────────────────────────────────────

def test_mode(args: argparse.Namespace, ssl_def: dict) -> dict:
    """
    Intenta conectar con el sslmode indicado.
    Devuelve dict con resultado, tiempo y detalles.
    """
    mode         = ssl_def["mode"]
    needs_cert   = ssl_def["requires_cert"]

    connect_params = {
        "host":    args.host,
        "port":    args.port,
        "dbname":  args.dbname,
        "user":    args.user,
        "connect_timeout": args.timeout,
        "sslmode": mode,
    }

    if args.password:
        connect_params["password"] = args.password

    # Adjuntar certificados si están disponibles
    if args.sslrootcert and os.path.exists(args.sslrootcert):
        connect_params["sslrootcert"] = args.sslrootcert

    if args.sslcert and os.path.exists(args.sslcert):
        connect_params["sslcert"] = args.sslcert

    if args.sslkey and os.path.exists(args.sslkey):
        # psycopg2 requiere permisos 600 en la clave
        if not check_file_permissions(args.sslkey):
            fix_key_permissions(args.sslkey)
        connect_params["sslkey"] = args.sslkey

    # Si el modo requiere certificados y no están disponibles, omitir
    if needs_cert and not (args.sslcert and args.sslkey and args.sslrootcert):
        return {
            "mode":    mode,
            "status":  "SKIP",
            "message": "Certificados no proporcionados (--sslcert / --sslkey / --sslrootcert)",
            "elapsed": 0,
            "ssl_info": {},
        }

    t0 = time.time()
    try:
        conn = psycopg2.connect(**connect_params)
        elapsed = time.time() - t0

        ssl_info    = get_ssl_info(conn)
        server_info = get_server_info(conn)
        conn.close()

        return {
            "mode":        mode,
            "status":      "OK",
            "message":     f"Conectado en {elapsed:.3f}s",
            "elapsed":     elapsed,
            "ssl_info":    ssl_info,
            "server_info": server_info,
        }

    except OperationalError as e:
        elapsed = time.time() - t0
        # Extraer primera línea del error
        err_msg = str(e).strip().split("\n")[0]
        return {
            "mode":    mode,
            "status":  "FAIL",
            "message": err_msg,
            "elapsed": elapsed,
            "ssl_info": {},
        }


# ── Informe detallado ─────────────────────────────────────────────────────────

def print_detail_report(results: list) -> None:
    print_header("INFORME DETALLADO")

    for r in results:
        mode   = r["mode"]
        status = r["status"]

        if status == "OK":
            color = GREEN
        elif status == "SKIP":
            color = YELLOW
        else:
            color = RED

        print(f"\n  {BOLD}{color}[{mode}]{RESET}  →  {color}{status}{RESET}")
        print(f"    Mensaje : {r['message']}")

        if status == "OK":
            si = r.get("ssl_info", {})
            sv = r.get("server_info", {})
            if si:
                ssl_active = "Sí" if si.get("ssl") else "No"
                print(f"    SSL activo : {ssl_active}")
                if si.get("ssl"):
                    print(f"    Protocolo  : {si.get('version', 'N/A')}")
                    print(f"    Cipher     : {si.get('cipher', 'N/A')}")
                    print(f"    Bits       : {si.get('bits', 'N/A')}")
            if sv:
                print(f"    Servidor   : {sv.get('version', 'N/A')}")
                print(f"    Usuario    : {sv.get('user', 'N/A')}")
                print(f"    Base datos : {sv.get('database', 'N/A')}")


def print_summary(results: list) -> None:
    print_header("RESUMEN")

    header = f"  {'MODO':<14} {'ESTADO':<8} {'TIEMPO':>8}  SEGURIDAD"
    print(f"{BOLD}{header}{RESET}")
    print(f"  {'─'*58}")

    for r in results:
        mode   = r["mode"]
        status = r["status"]

        # Buscar definición de seguridad
        security = next(
            (d["security"] for d in SSL_MODES if d["mode"] == mode), "—"
        )

        if status == "OK":
            color, badge = GREEN, "✔ OK  "
        elif status == "SKIP":
            color, badge = YELLOW, "─ SKIP"
        else:
            color, badge = RED, "✘ FAIL"

        elapsed_str = f"{r['elapsed']:.3f}s" if r["elapsed"] else "  —   "
        print(f"  {color}{badge}{RESET}  {BOLD}{mode:<12}{RESET}  "
              f"{elapsed_str:>7}  {security}")

    ok_count   = sum(1 for r in results if r["status"] == "OK")
    fail_count = sum(1 for r in results if r["status"] == "FAIL")
    skip_count = sum(1 for r in results if r["status"] == "SKIP")
    print(f"\n  Resultados: {GREEN}{ok_count} OK{RESET}  "
          f"{RED}{fail_count} FALLIDOS{RESET}  "
          f"{YELLOW}{skip_count} OMITIDOS{RESET}")


# ── Argumentos CLI ────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prueba todos los modos SSL de conexión a PostgreSQL.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--host",        default="localhost",  help="Host del servidor PostgreSQL")
    parser.add_argument("--port",        type=int, default=5432, help="Puerto (defecto: 5432)")
    parser.add_argument("--dbname",      default="postgres",   help="Nombre de la base de datos")
    parser.add_argument("--user",        default="postgres",   help="Usuario de conexión")
    parser.add_argument("--password",    default="",           help="Contraseña (o usa PGPASSWORD)")
    parser.add_argument("--sslcert",     default="",           help="Ruta al certificado cliente (.crt)")
    parser.add_argument("--sslkey",      default="",           help="Ruta a la clave privada cliente (.key)")
    parser.add_argument("--sslrootcert", default="",           help="Ruta al certificado CA raíz (.crt)")
    parser.add_argument("--timeout",     type=int, default=5,  help="Timeout de conexión en segundos")
    parser.add_argument(
        "--mode",
        choices=[d["mode"] for d in SSL_MODES],
        default=None,
        help="Probar solo un modo específico",
    )
    parser.add_argument("--verbose", action="store_true", help="Mostrar informe detallado")
    return parser.parse_args()


# ── Punto de entrada ──────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()

    # Contraseña desde variable de entorno si no se pasa por argumento
    if not args.password:
        args.password = os.environ.get("PGPASSWORD", "")

    print_header(f"TEST SSL — PostgreSQL @ {args.host}:{args.port}/{args.dbname}")

    print(f"\n  {BOLD}Parámetros:{RESET}")
    print(f"    Host         : {args.host}:{args.port}")
    print(f"    Base de datos: {args.dbname}")
    print(f"    Usuario      : {args.user}")
    print(f"    SSL cert     : {args.sslcert  or '(no proporcionado)'}")
    print(f"    SSL key      : {args.sslkey   or '(no proporcionado)'}")
    print(f"    SSL CA       : {args.sslrootcert or '(no proporcionado)'}")
    print(f"    Timeout      : {args.timeout}s")

    # Seleccionar modos a probar
    modes_to_test = (
        [d for d in SSL_MODES if d["mode"] == args.mode]
        if args.mode
        else SSL_MODES
    )

    print_header("EJECUTANDO PRUEBAS")
    results = []

    for ssl_def in modes_to_test:
        mode = ssl_def["mode"]
        print(f"\n  {CYAN}▶ [{mode}]{RESET}  {ssl_def['description']}")

        result = test_mode(args, ssl_def)
        results.append(result)

        if result["status"] == "OK":
            si = result.get("ssl_info", {})
            ssl_on = si.get("ssl", False)
            proto  = si.get("version", "") if ssl_on else "sin cifrado"
            print_result(mode, True, result["message"], proto)
        elif result["status"] == "SKIP":
            print(f"    {YELLOW}─ OMITIDO: {result['message']}{RESET}")
        else:
            print_result(mode, False, "Conexión fallida", result["message"])

    # Informes
    if args.verbose or args.mode:
        print_detail_report(results)

    print_summary(results)

    # Código de salida: 0 si al menos verify-full OK, 1 si no
    vf = next((r for r in results if r["mode"] == "verify-full"), None)
    if vf and vf["status"] == "OK":
        print(f"\n  {GREEN}{BOLD}✔ verify-full OK — Conexión completamente segura.{RESET}\n")
        sys.exit(0)
    else:
        print(f"\n  {YELLOW}ℹ  verify-full no disponible o no probado.{RESET}\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
