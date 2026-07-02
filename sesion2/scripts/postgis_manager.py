"""
=============================================================
  PostGIS Geospatial Manager
  Script interactivo para gestión de datos geoespaciales
  con PostgreSQL + PostGIS
=============================================================

Requisitos:
    pip install psycopg2-binary shapely folium
"""

import sys
import json
import random
import math
import subprocess
import platform
import shutil
from datetime import datetime, timedelta
import os

try:
    import psycopg2
    from psycopg2 import sql, OperationalError
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("\n[ERROR] psycopg2 no está instalado.")
    print("Ejecuta: pip install psycopg2-binary")
    sys.exit(1)

try:
    from shapely.geometry import Point, LineString, Polygon, mapping
    from shapely.ops import unary_union
    SHAPELY_OK = True
except ImportError:
    SHAPELY_OK = False
    print("[AVISO] shapely no disponible. Algunas funciones estarán limitadas.")

try:
    import folium
    FOLIUM_OK = True
except ImportError:
    FOLIUM_OK = False
    print("[AVISO] folium no disponible. Los mapas HTML no se generarán.")

# ── Colores ANSI ──────────────────────────────────────────
RED    = "\033[91m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

# ── Configuración ─────────────────────────────────────────
DB_CONFIG = {
    "host":     os.environ.get("PG_HOST",     "localhost"),
    "port":     int(os.environ.get("PG_PORT", "5432")),
    "user":     os.environ.get("PG_USER",     "postgres"),
    "password": os.environ.get("PG_PASSWORD", "postgres_lab"),
    "dbname":   os.environ.get("PG_DBNAME",   "postgres"),
}

TARGET_DB = "postgis_geo_db"

# ══════════════════════════════════════════════════════════
# DATOS DE MUESTRA — Ciudades, POIs, rutas, zonas
# ══════════════════════════════════════════════════════════

# Ciudades españolas con coordenadas reales (lon, lat)
CIUDADES = {
    "Madrid":      (-3.7038,  40.4168),
    "Barcelona":   ( 2.1734,  41.3851),
    "Valencia":    (-0.3763,  39.4699),
    "Sevilla":     (-5.9845,  37.3891),
    "Zaragoza":    (-0.8773,  41.6488),
    "Málaga":      (-4.4214,  36.7213),
    "Murcia":      (-1.1307,  37.9922),
    "Palma":       ( 2.6502,  39.5696),
    "Las Palmas":  (-15.4138, 28.1248),
    "Bilbao":      (-2.9253,  43.2630),
    "Alicante":    (-0.4810,  38.3452),
    "Córdoba":     (-4.7794,  37.8882),
    "Valladolid":  (-4.7245,  41.6523),
    "Vigo":        (-8.7207,  42.2328),
    "Gijón":       (-5.6611,  43.5453),
}

CATEGORIAS_POI = [
    "hospital", "farmacia", "supermercado", "restaurante",
    "hotel", "museo", "parque", "gasolinera", "banco",
    "universidad", "estacion_tren", "aeropuerto"
]

TIPOS_RUTA = ["autopista", "nacional", "comarcal", "ciclista", "senderismo"]

TIPOS_ZONA = [
    "zona_residencial", "zona_comercial", "zona_industrial",
    "parque_natural", "area_protegida", "municipio"
]

NOMBRES_POI = [
    "Centro Médico {ciudad}", "Farmacia {ciudad} Norte", "Mercadona {ciudad}",
    "Restaurante El Rincón", "Hotel Plaza {ciudad}", "Museo de {ciudad}",
    "Parque de la Paz", "Repsol {ciudad}", "Banco Santander {ciudad}",
    "Universidad de {ciudad}", "Estación AVE {ciudad}", "Aeropuerto {ciudad}"
]


# ══════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════

def get_connection(dbname=None):
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


def rand_offset(center_lon, center_lat, max_deg=0.15):
    """Genera coordenadas aleatorias cerca de un punto central."""
    lon = center_lon + random.uniform(-max_deg, max_deg)
    lat = center_lat + random.uniform(-max_deg * 0.7, max_deg * 0.7)
    return round(lon, 6), round(lat, 6)


def haversine_km(lon1, lat1, lon2, lat2):
    """Distancia aproximada en km entre dos puntos (Haversine)."""
    R = 6371
    dlon = math.radians(lon2 - lon1)
    dlat = math.radians(lat2 - lat1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * \
        math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    return R * 2 * math.asin(math.sqrt(a))



# ══════════════════════════════════════════════════════════
# OPCIÓN 0 — INSTALAR / VERIFICAR POSTGIS EN EL SISTEMA
# ══════════════════════════════════════════════════════════

def _run_cmd(cmd, use_sudo=False, capture=True):
    """Ejecuta un comando del sistema y devuelve (returncode, stdout, stderr)."""
    if use_sudo and shutil.which("sudo"):
        cmd = ["sudo"] + cmd
    try:
        result = subprocess.run(
            cmd,
            capture_output=capture,
            text=True,
            timeout=300
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Tiempo de espera agotado (300s)."
    except FileNotFoundError:
        return -1, "", f"Comando no encontrado: {cmd[0]}"


def _detect_pg_version():
    """Detecta la versión mayor de PostgreSQL instalada."""
    # Intentar desde psql
    for cmd in [["psql", "--version"], ["pg_config", "--version"]]:
        rc, out, _ = _run_cmd(cmd)
        if rc == 0 and out:
            import re
            m = re.search(r"(\d+)\.", out)
            if m:
                return int(m.group(1))
    # Intentar desde el servidor al que nos conectamos
    try:
        conn = get_connection()
        cur  = conn.cursor()
        cur.execute("SHOW server_version;")
        ver = cur.fetchone()[0]
        cur.close(); conn.close()
        import re
        m = re.search(r"(\d+)\.", ver)
        if m:
            return int(m.group(1))
    except Exception:
        pass
    return None


def _postgis_is_installed_on_os():
    """Comprueba si el archivo postgis.control existe en el sistema."""
    pg_ver = _detect_pg_version()
    candidates = []
    if pg_ver:
        candidates += [
            f"/usr/share/postgresql/{pg_ver}/extension/postgis.control",
            f"/usr/share/postgresql/extension/postgis.control",
        ]
    candidates += [
        "/usr/share/postgresql/extension/postgis.control",
        "/usr/local/share/postgresql/extension/postgis.control",
    ]
    # macOS Homebrew paths
    for prefix in ["/opt/homebrew", "/usr/local"]:
        candidates.append(
            f"{prefix}/share/postgresql@{pg_ver}/extension/postgis.control"
            if pg_ver else f"{prefix}/share/postgresql/extension/postgis.control"
        )
    import os
    return any(os.path.exists(p) for p in candidates), pg_ver


def _postgis_extension_active(dbname=None):
    """Comprueba si la extensión postgis ya está activa en la BD."""
    try:
        conn = get_connection(dbname=dbname or TARGET_DB)
        cur  = conn.cursor()
        cur.execute(
            "SELECT extversion FROM pg_extension WHERE extname = 'postgis';"
        )
        row = cur.fetchone()
        cur.close(); conn.close()
        return row[0] if row else None
    except Exception:
        return None


def install_postgis():
    """
    Opción 0 — Detecta, instala y activa PostGIS:
      1. Comprueba si PostGIS ya está activo en la BD.
      2. Comprueba si está instalado en el SO.
      3. Si no, ofrece instalarlo con el gestor de paquetes del SO.
      4. Activa la extensión en la BD destino.
    """
    print_separator()
    print(f"{BOLD}0. Instalar / Verificar PostGIS en el sistema{RESET}\n")

    sistema = platform.system()   # 'Linux', 'Darwin', 'Windows'
    print(f"  Sistema operativo : {CYAN}{sistema} {platform.release()}{RESET}")

    # ── Paso 1: ¿Ya está activo en la BD? ────────────────
    ver_activa = _postgis_extension_active()
    if ver_activa:
        print_success(
            f"PostGIS ya está activo en '{TARGET_DB}' "
            f"(versión {ver_activa}). No se necesita ninguna acción."
        )
        wait()
        return

    # ── Paso 2: ¿Está instalado en el SO? ─────────────────
    installed_os, pg_ver = _postgis_is_installed_on_os()
    print(f"  PostgreSQL detectado : versión {CYAN}{pg_ver or 'desconocida'}{RESET}")
    print(f"  PostGIS en el SO     : "
          f"{'✔ Instalado' if installed_os else RED + '✗ No encontrado' + RESET}")

    if installed_os:
        print_info(
            "PostGIS está instalado en el SO pero no activado en la BD.\n"
            "  Procediendo a activar la extensión en la base de datos..."
        )
        _activate_extension()
        wait()
        return

    # ── Paso 3: Instalar PostGIS en el SO ─────────────────
    print(f"\n{YELLOW}PostGIS no está instalado en el sistema.{RESET}")
    print(f"Se intentará instalar automáticamente.\n")

    if sistema == "Linux":
        _install_linux(pg_ver)
    elif sistema == "Darwin":
        _install_macos(pg_ver)
    elif sistema == "Windows":
        _install_windows()
    else:
        print_error(f"Sistema '{sistema}' no soportado para instalación automática.")
        _print_manual_instructions(sistema, pg_ver)
        wait()
        return

    # ── Paso 4: Verificar y activar ───────────────────────
    installed_after, _ = _postgis_is_installed_on_os()
    if installed_after:
        print_success("PostGIS instalado en el SO correctamente.")
        _activate_extension()
    else:
        print_error(
            "No se pudo verificar la instalación de PostGIS.\n"
            "  Puede que necesites permisos de administrador (sudo).\n"
            "  Consulta las instrucciones manuales a continuación."
        )
        _print_manual_instructions(sistema, pg_ver)

    wait()


def _install_linux(pg_ver):
    """Intenta instalar PostGIS en sistemas Linux."""
    # Detectar gestor de paquetes
    distro_info = ""
    try:
        import os
        if os.path.exists("/etc/os-release"):
            with open("/etc/os-release") as f:
                distro_info = f.read().lower()
    except Exception:
        pass

    is_debian = (
        shutil.which("apt-get") is not None or
        "debian" in distro_info or "ubuntu" in distro_info
    )
    is_redhat = (
        shutil.which("dnf") is not None or
        shutil.which("yum") is not None or
        "fedora" in distro_info or "centos" in distro_info or
        "rhel" in distro_info
    )
    is_arch = shutil.which("pacman") is not None

    pkg_ver = str(pg_ver) if pg_ver else "16"

    if is_debian:
        pkg = f"postgresql-{pkg_ver}-postgis-3"
        print(f"{CYAN}Distribución Debian/Ubuntu detectada.{RESET}")
        print(f"Paquete a instalar: {BOLD}{pkg}{RESET}")
        confirm = input(
            f"\n{YELLOW}¿Ejecutar 'sudo apt-get install {pkg}'? (s/n): {RESET}"
        ).strip().lower()
        if confirm != "s":
            print_info("Instalación cancelada.")
            _print_manual_instructions("Linux-Debian", pg_ver)
            return

        print(f"\n{YELLOW}⏳ Actualizando lista de paquetes...{RESET}")
        rc, _, err = _run_cmd(["apt-get", "update", "-qq"], use_sudo=True)
        if rc != 0:
            print_error(f"Error en apt-get update: {err}")

        print(f"{YELLOW}⏳ Instalando {pkg}...{RESET}")
        rc, out, err = _run_cmd(
            ["apt-get", "install", "-y", pkg], use_sudo=True, capture=False
        )
        if rc == 0:
            print_success(f"Paquete '{pkg}' instalado correctamente.")
        else:
            print_error(f"Error instalando '{pkg}': {err}")
            # Intentar con postgis-3 genérico
            print(f"{YELLOW}Intentando con paquete genérico 'postgis'...{RESET}")
            rc2, _, err2 = _run_cmd(
                ["apt-get", "install", "-y", "postgis"], use_sudo=True, capture=False
            )
            if rc2 == 0:
                print_success("Paquete 'postgis' instalado.")
            else:
                print_error(f"Instalación fallida: {err2}")
                _print_manual_instructions("Linux-Debian", pg_ver)

    elif is_redhat:
        pkg = f"postgis33_{pkg_ver.replace('.','')}"
        manager = "dnf" if shutil.which("dnf") else "yum"
        print(f"{CYAN}Distribución RedHat/Fedora/CentOS detectada.{RESET}")
        print(f"Gestor de paquetes: {BOLD}{manager}{RESET}")
        print(f"Paquete sugerido  : {BOLD}{pkg}{RESET}")
        confirm = input(
            f"\n{YELLOW}¿Ejecutar 'sudo {manager} install {pkg}'? (s/n): {RESET}"
        ).strip().lower()
        if confirm != "s":
            print_info("Instalación cancelada.")
            _print_manual_instructions("Linux-RedHat", pg_ver)
            return

        print(f"\n{YELLOW}⏳ Instalando {pkg}...{RESET}")
        rc, _, err = _run_cmd(
            [manager, "install", "-y", pkg], use_sudo=True, capture=False
        )
        if rc == 0:
            print_success(f"Paquete '{pkg}' instalado correctamente.")
        else:
            print_error(f"Error: {err}")
            _print_manual_instructions("Linux-RedHat", pg_ver)

    elif is_arch:
        pkg = "postgis"
        print(f"{CYAN}Arch Linux detectado.{RESET}")
        confirm = input(
            f"\n{YELLOW}¿Ejecutar 'sudo pacman -S {pkg}'? (s/n): {RESET}"
        ).strip().lower()
        if confirm != "s":
            print_info("Instalación cancelada.")
            return
        rc, _, err = _run_cmd(
            ["pacman", "-S", "--noconfirm", pkg], use_sudo=True, capture=False
        )
        if rc == 0:
            print_success("PostGIS instalado via pacman.")
        else:
            print_error(f"Error: {err}")

    else:
        print_error("No se pudo detectar el gestor de paquetes.")
        _print_manual_instructions("Linux", pg_ver)


def _install_macos(pg_ver):
    """Intenta instalar PostGIS en macOS via Homebrew."""
    print(f"{CYAN}macOS detectado.{RESET}")
    if not shutil.which("brew"):
        print_error(
            "Homebrew no está instalado.\n"
            "  Instala Homebrew primero: https://brew.sh"
        )
        _print_manual_instructions("macOS", pg_ver)
        return

    confirm = input(
        f"\n{YELLOW}¿Ejecutar 'brew install postgis'? (s/n): {RESET}"
    ).strip().lower()
    if confirm != "s":
        print_info("Instalación cancelada.")
        return

    print(f"\n{YELLOW}⏳ Instalando postgis via Homebrew (puede tardar varios minutos)...{RESET}")
    rc, _, err = _run_cmd(["brew", "install", "postgis"], capture=False)
    if rc == 0:
        print_success("PostGIS instalado via Homebrew.")
    else:
        print_error(f"Error con Homebrew: {err}")
        _print_manual_instructions("macOS", pg_ver)


def _install_windows():
    """Guía para Windows — instalación manual via Stack Builder."""
    print(f"{CYAN}Windows detectado.{RESET}")
    print_error(
        "La instalación automática no está disponible en Windows.\n"
        "  Consulta las instrucciones manuales a continuación."
    )
    _print_manual_instructions("Windows", None)


def _activate_extension():
    """
    Activa la extensión PostGIS en TARGET_DB.
    Si la BD no existe aún, la crea primero.
    """
    # Asegurarse de que la BD existe
    try:
        conn = get_connection()
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute(
            "SELECT 1 FROM pg_database WHERE datname = %s", (TARGET_DB,)
        )
        if not cur.fetchone():
            cur.execute(
                sql.SQL("CREATE DATABASE {}").format(sql.Identifier(TARGET_DB))
            )
            print_success(f"Base de datos '{TARGET_DB}' creada.")
        cur.close()
        conn.close()
    except OperationalError as e:
        print_error(f"No se pudo conectar a PostgreSQL: {e}")
        return

    # Activar la extensión
    try:
        conn = get_connection(dbname=TARGET_DB)
        conn.autocommit = True
        cur = conn.cursor()

        print(f"\n{YELLOW}⏳ Activando extensión PostGIS en '{TARGET_DB}'...{RESET}")
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")

        cur.execute("SELECT PostGIS_Full_Version();")
        version = cur.fetchone()[0]
        # Extraer solo la parte relevante
        ver_short = version.split('"')[1] if '"' in version else version[:40]

        # Activar extensiones opcionales si están disponibles
        for ext in ["postgis_topology", "postgis_raster", "fuzzystrmatch"]:
            try:
                cur.execute(
                    f"CREATE EXTENSION IF NOT EXISTS {ext};"
                )
                print(f"  {GREEN}✔{RESET}  Extensión '{ext}' activada.")
            except Exception:
                print(f"  {YELLOW}⚠{RESET}  Extensión '{ext}' no disponible (opcional).")

        cur.close()
        conn.close()

        print_success(
            f"PostGIS activado correctamente en '{TARGET_DB}'.\n"
            f"  Versión: {ver_short}\n\n"
            f"  Ahora puedes ejecutar la opción {BOLD}[1]{RESET}{GREEN} "
            f"para crear el esquema y los datos de muestra."
        )

    except Exception as e:
        print_error(
            f"No se pudo activar la extensión: {e}\n\n"
            "  Posibles causas:\n"
            "  • PostGIS aún no está instalado en el SO (ejecuta opción 0 de nuevo)\n"
            "  • El usuario de PostgreSQL no tiene permisos de superusuario\n"
            "  • La versión del paquete no coincide con la de PostgreSQL"
        )


def _print_manual_instructions(sistema, pg_ver):
    """Imprime instrucciones de instalación manual según el SO."""
    pkg_ver = str(pg_ver) if pg_ver else "16"
    print(f"\n{BOLD}{'─'*60}{RESET}")
    print(f"{BOLD}  Instrucciones de instalación manual{RESET}")
    print(f"{BOLD}{'─'*60}{RESET}\n")

    if "Debian" in sistema or sistema == "Linux":
        print(f"  {CYAN}Ubuntu / Debian:{RESET}")
        print(f"  $ sudo apt-get update")
        print(f"  $ sudo apt-get install postgresql-{pkg_ver}-postgis-3\n")
        print(f"  {CYAN}Si el paquete no existe para tu versión de PG:{RESET}")
        print(f"  Añade el repositorio oficial de PostgreSQL:")
        print(f"  https://wiki.postgresql.org/wiki/Apt\n")

    if "RedHat" in sistema or sistema == "Linux":
        print(f"  {CYAN}Fedora / CentOS / RHEL:{RESET}")
        print(f"  $ sudo dnf install postgis33_{pkg_ver}")
        print(f"  (Puede requerir activar el repositorio EPEL y PGDG)\n")

    if sistema == "macOS" or sistema == "Darwin":
        print(f"  {CYAN}macOS con Homebrew:{RESET}")
        print(f"  $ brew install postgis\n")
        print(f"  {CYAN}macOS con Postgres.app:{RESET}")
        print(f"  PostGIS está incluido en https://postgresapp.com\n")

    if sistema == "Windows":
        print(f"  {CYAN}Windows:{RESET}")
        print(f"  1. Abre el instalador de PostgreSQL")
        print(f"  2. Lanza 'Stack Builder' al finalizar")
        print(f"  3. Selecciona: Spatial Extensions → PostGIS")
        print(f"  4. Sigue el asistente de instalación\n")
        print(f"  O descarga el instalador desde:")
        print(f"  https://postgis.net/windows_downloads/\n")

    print(f"  {CYAN}Tras instalar, vuelve a ejecutar la opción [0]{RESET}")
    print(f"  para activar la extensión en la base de datos.\n")
    print(f"  {CYAN}Documentación oficial:{RESET}")
    print(f"  https://postgis.net/documentation/getting_started/\n")
    print(f"{'─'*60}")


# ══════════════════════════════════════════════════════════
# OPCIÓN 1 — CREAR BASE DE DATOS Y ESQUEMA
# ══════════════════════════════════════════════════════════

def create_database():
    print_separator()
    print(f"{BOLD}1. Crear base de datos PostGIS y esquema geoespacial{RESET}\n")

    # ── Crear base de datos ───────────────────────────────
    try:
        conn = get_connection()
        conn.autocommit = True
        cur = conn.cursor()

        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (TARGET_DB,))
        if cur.fetchone():
            print_info(f"La base de datos '{TARGET_DB}' ya existe.")
        else:
            cur.execute(
                sql.SQL("CREATE DATABASE {}").format(sql.Identifier(TARGET_DB))
            )
            print_success(f"Base de datos '{TARGET_DB}' creada.")
        cur.close()
        conn.close()
    except OperationalError as e:
        print_error(f"No se pudo conectar a PostgreSQL: {e}")
        wait()
        return

    # ── Activar PostGIS y crear tablas ────────────────────
    try:
        conn = get_connection(dbname=TARGET_DB)
        conn.autocommit = True
        cur = conn.cursor()

        # Activar extensión PostGIS
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        cur.execute("SELECT PostGIS_Version();")
        version = cur.fetchone()[0]
        print_success(f"PostGIS activado — versión {version}")

        # ── Tabla 1: Puntos de interés ────────────────────
        cur.execute("""
        CREATE TABLE IF NOT EXISTS puntos_interes (
            id          SERIAL PRIMARY KEY,
            nombre      VARCHAR(200) NOT NULL,
            categoria   VARCHAR(100) NOT NULL,
            ciudad      VARCHAR(100),
            direccion   TEXT,
            telefono    VARCHAR(20),
            valoracion  NUMERIC(3,2) CHECK (valoracion BETWEEN 0 AND 5),
            activo      BOOLEAN DEFAULT TRUE,
            ubicacion   GEOGRAPHY(POINT, 4326),
            creado_en   TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_poi_ubicacion
            ON puntos_interes USING GIST (ubicacion);
        CREATE INDEX IF NOT EXISTS idx_poi_categoria
            ON puntos_interes (categoria);
        """)
        print_success("Tabla 'puntos_interes' creada con índices GiST.")

        # ── Tabla 2: Rutas ────────────────────────────────
        cur.execute("""
        CREATE TABLE IF NOT EXISTS rutas (
            id              SERIAL PRIMARY KEY,
            nombre          VARCHAR(200) NOT NULL,
            tipo            VARCHAR(50),
            origen          VARCHAR(100),
            destino         VARCHAR(100),
            longitud_km     NUMERIC(10,3),
            tiempo_min      INTEGER,
            trazado         GEOMETRY(LINESTRING, 4326),
            creado_en       TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_rutas_trazado
            ON rutas USING GIST (trazado);
        """)
        print_success("Tabla 'rutas' creada con índices GiST.")

        # ── Tabla 3: Zonas / polígonos ────────────────────
        cur.execute("""
        CREATE TABLE IF NOT EXISTS zonas (
            id          SERIAL PRIMARY KEY,
            nombre      VARCHAR(200) NOT NULL,
            tipo        VARCHAR(100),
            poblacion   INTEGER,
            area_km2    NUMERIC(12,4),
            perimetro   GEOMETRY(POLYGON, 4326),
            creado_en   TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_zonas_perimetro
            ON zonas USING GIST (perimetro);
        """)
        print_success("Tabla 'zonas' creada con índices GiST.")

        # ── Tabla 4: Trazas GPS de vehículos ──────────────
        cur.execute("""
        CREATE TABLE IF NOT EXISTS vehiculos (
            id          SERIAL PRIMARY KEY,
            matricula   VARCHAR(20) UNIQUE,
            tipo        VARCHAR(50),
            conductor   VARCHAR(100),
            activo      BOOLEAN DEFAULT TRUE
        );

        CREATE TABLE IF NOT EXISTS trazas_gps (
            id          BIGSERIAL PRIMARY KEY,
            vehiculo_id INTEGER REFERENCES vehiculos(id),
            timestamp   TIMESTAMP NOT NULL DEFAULT NOW(),
            posicion    GEOGRAPHY(POINT, 4326),
            velocidad   NUMERIC(6,2),
            rumbo       NUMERIC(5,2),
            altitud_m   NUMERIC(8,2)
        );
        CREATE INDEX IF NOT EXISTS idx_trazas_vehiculo_ts
            ON trazas_gps (vehiculo_id, timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_trazas_posicion
            ON trazas_gps USING GIST (posicion);
        """)
        print_success("Tablas 'vehiculos' y 'trazas_gps' creadas.")

        # ── Tabla 5: Sensores IoT medioambientales ─────────
        cur.execute("""
        CREATE TABLE IF NOT EXISTS sensores_aire (
            id          SERIAL PRIMARY KEY,
            codigo      VARCHAR(50) UNIQUE,
            ciudad      VARCHAR(100),
            posicion    GEOGRAPHY(POINT, 4326),
            instalado   DATE DEFAULT CURRENT_DATE,
            activo      BOOLEAN DEFAULT TRUE
        );

        CREATE TABLE IF NOT EXISTS lecturas_aire (
            id          BIGSERIAL PRIMARY KEY,
            sensor_id   INTEGER REFERENCES sensores_aire(id),
            timestamp   TIMESTAMP NOT NULL DEFAULT NOW(),
            pm25        NUMERIC(6,2),
            pm10        NUMERIC(6,2),
            no2         NUMERIC(6,2),
            temperatura NUMERIC(5,2),
            humedad     NUMERIC(5,2)
        );
        CREATE INDEX IF NOT EXISTS idx_sensores_posicion
            ON sensores_aire USING GIST (posicion);
        CREATE INDEX IF NOT EXISTS idx_lecturas_sensor_ts
            ON lecturas_aire (sensor_id, timestamp DESC);
        """)
        print_success("Tablas 'sensores_aire' y 'lecturas_aire' creadas.")

        conn.commit()
        cur.close()
        conn.close()

        # ── Insertar datos de muestra ─────────────────────
        _insert_sample_data()

    except Exception as e:
        print_error(f"Error al configurar la base de datos: {e}")
        import traceback
        traceback.print_exc()

    wait()


def _insert_sample_data():
    """Inserta datos geoespaciales de muestra en todas las tablas."""
    print_info("Insertando datos de muestra geoespaciales...")

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor()

        # ── POIs: 5 por ciudad ────────────────────────────
        poi_count = 0
        for ciudad, (lon, lat) in CIUDADES.items():
            for i in range(5):
                cat = random.choice(CATEGORIAS_POI)
                plon, plat = rand_offset(lon, lat, 0.08)
                nombre = random.choice(NOMBRES_POI).format(ciudad=ciudad)
                cur.execute("""
                    INSERT INTO puntos_interes
                        (nombre, categoria, ciudad, valoracion, ubicacion)
                    VALUES (%s, %s, %s, %s,
                        ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography)
                """, (
                    nombre, cat, ciudad,
                    round(random.uniform(2.5, 5.0), 1),
                    plon, plat
                ))
                poi_count += 1

        print_success(f"  {poi_count} puntos de interés insertados.")

        # ── Rutas: conexiones entre ciudades pares ─────────
        ciudades_lista = list(CIUDADES.items())
        ruta_count = 0
        for i in range(min(10, len(ciudades_lista) - 1)):
            c1_name, (lon1, lat1) = ciudades_lista[i]
            c2_name, (lon2, lat2) = ciudades_lista[i + 1]
            dist = haversine_km(lon1, lat1, lon2, lat2)
            tipo = random.choice(TIPOS_RUTA)
            vel  = {"autopista": 120, "nacional": 90, "comarcal": 60,
                    "ciclista": 20, "senderismo": 5}[tipo]
            tiempo = int((dist / vel) * 60)

            cur.execute("""
                INSERT INTO rutas
                    (nombre, tipo, origen, destino, longitud_km,
                     tiempo_min, trazado)
                VALUES (%s, %s, %s, %s, %s, %s,
                    ST_SetSRID(
                        ST_MakeLine(
                            ST_MakePoint(%s, %s),
                            ST_MakePoint(%s, %s)
                        ), 4326
                    ))
            """, (
                f"Ruta {c1_name}-{c2_name}", tipo, c1_name, c2_name,
                round(dist, 2), tiempo,
                lon1, lat1, lon2, lat2
            ))
            ruta_count += 1

        print_success(f"  {ruta_count} rutas insertadas.")

        # ── Zonas: polígonos alrededor de ciudades ─────────
        zona_count = 0
        for ciudad, (lon, lat) in list(CIUDADES.items())[:8]:
            radio = random.uniform(0.03, 0.08)
            n_vertices = random.randint(6, 10)
            coords = []
            for j in range(n_vertices):
                angle = 2 * math.pi * j / n_vertices
                r = radio * random.uniform(0.7, 1.3)
                coords.append((
                    round(lon + r * math.cos(angle), 6),
                    round(lat + r * math.sin(angle), 6)
                ))
            coords.append(coords[0])  # cerrar el polígono
            wkt_coords = ", ".join(f"{c[0]} {c[1]}" for c in coords)

            tipo = random.choice(TIPOS_ZONA)
            area_aprox = math.pi * (radio * 111) ** 2
            cur.execute("""
                INSERT INTO zonas (nombre, tipo, poblacion, area_km2, perimetro)
                VALUES (%s, %s, %s, %s,
                    ST_SetSRID(
                        ST_GeomFromText(%s), 4326
                    ))
            """, (
                f"Zona {tipo.replace('_',' ').title()} {ciudad}",
                tipo,
                random.randint(5000, 500000),
                round(area_aprox, 4),
                f"POLYGON(({wkt_coords}))"
            ))
            zona_count += 1

        print_success(f"  {zona_count} zonas (polígonos) insertadas.")

        # ── Vehículos y trazas GPS ────────────────────────
        vehiculos = [
            ("1234ABC", "furgoneta", "Juan García"),
            ("5678DEF", "camión",    "María López"),
            ("9012GHI", "turismo",   "Pedro Martínez"),
        ]
        for mat, tipo, conductor in vehiculos:
            cur.execute("""
                INSERT INTO vehiculos (matricula, tipo, conductor)
                VALUES (%s, %s, %s)
                ON CONFLICT (matricula) DO NOTHING
                RETURNING id
            """, (mat, tipo, conductor))
            result = cur.fetchone()
            if result:
                vid = result[0]
                # 20 puntos de traza GPS alrededor de Madrid
                lon, lat = CIUDADES["Madrid"]
                for t in range(20):
                    ts = datetime.now() - timedelta(hours=20 - t)
                    plon = lon + t * 0.002 + random.uniform(-0.001, 0.001)
                    plat = lat + random.uniform(-0.005, 0.005)
                    cur.execute("""
                        INSERT INTO trazas_gps
                            (vehiculo_id, timestamp, posicion, velocidad, rumbo)
                        VALUES (%s, %s,
                            ST_SetSRID(ST_MakePoint(%s,%s),4326)::geography,
                            %s, %s)
                    """, (
                        vid, ts, round(plon, 6), round(plat, 6),
                        round(random.uniform(0, 120), 1),
                        round(random.uniform(0, 360), 1)
                    ))

        print_success("  3 vehículos con 20 trazas GPS cada uno insertados.")

        # ── Sensores de aire y lecturas ───────────────────
        sensor_count = 0
        for ciudad, (lon, lat) in list(CIUDADES.items())[:6]:
            for s in range(3):
                codigo = f"AIRE-{ciudad[:3].upper()}-{s+1:02d}"
                plon, plat = rand_offset(lon, lat, 0.05)
                cur.execute("""
                    INSERT INTO sensores_aire (codigo, ciudad, posicion)
                    VALUES (%s, %s,
                        ST_SetSRID(ST_MakePoint(%s,%s),4326)::geography)
                    ON CONFLICT (codigo) DO NOTHING
                    RETURNING id
                """, (codigo, ciudad, round(plon,6), round(plat,6)))
                result = cur.fetchone()
                if result:
                    sid = result[0]
                    # 48 lecturas (últimas 48 horas)
                    for h in range(48):
                        ts = datetime.now() - timedelta(hours=48 - h)
                        cur.execute("""
                            INSERT INTO lecturas_aire
                                (sensor_id, timestamp, pm25, pm10,
                                 no2, temperatura, humedad)
                            VALUES (%s, %s, %s, %s, %s, %s, %s)
                        """, (
                            sid, ts,
                            round(random.uniform(5, 45), 1),
                            round(random.uniform(10, 80), 1),
                            round(random.uniform(10, 60), 1),
                            round(random.uniform(8, 32), 1),
                            round(random.uniform(30, 90), 1)
                        ))
                    sensor_count += 1

        print_success(f"  {sensor_count} sensores con 48 lecturas cada uno.")

        conn.commit()
        cur.close()
        conn.close()

    except Exception as e:
        print_error(f"Error al insertar datos de muestra: {e}")
        import traceback
        traceback.print_exc()


# ══════════════════════════════════════════════════════════
# OPCIÓN 2 — INSERTAR PUNTO DE INTERÉS
# ══════════════════════════════════════════════════════════

def insert_poi():
    print_separator()
    print(f"{BOLD}2. Insertar punto de interés geoespacial{RESET}\n")

    print(f"{YELLOW}Opciones:{RESET}")
    print(f"  {YELLOW}[1]{RESET}  Insertar manualmente (lon, lat)")
    print(f"  {YELLOW}[2]{RESET}  Insertar desde ciudad predefinida")
    print(f"  {YELLOW}[3]{RESET}  Insertar N POIs aleatorios")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor()

        if choice == "1":
            nombre   = input("Nombre del POI: ").strip() or "POI Sin Nombre"
            print(f"Categorías: {', '.join(CATEGORIAS_POI[:6])}...")
            categoria = input("Categoría: ").strip() or "restaurante"
            ciudad    = input("Ciudad: ").strip() or "Desconocida"
            try:
                lon = float(input("Longitud (ej. -3.7038): ").strip())
                lat = float(input("Latitud  (ej. 40.4168): ").strip())
            except ValueError:
                print_error("Coordenadas inválidas.")
                cur.close(); conn.close(); wait(); return

            valoracion = round(random.uniform(3.0, 5.0), 1)

            cur.execute("""
                INSERT INTO puntos_interes
                    (nombre, categoria, ciudad, valoracion, ubicacion)
                VALUES (%s, %s, %s, %s,
                    ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography)
                RETURNING id
            """, (nombre, categoria, ciudad, valoracion, lon, lat))
            new_id = cur.fetchone()[0]
            conn.commit()
            print_success(
                f"POI '{nombre}' insertado con ID={new_id} "
                f"en ({lon}, {lat})."
            )

        elif choice == "2":
            print(f"\nCiudades disponibles:")
            for i, c in enumerate(CIUDADES.keys(), 1):
                print(f"  {i:2}. {c}")
            idx = input("Número de ciudad: ").strip()
            ciudades_list = list(CIUDADES.items())
            try:
                ciudad, (clon, clat) = ciudades_list[int(idx) - 1]
            except (ValueError, IndexError):
                print_error("Selección inválida.")
                cur.close(); conn.close(); wait(); return

            nombre    = input(f"Nombre del POI [{ciudad} POI]: ").strip() \
                        or f"{ciudad} POI"
            categoria = input(
                f"Categoría [{CATEGORIAS_POI[0]}]: "
            ).strip() or CATEGORIAS_POI[0]
            radio     = float(
                input("Radio de desplazamiento en grados [0.05]: ").strip() or "0.05"
            )
            lon, lat  = rand_offset(clon, clat, radio)

            cur.execute("""
                INSERT INTO puntos_interes
                    (nombre, categoria, ciudad, valoracion, ubicacion)
                VALUES (%s, %s, %s, %s,
                    ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography)
                RETURNING id
            """, (nombre, categoria, ciudad,
                  round(random.uniform(2.5, 5.0), 1), lon, lat))
            new_id = cur.fetchone()[0]
            conn.commit()
            print_success(
                f"POI '{nombre}' en {ciudad} insertado con ID={new_id} "
                f"coords ({lon}, {lat})."
            )

        elif choice == "3":
            n_str = input("¿Cuántos POIs aleatorios? [20]: ").strip()
            n = int(n_str) if n_str.isdigit() and int(n_str) > 0 else 20
            inserted = 0
            for _ in range(n):
                ciudad, (clon, clat) = random.choice(list(CIUDADES.items()))
                lon, lat = rand_offset(clon, clat, 0.1)
                cat  = random.choice(CATEGORIAS_POI)
                nom  = random.choice(NOMBRES_POI).format(ciudad=ciudad)
                cur.execute("""
                    INSERT INTO puntos_interes
                        (nombre, categoria, ciudad, valoracion, ubicacion)
                    VALUES (%s, %s, %s, %s,
                        ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography)
                """, (nom, cat, ciudad,
                      round(random.uniform(2.0, 5.0), 1), lon, lat))
                inserted += 1
            conn.commit()
            print_success(f"{inserted} POIs aleatorios insertados.")

        cur.close()
        conn.close()
    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'. ¿Ejecutaste la opción 1?")
    except Exception as e:
        print_error(f"Error: {e}")

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 3 — CONSULTAS GEOESPACIALES
# ══════════════════════════════════════════════════════════

def spatial_queries():
    print_separator()
    print(f"{BOLD}3. Consultas geoespaciales{RESET}\n")

    print(f"  {YELLOW}[1]{RESET}  POIs cercanos a un punto (radio en km)")
    print(f"  {YELLOW}[2]{RESET}  Los N POIs más cercanos (KNN)")
    print(f"  {YELLOW}[3]{RESET}  POIs dentro de una zona (polígono)")
    print(f"  {YELLOW}[4]{RESET}  Distancia entre dos ciudades")
    print(f"  {YELLOW}[5]{RESET}  Ruta más larga registrada")
    print(f"  {YELLOW}[6]{RESET}  Recorrido total de un vehículo")
    print(f"  {YELLOW}[7]{RESET}  Sensores con contaminación alta (PM2.5)")
    print(f"  {YELLOW}[8]{RESET}  Estadísticas geoespaciales generales")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            # POIs en un radio dado
            print(f"\nCiudades de referencia:")
            for i, c in enumerate(list(CIUDADES.keys())[:8], 1):
                print(f"  {i}. {c}")
            idx = input("Ciudad de referencia [1]: ").strip() or "1"
            ciudad, (lon, lat) = list(CIUDADES.items())[int(idx) - 1]
            radio_km = float(input(f"Radio en km [5]: ").strip() or "5")

            cur.execute("""
                SELECT
                    nombre,
                    categoria,
                    ciudad,
                    valoracion,
                    ROUND(ST_Distance(
                        ubicacion,
                        ST_GeogFromText(%s)
                    )::numeric / 1000, 2) AS distancia_km,
                    ST_Y(ubicacion::geometry) AS latitud,
                    ST_X(ubicacion::geometry) AS longitud
                FROM puntos_interes
                WHERE ST_DWithin(
                    ubicacion,
                    ST_GeogFromText(%s),
                    %s
                )
                ORDER BY distancia_km
            """, (
                f"POINT({lon} {lat})",
                f"POINT({lon} {lat})",
                radio_km * 1000
            ))
            rows = cur.fetchall()
            _print_poi_table(rows, f"POIs a menos de {radio_km} km de {ciudad}")

        elif choice == "2":
            # KNN — N más cercanos
            print(f"\nCiudades:")
            for i, c in enumerate(list(CIUDADES.keys())[:8], 1):
                print(f"  {i}. {c}")
            idx   = input("Ciudad de referencia [1]: ").strip() or "1"
            ciudad, (lon, lat) = list(CIUDADES.items())[int(idx) - 1]
            n_str = input("¿Cuántos POIs más cercanos? [5]: ").strip()
            n     = int(n_str) if n_str.isdigit() else 5
            cat   = input(
                f"Filtrar por categoría (Enter = todas): "
            ).strip() or None

            where = "WHERE categoria = %s" if cat else ""
            params = [lon, lat, lon, lat]
            if cat:
                params = [lon, lat, cat, lon, lat]
                where = "WHERE categoria = %s"

            cur.execute(f"""
                SELECT
                    nombre, categoria, ciudad, valoracion,
                    ROUND(
                        ST_Distance(
                            ubicacion,
                            ST_SetSRID(ST_MakePoint(%s,%s),4326)::geography
                        )::numeric / 1000, 3
                    ) AS distancia_km
                FROM puntos_interes
                {where}
                ORDER BY ubicacion <->
                    ST_SetSRID(ST_MakePoint(%s,%s),4326)
                LIMIT {n}
            """, params)
            rows = cur.fetchall()
            _print_poi_table(rows, f"{n} POIs más cercanos a {ciudad}"
                             + (f" (cat: {cat})" if cat else ""))

        elif choice == "3":
            # POIs dentro de una zona
            cur.execute("""
                SELECT id, nombre, tipo FROM zonas ORDER BY nombre
            """)
            zonas = cur.fetchall()
            print(f"\nZonas disponibles:")
            for z in zonas:
                print(f"  {z['id']:3}. [{z['tipo']}] {z['nombre']}")
            zona_id = input("ID de zona: ").strip()

            cur.execute("""
                SELECT
                    p.nombre, p.categoria, p.ciudad, p.valoracion,
                    ST_Y(p.ubicacion::geometry) AS latitud,
                    ST_X(p.ubicacion::geometry) AS longitud
                FROM puntos_interes p, zonas z
                WHERE z.id = %s
                  AND ST_Within(
                      p.ubicacion::geometry,
                      z.perimetro
                  )
                ORDER BY p.categoria, p.nombre
            """, (zona_id,))
            rows = cur.fetchall()
            _print_poi_table(rows, f"POIs dentro de la zona ID={zona_id}")

        elif choice == "4":
            # Distancia entre ciudades
            ciudades_list = list(CIUDADES.items())
            print("\nCiudades:")
            for i, (c, _) in enumerate(ciudades_list, 1):
                print(f"  {i:2}. {c}")
            i1 = int(input("Ciudad origen (número): ").strip() or "1") - 1
            i2 = int(input("Ciudad destino (número): ").strip() or "2") - 1
            c1, (lon1, lat1) = ciudades_list[i1]
            c2, (lon2, lat2) = ciudades_list[i2]

            cur.execute("""
                SELECT
                    ROUND(ST_Distance(
                        ST_GeogFromText(%s),
                        ST_GeogFromText(%s)
                    )::numeric / 1000, 2) AS distancia_km,
                    ROUND(ST_Distance(
                        ST_GeogFromText(%s),
                        ST_GeogFromText(%s)
                    )::numeric / 1000 / 110 * 60, 0) AS tiempo_coche_min
            """, (
                f"POINT({lon1} {lat1})",
                f"POINT({lon2} {lat2})",
                f"POINT({lon1} {lat1})",
                f"POINT({lon2} {lat2})",
            ))
            r = cur.fetchone()
            print(f"\n{BOLD}Distancia {c1} → {c2}:{RESET}")
            print_separator("─")
            print(f"  Distancia geodésica : {CYAN}{r['distancia_km']} km{RESET}")
            print(f"  Tiempo estimado (110km/h) : {YELLOW}{r['tiempo_coche_min']} min{RESET}")
            distancia_local = haversine_km(lon1, lat1, lon2, lat2)
            print(f"  Verificación Haversine   : {distancia_local:.2f} km")

        elif choice == "5":
            # Ruta más larga
            cur.execute("""
                SELECT
                    nombre, tipo, origen, destino,
                    ROUND(
                        ST_Length(trazado::geography)::numeric / 1000, 2
                    ) AS longitud_real_km,
                    longitud_km AS longitud_registrada_km
                FROM rutas
                ORDER BY ST_Length(trazado::geography) DESC
                LIMIT 5
            """)
            rows = cur.fetchall()
            print(f"\n{BOLD}Top 5 rutas más largas:{RESET}")
            print_separator("─")
            print(f"  {'Nombre':<30} {'Tipo':<12} {'Origen':<15} {'Destino':<15} {'km':>8}")
            print_separator("─")
            for r in rows:
                print(f"  {str(r['nombre']):<30} {str(r['tipo']):<12} "
                      f"{str(r['origen']):<15} {str(r['destino']):<15} "
                      f"{CYAN}{r['longitud_real_km']:>8}{RESET}")

        elif choice == "6":
            # Recorrido de vehículo
            cur.execute("SELECT id, matricula, conductor FROM vehiculos")
            vehs = cur.fetchall()
            for v in vehs:
                print(f"  {v['id']}. {v['matricula']} — {v['conductor']}")
            vid = input("ID de vehículo: ").strip() or "1"

            cur.execute("""
                SELECT
                    v.matricula,
                    v.conductor,
                    COUNT(t.id) AS total_puntos,
                    MIN(t.timestamp) AS inicio,
                    MAX(t.timestamp) AS fin,
                    ROUND(AVG(t.velocidad)::numeric, 1) AS vel_media_kmh,
                    ROUND(MAX(t.velocidad)::numeric, 1) AS vel_max_kmh,
                    ROUND(
                        ST_Length(
                            ST_MakeLine(t.posicion::geometry ORDER BY t.timestamp)
                            ::geography
                        )::numeric / 1000, 3
                    ) AS km_recorridos
                FROM vehiculos v
                JOIN trazas_gps t ON t.vehiculo_id = v.id
                WHERE v.id = %s
                GROUP BY v.id, v.matricula, v.conductor
            """, (vid,))
            r = cur.fetchone()
            if r:
                print(f"\n{BOLD}Resumen de recorrido — {r['matricula']}{RESET}")
                print_separator("─")
                print(f"  Conductor         : {r['conductor']}")
                print(f"  Puntos GPS        : {r['total_puntos']}")
                print(f"  Inicio            : {r['inicio']}")
                print(f"  Fin               : {r['fin']}")
                print(f"  Velocidad media   : {CYAN}{r['vel_media_kmh']} km/h{RESET}")
                print(f"  Velocidad máxima  : {YELLOW}{r['vel_max_kmh']} km/h{RESET}")
                print(f"  Distancia total   : {GREEN}{r['km_recorridos']} km{RESET}")

        elif choice == "7":
            # Sensores con PM2.5 alto
            umbral = float(input("Umbral PM2.5 µg/m³ [25]: ").strip() or "25")
            cur.execute("""
                SELECT
                    s.codigo,
                    s.ciudad,
                    ROUND(AVG(l.pm25)::numeric, 2) AS pm25_medio,
                    ROUND(MAX(l.pm25)::numeric, 2) AS pm25_max,
                    ROUND(AVG(l.temperatura)::numeric, 1) AS temp_media,
                    ST_Y(s.posicion::geometry) AS lat,
                    ST_X(s.posicion::geometry) AS lon,
                    COUNT(l.id) AS num_lecturas
                FROM sensores_aire s
                JOIN lecturas_aire l ON l.sensor_id = s.id
                WHERE l.timestamp >= NOW() - INTERVAL '24 hours'
                GROUP BY s.id, s.codigo, s.ciudad, s.posicion
                HAVING AVG(l.pm25) > %s
                ORDER BY pm25_medio DESC
            """, (umbral,))
            rows = cur.fetchall()
            print(f"\n{BOLD}Sensores con PM2.5 > {umbral} µg/m³ (últimas 24h):{RESET}")
            print_separator("─")
            if not rows:
                print_info("Ningún sensor supera el umbral establecido.")
            else:
                print(f"  {'Código':<18} {'Ciudad':<15} {'PM2.5 medio':>12} "
                      f"{'PM2.5 max':>10} {'Temp':>6}")
                print_separator("─")
                for r in rows:
                    color = RED if r['pm25_medio'] > 35 else YELLOW
                    print(f"  {r['codigo']:<18} {str(r['ciudad']):<15} "
                          f"{color}{r['pm25_medio']:>12}{RESET} "
                          f"{r['pm25_max']:>10} {r['temp_media']:>6}°C")

        elif choice == "8":
            # Estadísticas generales
            cur.execute("SELECT COUNT(*) AS total FROM puntos_interes")
            n_poi = cur.fetchone()["total"]
            cur.execute("SELECT COUNT(*) AS total FROM rutas")
            n_rutas = cur.fetchone()["total"]
            cur.execute("SELECT COUNT(*) AS total FROM zonas")
            n_zonas = cur.fetchone()["total"]
            cur.execute("SELECT COUNT(*) AS total FROM trazas_gps")
            n_trazas = cur.fetchone()["total"]
            cur.execute("SELECT COUNT(*) AS total FROM lecturas_aire")
            n_lecturas = cur.fetchone()["total"]

            cur.execute("""
                SELECT categoria, COUNT(*) AS total
                FROM puntos_interes
                GROUP BY categoria
                ORDER BY total DESC LIMIT 5
            """)
            top_cat = cur.fetchall()

            cur.execute("""
                SELECT ciudad,
                    COUNT(*) AS pois,
                    ROUND(AVG(valoracion)::numeric, 2) AS val_media
                FROM puntos_interes
                GROUP BY ciudad
                ORDER BY pois DESC LIMIT 5
            """)
            top_cities = cur.fetchall()

            cur.execute("""
                SELECT
                    ROUND(SUM(
                        ST_Length(trazado::geography)
                    )::numeric / 1000, 2) AS km_total_rutas
                FROM rutas
            """)
            km_total = cur.fetchone()["km_total_rutas"]

            print(f"\n{BOLD}{'═'*55}{RESET}")
            print(f"{BOLD}  ESTADÍSTICAS GEOESPACIALES — {TARGET_DB}{RESET}")
            print(f"{BOLD}{'═'*55}{RESET}")
            print(f"\n  {BOLD}Registros por tabla:{RESET}")
            print(f"  {'Puntos de interés':<30} {CYAN}{n_poi:>8}{RESET}")
            print(f"  {'Rutas':<30} {CYAN}{n_rutas:>8}{RESET}")
            print(f"  {'Zonas (polígonos)':<30} {CYAN}{n_zonas:>8}{RESET}")
            print(f"  {'Trazas GPS':<30} {CYAN}{n_trazas:>8}{RESET}")
            print(f"  {'Lecturas de sensores':<30} {CYAN}{n_lecturas:>8}{RESET}")
            print(f"  {'Km totales en rutas':<30} {GREEN}{km_total:>8} km{RESET}")

            print(f"\n  {BOLD}Top 5 categorías de POI:{RESET}")
            for r in top_cat:
                bar = "█" * min(int(r["total"] / max(n_poi, 1) * 25), 25)
                print(f"  {str(r['categoria']):<22} {bar} {r['total']}")

            print(f"\n  {BOLD}Top 5 ciudades por POIs:{RESET}")
            for r in top_cities:
                print(f"  {str(r['ciudad']):<20} {r['pois']:>5} POIs  "
                      f"val. media {YELLOW}{r['val_media']}{RESET}⭐")
            print_separator()

        cur.close()
        conn.close()

    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error en la consulta: {e}")
        import traceback
        traceback.print_exc()

    wait()


def _print_poi_table(rows, title):
    """Imprime una tabla formateada de POIs."""
    print(f"\n{BOLD}{title}{RESET}")
    print_separator("─")
    if not rows:
        print_info("No se encontraron resultados.")
        return
    print(f"  {'Nombre':<28} {'Cat':<16} {'Ciudad':<14} {'Val':>4} ", end="")
    if "distancia_km" in rows[0]:
        print(f"{'Dist km':>9}", end="")
    print()
    print_separator("─")
    for r in rows:
        dist_str = ""
        if "distancia_km" in r and r["distancia_km"] is not None:
            dist_str = f"{r['distancia_km']:>9}"
        print(
            f"  {str(r['nombre'])[:27]:<28} "
            f"{str(r['categoria'])[:15]:<16} "
            f"{str(r.get('ciudad',''))[:13]:<14} "
            f"{YELLOW}{str(r.get('valoracion',''))[:4]:>4}{RESET}"
            f"{CYAN}{dist_str}{RESET}"
        )
    print_separator("─")
    print(f"  Total: {BOLD}{len(rows)}{RESET} registros.")


# ══════════════════════════════════════════════════════════
# OPCIÓN 4 — ACTUALIZAR GEOMETRÍA
# ══════════════════════════════════════════════════════════

def update_geometry():
    print_separator()
    print(f"{BOLD}4. Actualizar geometría de un registro{RESET}\n")

    print(f"  {YELLOW}[1]{RESET}  Actualizar ubicación de un POI")
    print(f"  {YELLOW}[2]{RESET}  Actualizar zona de cobertura (buffer)")
    print(f"  {YELLOW}[3]{RESET}  Añadir punto GPS a un vehículo")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            poi_id = input("ID del POI a actualizar: ").strip()
            cur.execute(
                "SELECT id, nombre, categoria, ciudad FROM puntos_interes "
                "WHERE id = %s", (poi_id,)
            )
            poi = cur.fetchone()
            if not poi:
                print_info(f"No existe POI con ID={poi_id}.")
                cur.close(); conn.close(); wait(); return

            print(f"\n  POI: {poi['nombre']} ({poi['categoria']}) — {poi['ciudad']}")
            try:
                lon = float(input("Nueva longitud: ").strip())
                lat = float(input("Nueva latitud : ").strip())
            except ValueError:
                print_error("Coordenadas inválidas.")
                cur.close(); conn.close(); wait(); return

            cur.execute("""
                UPDATE puntos_interes
                SET ubicacion =
                    ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography
                WHERE id = %s
            """, (lon, lat, poi_id))
            conn.commit()
            print_success(
                f"Ubicación de '{poi['nombre']}' actualizada a ({lon}, {lat})."
            )

        elif choice == "2":
            # Buffer automático alrededor de un POI
            poi_id = input("ID del POI (origen del buffer): ").strip()
            radio  = float(
                input("Radio del buffer en metros [500]: ").strip() or "500"
            )
            cur.execute(
                "SELECT id, nombre FROM puntos_interes WHERE id = %s", (poi_id,)
            )
            poi = cur.fetchone()
            if not poi:
                print_info(f"No existe POI con ID={poi_id}.")
                cur.close(); conn.close(); wait(); return

            nombre_zona = input(
                f"Nombre de la zona [{poi['nombre']} — Zona de influencia]: "
            ).strip() or f"{poi['nombre']} — Zona de influencia"

            cur.execute("""
                INSERT INTO zonas (nombre, tipo, perimetro)
                SELECT
                    %s,
                    'zona_influencia',
                    ST_Buffer(ubicacion::geometry, %s / 111320.0)
                FROM puntos_interes
                WHERE id = %s
                RETURNING id
            """, (nombre_zona, radio, poi_id))
            zona_id = cur.fetchone()["id"]
            conn.commit()
            print_success(
                f"Zona de influencia '{nombre_zona}' creada con ID={zona_id} "
                f"(radio={radio}m)."
            )

        elif choice == "3":
            # Añadir punto GPS a vehículo
            cur.execute(
                "SELECT id, matricula FROM vehiculos WHERE activo = TRUE"
            )
            vehs = cur.fetchall()
            for v in vehs:
                print(f"  {v['id']}. {v['matricula']}")
            vid = input("ID de vehículo: ").strip()
            try:
                lon = float(input("Longitud GPS: ").strip())
                lat = float(input("Latitud  GPS: ").strip())
                vel = float(input("Velocidad km/h [0]: ").strip() or "0")
            except ValueError:
                print_error("Datos inválidos.")
                cur.close(); conn.close(); wait(); return

            cur.execute("""
                INSERT INTO trazas_gps (vehiculo_id, posicion, velocidad)
                VALUES (%s,
                    ST_SetSRID(ST_MakePoint(%s,%s),4326)::geography,
                    %s)
                RETURNING id, timestamp
            """, (vid, lon, lat, vel))
            result = cur.fetchone()
            conn.commit()
            print_success(
                f"Punto GPS insertado (ID={result['id']}) "
                f"para vehículo {vid} a las {result['timestamp']}."
            )

        cur.close()
        conn.close()
    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error: {e}")

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 5 — ELIMINAR DATOS GEOESPACIALES
# ══════════════════════════════════════════════════════════

def delete_geo_data():
    print_separator()
    print(f"{BOLD}5. Eliminar datos geoespaciales{RESET}\n")

    print(f"  {YELLOW}[1]{RESET}  Eliminar POI por ID")
    print(f"  {YELLOW}[2]{RESET}  Eliminar POIs fuera de un radio (limpiar outliers)")
    print(f"  {YELLOW}[3]{RESET}  Eliminar zona por ID")
    print(f"  {YELLOW}[4]{RESET}  Eliminar trazas GPS antiguas")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            poi_id = input("ID del POI a eliminar: ").strip()
            cur.execute(
                "SELECT nombre, categoria, ciudad FROM puntos_interes "
                "WHERE id = %s", (poi_id,)
            )
            poi = cur.fetchone()
            if not poi:
                print_info(f"No existe POI con ID={poi_id}.")
                cur.close(); conn.close(); wait(); return

            print(f"\n  {poi['nombre']} — {poi['categoria']} — {poi['ciudad']}")
            confirm = input(f"\n{RED}¿Confirmar eliminación? (s/n): {RESET}").lower()
            if confirm != "s":
                print_info("Cancelado.")
                cur.close(); conn.close(); wait(); return

            cur.execute("DELETE FROM puntos_interes WHERE id = %s", (poi_id,))
            conn.commit()
            print_success(f"POI '{poi['nombre']}' eliminado.")

        elif choice == "2":
            # Eliminar POIs fuera de España peninsular (bbox)
            lon_min = float(input("Longitud mínima [-10.0]: ").strip() or "-10.0")
            lon_max = float(input("Longitud máxima [5.0]: ").strip()  or "5.0")
            lat_min = float(input("Latitud mínima [35.0]: ").strip()  or "35.0")
            lat_max = float(input("Latitud máxima [44.0]: ").strip()  or "44.0")

            cur.execute("""
                SELECT COUNT(*) AS total FROM puntos_interes
                WHERE NOT ST_Within(
                    ubicacion::geometry,
                    ST_MakeEnvelope(%s, %s, %s, %s, 4326)
                )
            """, (lon_min, lat_min, lon_max, lat_max))
            count = cur.fetchone()["total"]
            print_info(f"Se eliminarán {count} POIs fuera del bbox definido.")

            if count == 0:
                print_info("No hay POIs fuera del área.")
                cur.close(); conn.close(); wait(); return

            confirm = input(
                f"{RED}¿Confirmar eliminación de {count} POIs? (s/n): {RESET}"
            ).lower()
            if confirm != "s":
                print_info("Cancelado.")
                cur.close(); conn.close(); wait(); return

            cur.execute("""
                DELETE FROM puntos_interes
                WHERE NOT ST_Within(
                    ubicacion::geometry,
                    ST_MakeEnvelope(%s, %s, %s, %s, 4326)
                )
            """, (lon_min, lat_min, lon_max, lat_max))
            conn.commit()
            print_success(f"{count} POIs fuera del área eliminados.")

        elif choice == "3":
            cur.execute(
                "SELECT id, nombre, tipo FROM zonas ORDER BY id"
            )
            zonas = cur.fetchall()
            for z in zonas:
                print(f"  {z['id']:3}. [{z['tipo']}] {z['nombre']}")
            zona_id = input("ID de zona a eliminar: ").strip()
            cur.execute(
                "SELECT nombre FROM zonas WHERE id = %s", (zona_id,)
            )
            zona = cur.fetchone()
            if not zona:
                print_info(f"No existe zona con ID={zona_id}.")
                cur.close(); conn.close(); wait(); return

            confirm = input(
                f"\n{RED}Eliminar zona '{zona['nombre']}' (s/n): {RESET}"
            ).lower()
            if confirm != "s":
                print_info("Cancelado.")
                cur.close(); conn.close(); wait(); return

            cur.execute("DELETE FROM zonas WHERE id = %s", (zona_id,))
            conn.commit()
            print_success(f"Zona '{zona['nombre']}' eliminada.")

        elif choice == "4":
            dias_str = input(
                "Eliminar trazas GPS más antiguas que (días) [7]: "
            ).strip() or "7"
            dias = int(dias_str)
            cutoff = datetime.now() - timedelta(days=dias)

            cur.execute(
                "SELECT COUNT(*) AS total FROM trazas_gps WHERE timestamp < %s",
                (cutoff,)
            )
            count = cur.fetchone()["total"]
            print_info(
                f"Se eliminarán {count} trazas anteriores a "
                f"{cutoff.strftime('%Y-%m-%d')}."
            )

            if count == 0:
                print_info("No hay trazas que cumplan el criterio.")
                cur.close(); conn.close(); wait(); return

            confirm = input(
                f"{RED}¿Confirmar? (s/n): {RESET}"
            ).lower()
            if confirm != "s":
                print_info("Cancelado.")
                cur.close(); conn.close(); wait(); return

            cur.execute(
                "DELETE FROM trazas_gps WHERE timestamp < %s", (cutoff,)
            )
            conn.commit()
            print_success(f"{count} trazas GPS antiguas eliminadas.")

        cur.close()
        conn.close()
    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error: {e}")

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 6 — EXPORTAR GEOJSON / MAPA HTML
# ══════════════════════════════════════════════════════════

def export_data():
    print_separator()
    print(f"{BOLD}6. Exportar datos geoespaciales{RESET}\n")

    print(f"  {YELLOW}[1]{RESET}  Exportar POIs como GeoJSON")
    print(f"  {YELLOW}[2]{RESET}  Exportar zonas como GeoJSON")
    print(f"  {YELLOW}[3]{RESET}  Generar mapa HTML interactivo (requiere folium)")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            ciudad = input("Filtrar por ciudad (Enter = todas): ").strip() or None
            where  = "WHERE ciudad = %s" if ciudad else ""
            params = (ciudad,) if ciudad else ()

            cur.execute(f"""
                SELECT json_build_object(
                    'type', 'FeatureCollection',
                    'features', json_agg(
                        json_build_object(
                            'type', 'Feature',
                            'geometry', ST_AsGeoJSON(ubicacion)::json,
                            'properties', json_build_object(
                                'id', id,
                                'nombre', nombre,
                                'categoria', categoria,
                                'ciudad', ciudad,
                                'valoracion', valoracion
                            )
                        )
                    )
                ) AS geojson
                FROM puntos_interes
                {where}
            """, params)
            result = cur.fetchone()
            filename = f"poi{'_' + ciudad if ciudad else ''}.geojson"
            with open(filename, "w", encoding="utf-8") as f:
                json.dump(result["geojson"], f, ensure_ascii=False, indent=2)
            print_success(f"GeoJSON exportado a '{filename}'.")

        elif choice == "2":
            cur.execute("""
                SELECT json_build_object(
                    'type', 'FeatureCollection',
                    'features', json_agg(
                        json_build_object(
                            'type', 'Feature',
                            'geometry', ST_AsGeoJSON(perimetro)::json,
                            'properties', json_build_object(
                                'id', id,
                                'nombre', nombre,
                                'tipo', tipo,
                                'poblacion', poblacion,
                                'area_km2', area_km2
                            )
                        )
                    )
                ) AS geojson
                FROM zonas
            """)
            result = cur.fetchone()
            filename = "zonas.geojson"
            with open(filename, "w", encoding="utf-8") as f:
                json.dump(result["geojson"], f, ensure_ascii=False, indent=2)
            print_success(f"GeoJSON de zonas exportado a '{filename}'.")

        elif choice == "3":
            if not FOLIUM_OK:
                print_error(
                    "folium no está instalado. "
                    "Ejecuta: pip install folium"
                )
                cur.close(); conn.close(); wait(); return

            # Centrar el mapa en España
            mapa = folium.Map(
                location=[40.0, -3.5],
                zoom_start=6,
                tiles="OpenStreetMap"
            )

            # Colores por categoría
            color_map = {
                "hospital": "red",       "farmacia": "lightred",
                "supermercado": "green", "restaurante": "orange",
                "hotel": "blue",         "museo": "purple",
                "parque": "darkgreen",   "gasolinera": "gray",
                "banco": "darkblue",     "universidad": "darkpurple",
            }

            # POIs
            cur.execute("""
                SELECT nombre, categoria, ciudad, valoracion,
                    ST_Y(ubicacion::geometry) AS lat,
                    ST_X(ubicacion::geometry) AS lon
                FROM puntos_interes
                WHERE ubicacion IS NOT NULL
            """)
            pois = cur.fetchall()
            poi_group = folium.FeatureGroup(name="Puntos de Interés")
            for p in pois:
                color = color_map.get(p["categoria"], "blue")
                folium.CircleMarker(
                    location=[p["lat"], p["lon"]],
                    radius=6,
                    color=color,
                    fill=True,
                    fill_opacity=0.8,
                    popup=folium.Popup(
                        f"<b>{p['nombre']}</b><br>"
                        f"Categoría: {p['categoria']}<br>"
                        f"Ciudad: {p['ciudad']}<br>"
                        f"Valoración: {p['valoracion']}⭐",
                        max_width=200
                    ),
                    tooltip=p["nombre"]
                ).add_to(poi_group)
            poi_group.add_to(mapa)

            # Zonas (polígonos)
            cur.execute("""
                SELECT nombre, tipo, area_km2,
                    ST_AsGeoJSON(perimetro) AS geojson
                FROM zonas WHERE perimetro IS NOT NULL
            """)
            zonas = cur.fetchall()
            zona_group = folium.FeatureGroup(name="Zonas")
            for z in zonas:
                if z["geojson"]:
                    folium.GeoJson(
                        json.loads(z["geojson"]),
                        style_function=lambda x: {
                            "fillColor": "#3388ff",
                            "color": "#1a66cc",
                            "weight": 2,
                            "fillOpacity": 0.15
                        },
                        tooltip=f"{z['nombre']} ({z['tipo']})"
                    ).add_to(zona_group)
            zona_group.add_to(mapa)

            # Rutas
            cur.execute("""
                SELECT nombre, tipo,
                    ST_AsGeoJSON(trazado) AS geojson
                FROM rutas WHERE trazado IS NOT NULL
            """)
            rutas = cur.fetchall()
            ruta_group = folium.FeatureGroup(name="Rutas")
            ruta_colors = {
                "autopista": "red", "nacional": "orange",
                "comarcal": "blue", "ciclista": "green",
                "senderismo": "brown"
            }
            for r in rutas:
                if r["geojson"]:
                    folium.GeoJson(
                        json.loads(r["geojson"]),
                        style_function=lambda x, tipo=r["tipo"]: {
                            "color": ruta_colors.get(tipo, "gray"),
                            "weight": 3,
                            "opacity": 0.8
                        },
                        tooltip=f"{r['nombre']} ({r['tipo']})"
                    ).add_to(ruta_group)
            ruta_group.add_to(mapa)

            # Trazas GPS de vehículos
            cur.execute("""
                SELECT v.matricula,
                    ST_Y(t.posicion::geometry) AS lat,
                    ST_X(t.posicion::geometry) AS lon,
                    t.velocidad, t.timestamp
                FROM trazas_gps t
                JOIN vehiculos v ON v.id = t.vehiculo_id
                ORDER BY v.id, t.timestamp
            """)
            gps_rows = cur.fetchall()
            gps_group = folium.FeatureGroup(name="Trazas GPS")
            # Agrupar por matrícula
            from itertools import groupby
            gps_rows_sorted = sorted(gps_rows, key=lambda x: x["matricula"])
            veh_colors = ["darkred", "darkblue", "darkgreen"]
            for idx, (matricula, puntos) in enumerate(
                groupby(gps_rows_sorted, key=lambda x: x["matricula"])
            ):
                puntos_list = list(puntos)
                coords = [(p["lat"], p["lon"]) for p in puntos_list]
                color = veh_colors[idx % len(veh_colors)]
                if len(coords) >= 2:
                    folium.PolyLine(
                        coords, color=color, weight=2.5,
                        opacity=0.9, tooltip=f"Vehículo {matricula}"
                    ).add_to(gps_group)
                # Último punto del vehículo
                last = puntos_list[-1]
                folium.Marker(
                    location=[last["lat"], last["lon"]],
                    popup=f"<b>{matricula}</b><br>Vel: {last['velocidad']} km/h",
                    icon=folium.Icon(color=color, icon="car", prefix="fa")
                ).add_to(gps_group)
            gps_group.add_to(mapa)

            folium.LayerControl().add_to(mapa)

            filename = "mapa_geoespacial.html"
            mapa.save(filename)
            print_success(
                f"Mapa HTML interactivo generado: '{filename}'\n"
                f"  Abre el archivo en tu navegador para visualizarlo."
            )
            print(f"\n  Capas incluidas:")
            print(f"  {CYAN}●{RESET} {len(pois)} Puntos de interés")
            print(f"  {CYAN}●{RESET} {len(zonas)} Zonas / polígonos")
            print(f"  {CYAN}●{RESET} {len(rutas)} Rutas")
            print(f"  {CYAN}●{RESET} Trazas GPS de vehículos")

        cur.close()
        conn.close()

    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error al exportar: {e}")
        import traceback
        traceback.print_exc()

    wait()


# ══════════════════════════════════════════════════════════
# MENÚ PRINCIPAL
# ══════════════════════════════════════════════════════════

BANNER = f"""
{CYAN}{BOLD}╔══════════════════════════════════════════════════════════════╗
║   PostGIS Geospatial Manager — PostgreSQL + PostGIS         ║
║   Base de datos: {TARGET_DB:<41}║
╚══════════════════════════════════════════════════════════════╝{RESET}
"""

MENU = f"""
{CYAN}{BOLD}── MENÚ PRINCIPAL ──────────────────────────────────────────{RESET}

  {YELLOW}[0]{RESET}  Instalar / Verificar PostGIS en el sistema  ← {RED}Empieza aquí{RESET}
  {YELLOW}[1]{RESET}  Crear base de datos PostGIS + datos de muestra
  {YELLOW}[2]{RESET}  Insertar punto de interés (POI)
  {YELLOW}[3]{RESET}  Consultas geoespaciales
       └─ Radio, KNN, contenencia, distancias, rutas, sensores
  {YELLOW}[4]{RESET}  Actualizar geometría
       └─ Mover POI, crear buffer, añadir traza GPS
  {YELLOW}[5]{RESET}  Eliminar datos geoespaciales
  {YELLOW}[6]{RESET}  Exportar GeoJSON / Mapa HTML interactivo
  {YELLOW}[q]{RESET}  Salir

{CYAN}────────────────────────────────────────────────────────────{RESET}
"""


def main():
    print(BANNER)
    print(f"{CYAN}Configuración:{RESET}")
    print(f"  Host     : {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print(f"  Usuario  : {DB_CONFIG['user']}")
    print(f"  Base de datos destino: {BOLD}{TARGET_DB}{RESET}")
    print(f"\n{YELLOW}ℹ  Edita DB_CONFIG al inicio del script para cambiar la conexión.")
    print(f"ℹ  Si PostGIS no está instalado ejecuta primero la opción [0].{RESET}")

    # ── Comprobación automática al arrancar ───────────────
    ver = _postgis_extension_active()
    if ver:
        print(f"\n{GREEN}✔  PostGIS {ver} ya está activo en '{TARGET_DB}'.{RESET}")
    else:
        installed, pg_ver = _postgis_is_installed_on_os()
        if installed:
            print(
                f"\n{YELLOW}⚠  PostGIS está instalado en el SO (PG {pg_ver}) "
                f"pero no activo en '{TARGET_DB}'.\n"
                f"   Ejecuta la opción [0] para activarlo.{RESET}"
            )
        else:
            print(
                f"\n{RED}⚠  PostGIS NO está instalado en el sistema.\n"
                f"   Ejecuta la opción [0] para instalarlo y activarlo.{RESET}"
            )

    while True:
        print(MENU)
        choice = input(f"{BOLD}Elige una opción: {RESET}").strip().lower()

        if   choice in ("q", "quit", "exit"):
            print(f"\n{GREEN}¡Hasta luego!{RESET}\n")
            sys.exit(0)
        elif choice == "0": install_postgis()
        elif choice == "1": create_database()
        elif choice == "2": insert_poi()
        elif choice == "3": spatial_queries()
        elif choice == "4": update_geometry()
        elif choice == "5": delete_geo_data()
        elif choice == "6": export_data()
        else: print(f"\n{RED}Opción no válida.{RESET}")


if __name__ == "__main__":
    main()
