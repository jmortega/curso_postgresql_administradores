"""
=============================================================
  pgvector Manager
  Script interactivo para almacenamiento y búsqueda
  de vectores (embeddings) con PostgreSQL + pgvector
=============================================================

Requisitos:
    pip install -r requeriments.txt


"""

import sys
import os
import json
import math
import random
import subprocess
import shutil
from datetime import datetime, timedelta

try:
    import psycopg2
    from psycopg2 import sql, OperationalError
    from psycopg2.extras import RealDictCursor
    from psycopg2.extensions import register_adapter, AsIs
except ImportError:
    print("\n[ERROR] psycopg2 no instalado. Ejecuta: pip install psycopg2-binary")
    sys.exit(1)

try:
    import numpy as np
    NUMPY_OK = True
except ImportError:
    NUMPY_OK = False
    print("[AVISO] numpy no disponible: pip install numpy")

try:
    from pgvector.psycopg2 import register_vector
    PGVECTOR_ADAPTER = True
except ImportError:
    PGVECTOR_ADAPTER = False
    print("[AVISO] adaptador pgvector no disponible: pip install pgvector")

try:
    from sentence_transformers import SentenceTransformer
    ST_OK = True
except ImportError:
    ST_OK = False
    print("[AVISO] sentence-transformers no disponible: pip install sentence-transformers")

# ── Colores ANSI ──────────────────────────────────────────
RED    = "\033[91m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
MAGENTA= "\033[95m"
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

TARGET_DB    = "pgvector_db"
EMBED_MODEL  = None           # Se carga bajo demanda
EMBED_DIM    = 384            # all-MiniLM-L6-v2 → 384 dims
MODEL_NAME   = "sentence-transformers/all-MiniLM-L6-v2"

# ══════════════════════════════════════════════════════════
# DATOS DE MUESTRA
# ══════════════════════════════════════════════════════════

DOCUMENTOS_MUESTRA = [
    # Tecnología / IA
    ("La inteligencia artificial está transformando la industria tecnológica",      "tecnologia"),
    ("Machine learning y deep learning son las bases de la IA moderna",             "tecnologia"),
    ("Los modelos de lenguaje grande como GPT-4 revolucionan el procesamiento NLP", "tecnologia"),
    ("Las redes neuronales convolucionales son fundamentales en visión artificial",  "tecnologia"),
    ("El aprendizaje por refuerzo permite a los agentes aprender por ensayo-error", "tecnologia"),
    ("Los transformers han reemplazado a los RNNs en tareas de lenguaje natural",   "tecnologia"),
    ("Python es el lenguaje de programación preferido para ciencia de datos",       "tecnologia"),
    ("Docker y Kubernetes facilitan el despliegue de modelos de machine learning",  "tecnologia"),
    # Ciencia
    ("La física cuántica describe el comportamiento de partículas subatómicas",     "ciencia"),
    ("El cambio climático es uno de los mayores desafíos de la humanidad",          "ciencia"),
    ("La ingeniería genética permite modificar el ADN de organismos vivos",         "ciencia"),
    ("Los agujeros negros son regiones del espacio con gravedad extrema",           "ciencia"),
    ("La energía solar es una fuente de energía renovable y limpia",                "ciencia"),
    ("La biología molecular estudia los mecanismos moleculares de los seres vivos", "ciencia"),
    # Negocio
    ("El marketing digital es esencial para el crecimiento de las empresas online", "negocio"),
    ("La transformación digital requiere cambios culturales en las organizaciones",  "negocio"),
    ("El análisis de datos permite tomar mejores decisiones empresariales",          "negocio"),
    ("La experiencia del cliente es clave para la fidelización y retención",        "negocio"),
    ("La gestión ágil de proyectos mejora la productividad de los equipos",         "negocio"),
    ("El comercio electrónico ha crecido exponencialmente en los últimos años",     "negocio"),
    # Salud
    ("La telemedicina facilita el acceso a la atención sanitaria remota",           "salud"),
    ("La inteligencia artificial ayuda al diagnóstico médico por imagen",           "salud"),
    ("Los ensayos clínicos son fundamentales para validar nuevos tratamientos",     "salud"),
    ("La nutrición equilibrada es base de una vida saludable",                      "salud"),
    ("La salud mental es tan importante como la salud física",                      "salud"),
    # Educación
    ("El aprendizaje en línea ha democratizado el acceso a la educación global",   "educacion"),
    ("La gamificación mejora la motivación y el aprendizaje de los estudiantes",   "educacion"),
    ("Las competencias digitales son imprescindibles en el mercado laboral actual", "educacion"),
    ("El aprendizaje personalizado adapta el contenido a cada estudiante",          "educacion"),
    ("La educación STEM fomenta el pensamiento crítico y la resolución de problemas","educacion"),
]

PRODUCTOS_MUESTRA = [
    ("Laptop Gaming RTX 4080", "Portátil gaming con GPU RTX 4080, 32GB RAM, SSD 1TB", "electronica", 2499.99),
    ("Smartphone Pro Max", "Teléfono con cámara 200MP, batería 6000mAh, 5G", "electronica", 1199.00),
    ("Auriculares Noise Cancelling", "Cancelación activa de ruido, 30h batería, Bluetooth 5.3", "electronica", 349.99),
    ("Monitor 4K 144Hz", "Panel IPS 27 pulgadas, HDR600, 1ms respuesta", "electronica", 699.99),
    ("Teclado Mecánico RGB", "Switches Cherry MX Red, retroiluminación RGB, TKL", "electronica", 149.99),
    ("Zapatillas Running Pro", "Amortiguación carbono, transpirable, suela Michelin", "deportes", 189.99),
    ("Bicicleta Eléctrica", "Motor 250W, batería 50km autonomía, frenos hidráulicos", "deportes", 1299.00),
    ("Mochila Trail 30L", "Impermeable, sistema ventilación espalda, 30 litros", "deportes", 89.99),
    ("Silla Ergonómica Pro", "Soporte lumbar ajustable, reposabrazos 4D, malla transpirable", "oficina", 459.99),
    ("Escritorio Elevable", "Regulación eléctrica altura, 160x80cm, antivuelco", "oficina", 699.00),
    ("Webcam 4K Streaming", "Sensor Sony, autofoco IA, micrófono integrado, tripode", "oficina", 199.99),
    ("Libro: Python para ML", "Guía completa machine learning con Python y scikit-learn", "libros", 49.99),
    ("Libro: Deep Learning", "Fundamentos de redes neuronales y PyTorch", "libros", 55.00),
    ("Libro: SQL Avanzado", "Optimización de consultas, índices y rendimiento en PostgreSQL", "libros", 44.99),
    ("Curso Programación IA", "50 horas de contenido sobre inteligencia artificial aplicada", "cursos", 299.00),
]

PREGUNTAS_FAQ = [
    ("¿Cómo puedo devolver un producto?",
     "Puedes devolver cualquier producto en un plazo de 30 días desde la recepción. Accede a tu cuenta, selecciona el pedido y haz clic en 'Iniciar devolución'. El envío de retorno es gratuito."),
    ("¿Cuánto tarda el envío estándar?",
     "El envío estándar tarda entre 3 y 5 días laborables. El envío express llega en 24-48 horas. Los pedidos superiores a 50€ tienen envío gratuito."),
    ("¿Puedo cambiar la dirección de entrega?",
     "Puedes modificar la dirección de entrega hasta que el pedido sea procesado. Contacta con atención al cliente en las primeras 2 horas tras realizar el pedido."),
    ("¿Cómo funciona la garantía?",
     "Todos los productos tienen garantía mínima de 2 años según la legislación europea. Los productos electrónicos tienen garantía extendida de 3 años. Contacta soporte con el número de pedido."),
    ("¿Aceptan pagos en cuotas?",
     "Sí, ofrecemos financiación en 3, 6 y 12 cuotas sin intereses para compras superiores a 200€. Selecciona la opción de financiación en el proceso de pago."),
    ("¿Tienen tienda física?",
     "Disponemos de 12 tiendas físicas en las principales ciudades de España. Consulta el localizador de tiendas en nuestra web para encontrar la más cercana."),
    ("¿Cómo contactar con atención al cliente?",
     "Puedes contactarnos por chat en vivo (disponible 9h-21h), email (respuesta en 24h) o teléfono 900 XXX XXX (gratuito, lunes a viernes 9h-18h)."),
    ("¿Los precios incluyen IVA?",
     "Todos los precios mostrados en nuestra web incluyen el IVA aplicable (21% para la mayoría de productos). La factura detallada se envía por email al confirmar el pedido."),
]


# ══════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════

def get_connection(dbname=None, with_vector_adapter=True):
    """
    Abre una conexión a PostgreSQL.

    FIX: se añade el parámetro with_vector_adapter. Antes, esta función
    llamaba SIEMPRE a register_vector(conn), que ejecuta una consulta
    interna contra pg_type para resolver el OID del tipo 'vector'. Esa
    consulta abría una transacción implícita (psycopg2 no usa autocommit
    por defecto), y cuando el código posterior intentaba hacer
    `conn.autocommit = True` fallaba con:
        psycopg2.ProgrammingError: set_session cannot be used inside a transaction

    Además, register_vector() solo puede tener éxito si el tipo 'vector'
    YA EXISTE en esa base de datos — lo cual no es cierto en los puntos
    del código donde todavía se está creando la BD o activando la
    extensión por primera vez.

    Por eso:
      - with_vector_adapter=True (por defecto): uso normal, una vez que
        sabemos que 'vector' ya existe en la BD destino.
      - with_vector_adapter=False: usado en los puntos que crean la BD
        o activan la extensión, donde 'vector' aún no está disponible.

    Cuando sí se registra el adaptador, se activa autocommit=True ANTES
    de llamar a register_vector(), evitando que su consulta interna deje
    una transacción abierta.
    """
    cfg = {**DB_CONFIG}
    if dbname:
        cfg["dbname"] = dbname
    conn = psycopg2.connect(**cfg)

    if PGVECTOR_ADAPTER and with_vector_adapter:
        try:
            conn.autocommit = True
            register_vector(conn)
        except Exception:
            # El tipo 'vector' no existe aún en esta BD — seguimos sin
            # el adaptador; el caller decide qué hacer a continuación.
            pass

    return conn


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


def get_embed_model():
    """Carga el modelo de sentence-transformers bajo demanda."""
    global EMBED_MODEL
    if EMBED_MODEL is None:
        if not ST_OK:
            print_error(
                "sentence-transformers no instalado.\n"
                "  Ejecuta: pip install sentence-transformers"
            )
            return None
        print(f"\n{YELLOW}⏳ Cargando modelo '{MODEL_NAME}'...{RESET}")
        EMBED_MODEL = SentenceTransformer(MODEL_NAME)
        print_success(f"Modelo cargado ({EMBED_DIM} dimensiones).")
    return EMBED_MODEL


def embed_text(text: str) -> list:
    """Genera el embedding de un texto."""
    model = get_embed_model()
    if model is None:
        return None
    vec = model.encode(text, normalize_embeddings=True)
    return vec.tolist()


def embed_texts(texts: list) -> list:
    """Genera embeddings para una lista de textos (más eficiente)."""
    model = get_embed_model()
    if model is None:
        return None
    vecs = model.encode(texts, batch_size=32,
                        normalize_embeddings=True,
                        show_progress_bar=len(texts) > 10)
    return [v.tolist() for v in vecs]


def fmt_vec(vec: list, n=6) -> str:
    """Formatea un vector mostrando solo los primeros n valores."""
    if vec is None:
        return "None"
    preview = [f"{v:.4f}" for v in vec[:n]]
    return f"[{', '.join(preview)}, ... ] ({len(vec)} dims)"


def similarity_bar(score: float, width=20) -> str:
    """Barra visual de similitud."""
    filled = int(score * width)
    color  = GREEN if score > 0.8 else YELLOW if score > 0.6 else RED
    return f"{color}{'█' * filled}{'░' * (width - filled)}{RESET} {score:.4f}"


def vec_to_pg(vec: list) -> str:
    """Convierte lista de floats al formato literal de pgvector."""
    return "[" + ",".join(str(v) for v in vec) + "]"


# ══════════════════════════════════════════════════════════
# OPCIÓN 0 — INSTALAR / VERIFICAR PGVECTOR
# ══════════════════════════════════════════════════════════

def install_pgvector():
    print_separator()
    print(f"{BOLD}0. Instalar / Verificar pgvector{RESET}\n")

    import platform, os
    sistema = platform.system()
    print(f"  Sistema operativo  : {CYAN}{sistema} {platform.release()}{RESET}")

    # ── Verificar si ya está activo en la BD ──────────────
    # FIX: with_vector_adapter=False — en este punto no sabemos todavía
    # si la extensión 'vector' existe en TARGET_DB, así que no debemos
    # intentar registrar el adaptador (fallaría si no existe).
    try:
        conn = get_connection(dbname=TARGET_DB, with_vector_adapter=False)
        cur  = conn.cursor()
        cur.execute(
            "SELECT extversion FROM pg_extension WHERE extname = 'vector';"
        )
        row = cur.fetchone()
        cur.close(); conn.close()
        if row:
            print_success(
                f"pgvector ya está activo en '{TARGET_DB}' "
                f"(versión {row[0]}). No se necesita ninguna acción."
            )
            wait()
            return
    except Exception:
        pass

    # ── Verificar si el archivo .control existe en el SO ──
    import re
    pg_ver = None
    try:
        rc = subprocess.run(
            ["pg_config", "--version"], capture_output=True, text=True
        )
        if rc.returncode == 0:
            m = re.search(r"(\d+)\.", rc.stdout)
            if m:
                pg_ver = int(m.group(1))
    except FileNotFoundError:
        pass

    print(f"  PostgreSQL versión : {CYAN}{pg_ver or 'desconocida'}{RESET}")

    pkg_ver = str(pg_ver) if pg_ver else "16"
    control_paths = [
        f"/usr/share/postgresql/{pkg_ver}/extension/vector.control",
        "/usr/share/postgresql/extension/vector.control",
        "/usr/local/share/postgresql/extension/vector.control",
    ]
    installed_os = any(os.path.exists(p) for p in control_paths)
    print(f"  pgvector en el SO  : "
          f"{'✔ Instalado' if installed_os else RED + '✗ No encontrado' + RESET}")

    if installed_os:
        print_info("pgvector está en el SO. Activando la extensión en la BD...")
        _activate_vector_extension()
        wait()
        return

    # ── Instrucciones de instalación ──────────────────────
    print(f"\n{YELLOW}pgvector no está instalado. Opciones disponibles:{RESET}\n")

    if sistema == "Linux" and shutil.which("apt-get"):
        pkg = f"postgresql-{pkg_ver}-pgvector"
        print(f"  {CYAN}Ubuntu / Debian:{RESET}")
        print(f"  $ sudo apt-get install {pkg}\n")
        confirm = input(
            f"{YELLOW}¿Ejecutar el comando anterior automáticamente? (s/n): {RESET}"
        ).strip().lower()
        if confirm == "s":
            print(f"\n{YELLOW}⏳ Ejecutando apt-get...{RESET}")
            rc = subprocess.run(
                ["sudo", "apt-get", "install", "-y", pkg],
                capture_output=False
            )
            if rc.returncode == 0:
                print_success(f"Paquete '{pkg}' instalado.")
                _activate_vector_extension()
            else:
                print_error("Instalación fallida. Inténtalo manualmente.")
        else:
            _print_pgvector_manual(sistema, pkg_ver)

    elif sistema == "Darwin" and shutil.which("brew"):
        print(f"  {CYAN}macOS con Homebrew:{RESET}")
        print(f"  $ brew install pgvector\n")
        confirm = input(
            f"{YELLOW}¿Ejecutar 'brew install pgvector'? (s/n): {RESET}"
        ).strip().lower()
        if confirm == "s":
            print(f"\n{YELLOW}⏳ Ejecutando brew install pgvector...{RESET}")
            rc = subprocess.run(["brew", "install", "pgvector"], capture_output=False)
            if rc.returncode == 0:
                print_success("pgvector instalado via Homebrew.")
                _activate_vector_extension()
            else:
                print_error("Instalación fallida.")
        else:
            _print_pgvector_manual(sistema, pkg_ver)

    else:
        _print_pgvector_manual(sistema, pkg_ver)

    # Verificar adaptador Python
    print(f"\n{BOLD}Adaptador Python pgvector:{RESET}")
    if PGVECTOR_ADAPTER:
        print_success("  pgvector Python adapter instalado.")
    else:
        print(f"  {YELLOW}⚠  No instalado. Ejecuta:{RESET}")
        print(f"     pip install pgvector")

    wait()


def _activate_vector_extension():
    """
    Crea la BD si no existe y activa la extensión vector.

    FIX: ambas conexiones usan with_vector_adapter=False.
      - La primera conecta a la BD por defecto (DB_CONFIG['dbname'],
        normalmente 'postgres'), donde el tipo 'vector' nunca existe:
        solo se usa para emitir CREATE DATABASE.
      - La segunda conecta a TARGET_DB pero el tipo 'vector' todavía
        no está registrado porque la extensión se activa justo en esa
        misma conexión (CREATE EXTENSION). Intentar registrar el
        adaptador antes de esa sentencia fallaría.
    """
    # Crear BD si no existe
    try:
        conn = get_connection(with_vector_adapter=False)
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
        cur.close(); conn.close()
    except OperationalError as e:
        print_error(f"Error de conexión: {e}")
        return

    # Activar extensión
    try:
        conn = get_connection(dbname=TARGET_DB, with_vector_adapter=False)
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        cur.execute(
            "SELECT extversion FROM pg_extension WHERE extname='vector';"
        )
        ver = cur.fetchone()[0]
        cur.close(); conn.close()
        print_success(
            f"Extensión 'vector' activada en '{TARGET_DB}' (v{ver}).\n"
            f"  Ahora ejecuta la opción {BOLD}[1]{RESET}{GREEN} "
            f"para crear el esquema."
        )
    except Exception as e:
        print_error(f"No se pudo activar la extensión: {e}")


def _print_pgvector_manual(sistema, pkg_ver):
    print(f"\n{BOLD}{'─'*55}{RESET}")
    print(f"{BOLD}  Instrucciones de instalación manual{RESET}")
    print(f"{BOLD}{'─'*55}{RESET}\n")
    print(f"  {CYAN}Ubuntu/Debian:{RESET}")
    print(f"  $ sudo apt-get install postgresql-{pkg_ver}-pgvector\n")
    print(f"  {CYAN}macOS:{RESET}")
    print(f"  $ brew install pgvector\n")
    print(f"  {CYAN}Compilar desde fuente (cualquier SO):{RESET}")
    print(f"  $ git clone https://github.com/pgvector/pgvector.git")
    print(f"  $ cd pgvector && make && sudo make install\n")
    print(f"  {CYAN}Docker (sin instalación en SO):{RESET}")
    print(f"  $ docker run -e POSTGRES_PASSWORD=postgres \\")
    print(f"               -p 5432:5432 \\")
    print(f"               pgvector/pgvector:pg16\n")
    print(f"  {CYAN}Documentación:{RESET} https://github.com/pgvector/pgvector\n")
    print(f"{'─'*55}")


# ══════════════════════════════════════════════════════════
# OPCIÓN 1 — CREAR BASE DE DATOS Y ESQUEMA
# ══════════════════════════════════════════════════════════

def create_schema():
    print_separator()
    print(f"{BOLD}1. Crear esquema pgvector y datos de muestra{RESET}\n")

    # Crear BD
    # FIX: with_vector_adapter=False — conectamos a la BD por defecto
    # (no a TARGET_DB), donde 'vector' nunca está instalado.
    try:
        conn = get_connection(with_vector_adapter=False)
        conn.autocommit = True
        cur  = conn.cursor()
        cur.execute(
            "SELECT 1 FROM pg_database WHERE datname = %s", (TARGET_DB,)
        )
        if not cur.fetchone():
            cur.execute(
                sql.SQL("CREATE DATABASE {}").format(sql.Identifier(TARGET_DB))
            )
            print_success(f"Base de datos '{TARGET_DB}' creada.")
        else:
            print_info(f"'{TARGET_DB}' ya existe.")
        cur.close(); conn.close()
    except OperationalError as e:
        print_error(f"Error de conexión: {e}")
        wait(); return

    # FIX: with_vector_adapter=False — la extensión se activa con
    # CREATE EXTENSION justo en este bloque; antes de ejecutarlo el
    # tipo 'vector' todavía no existe en TARGET_DB.
    try:
        conn = get_connection(dbname=TARGET_DB, with_vector_adapter=False)
        conn.autocommit = True
        cur  = conn.cursor()

        # Activar extensión
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        cur.execute(
            "SELECT extversion FROM pg_extension WHERE extname='vector';"
        )
        ver = cur.fetchone()[0]
        print_success(f"pgvector {ver} activo.")

        # ── Tabla 1: Documentos de texto ──────────────────
        cur.execute(f"""
        CREATE TABLE IF NOT EXISTS documentos (
            id          SERIAL PRIMARY KEY,
            titulo      TEXT NOT NULL,
            contenido   TEXT NOT NULL,
            categoria   VARCHAR(100),
            fuente      VARCHAR(200),
            n_tokens    INTEGER,
            modelo      VARCHAR(100) DEFAULT '{MODEL_NAME}',
            embedding   vector({EMBED_DIM}),
            creado_en   TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_docs_hnsw
            ON documentos
            USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64);
        CREATE INDEX IF NOT EXISTS idx_docs_categoria
            ON documentos (categoria);
        """)
        print_success("Tabla 'documentos' + índice HNSW creados.")

        # ── Tabla 2: Productos (recomendador) ─────────────
        cur.execute(f"""
        CREATE TABLE IF NOT EXISTS productos (
            id          SERIAL PRIMARY KEY,
            nombre      TEXT NOT NULL,
            descripcion TEXT,
            categoria   VARCHAR(100),
            precio      NUMERIC(10,2),
            modelo      VARCHAR(100) DEFAULT '{MODEL_NAME}',
            embedding   vector({EMBED_DIM}),
            creado_en   TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_prods_hnsw
            ON productos
            USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64);
        """)
        print_success("Tabla 'productos' + índice HNSW creados.")

        # ── Tabla 3: FAQ (base de conocimiento para RAG) ──
        cur.execute(f"""
        CREATE TABLE IF NOT EXISTS faq (
            id          SERIAL PRIMARY KEY,
            pregunta    TEXT NOT NULL,
            respuesta   TEXT NOT NULL,
            categoria   VARCHAR(100) DEFAULT 'general',
            modelo      VARCHAR(100) DEFAULT '{MODEL_NAME}',
            embedding   vector({EMBED_DIM}),  -- Embedding de la pregunta
            creado_en   TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_faq_hnsw
            ON faq
            USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64);
        """)
        print_success("Tabla 'faq' (RAG) + índice HNSW creados.")

        # ── Tabla 4: Chunks para RAG ──────────────────────
        cur.execute(f"""
        CREATE TABLE IF NOT EXISTS chunks_rag (
            id              SERIAL PRIMARY KEY,
            documento_nombre TEXT NOT NULL,
            chunk_index     INTEGER NOT NULL,
            contenido       TEXT NOT NULL,
            n_tokens        INTEGER,
            metadatos       JSONB DEFAULT '{{}}',
            modelo          VARCHAR(100) DEFAULT '{MODEL_NAME}',
            embedding       vector({EMBED_DIM}),
            creado_en       TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_chunks_hnsw
            ON chunks_rag
            USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64);
        """)
        print_success("Tabla 'chunks_rag' + índice HNSW creados.")

        cur.close(); conn.close()

        # Insertar datos de muestra
        _insert_sample_vectors()

    except Exception as e:
        print_error(f"Error al crear el esquema: {e}")
        import traceback; traceback.print_exc()

    wait()


def _insert_sample_vectors():
    """
    Genera embeddings e inserta los datos de muestra.

    Aquí sí usamos with_vector_adapter=True (el valor por defecto):
    en este punto del flujo, create_schema() ya ejecutó
    CREATE EXTENSION IF NOT EXISTS vector, así que el tipo 'vector'
    existe en TARGET_DB y register_vector() puede resolverlo sin error.
    """
    model = get_embed_model()
    if model is None:
        print_info(
            "Sin modelo de embeddings. Instala sentence-transformers "
            "para insertar datos de muestra con vectores reales."
        )
        return

    conn = get_connection(dbname=TARGET_DB)
    cur  = conn.cursor()

    try:
        # ── Documentos ────────────────────────────────────
        textos_doc = [d[0] for d in DOCUMENTOS_MUESTRA]
        print(f"\n{YELLOW}⏳ Generando embeddings para {len(textos_doc)} documentos...{RESET}")
        embs_doc = embed_texts(textos_doc)

        for i, ((texto, cat), emb) in enumerate(
            zip(DOCUMENTOS_MUESTRA, embs_doc)
        ):
            cur.execute("""
                INSERT INTO documentos
                    (titulo, contenido, categoria, n_tokens, embedding)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (
                texto[:80], texto, cat,
                len(texto.split()), vec_to_pg(emb)
            ))
        print_success(f"{len(textos_doc)} documentos insertados con embeddings.")

        # ── Productos ─────────────────────────────────────
        textos_prod = [
            f"{p[0]}. {p[1]}" for p in PRODUCTOS_MUESTRA
        ]
        print(f"{YELLOW}⏳ Generando embeddings para {len(textos_prod)} productos...{RESET}")
        embs_prod = embed_texts(textos_prod)

        for (nombre, desc, cat, precio), emb in zip(PRODUCTOS_MUESTRA, embs_prod):
            cur.execute("""
                INSERT INTO productos
                    (nombre, descripcion, categoria, precio, embedding)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (nombre, desc, cat, precio, vec_to_pg(emb)))
        print_success(f"{len(textos_prod)} productos insertados con embeddings.")

        # ── FAQ ───────────────────────────────────────────
        preguntas = [q[0] for q in PREGUNTAS_FAQ]
        print(f"{YELLOW}⏳ Generando embeddings para {len(preguntas)} FAQs...{RESET}")
        embs_faq = embed_texts(preguntas)

        for (pregunta, respuesta), emb in zip(PREGUNTAS_FAQ, embs_faq):
            cur.execute("""
                INSERT INTO faq (pregunta, respuesta, embedding)
                VALUES (%s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (pregunta, respuesta, vec_to_pg(emb)))
        print_success(f"{len(preguntas)} FAQs insertadas con embeddings.")

        # ── Chunks RAG (fragmentar los documentos largos) ─
        print(f"{YELLOW}⏳ Generando chunks para RAG...{RESET}")
        chunk_texts  = []
        chunk_metas  = []
        # Simular un documento técnico dividido en chunks
        doc_largo = [
            "PostgreSQL es un sistema de base de datos relacional avanzado de código abierto.",
            "pgvector añade soporte para vectores de alta dimensionalidad en PostgreSQL.",
            "Los embeddings son representaciones numéricas densas de objetos en un espacio vectorial.",
            "La búsqueda semántica encuentra documentos similares en significado, no solo en palabras.",
            "El índice HNSW permite búsquedas aproximadas de vecinos cercanos con alta eficiencia.",
            "RAG combina recuperación de información con generación de texto por LLMs.",
            "Los modelos de sentence-transformers generan embeddings de alta calidad de forma gratuita.",
            "La similitud coseno es la métrica más usada para comparar embeddings de texto.",
        ]
        for i, chunk in enumerate(doc_largo):
            chunk_texts.append(chunk)
            chunk_metas.append({
                "doc": "Manual pgvector",
                "idx": i,
                "palabras": len(chunk.split())
            })

        embs_chunks = embed_texts(chunk_texts)
        for (txt, meta), emb in zip(
            zip(chunk_texts, chunk_metas), embs_chunks
        ):
            cur.execute("""
                INSERT INTO chunks_rag
                    (documento_nombre, chunk_index, contenido,
                     n_tokens, metadatos, embedding)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                meta["doc"], meta["idx"], txt,
                meta["palabras"],
                json.dumps(meta),
                vec_to_pg(emb)
            ))
        print_success(f"{len(chunk_texts)} chunks RAG insertados.")

        conn.commit()

    except Exception as e:
        conn.rollback()
        print_error(f"Error al insertar datos: {e}")
        import traceback; traceback.print_exc()
    finally:
        cur.close(); conn.close()


# ══════════════════════════════════════════════════════════
# OPCIÓN 2 — INSERTAR TEXTO Y GENERAR EMBEDDING
# ══════════════════════════════════════════════════════════

def insert_document():
    print_separator()
    print(f"{BOLD}2. Insertar documento y generar embedding{RESET}\n")

    print(f"  {YELLOW}[1]{RESET}  Insertar documento de texto")
    print(f"  {YELLOW}[2]{RESET}  Insertar producto")
    print(f"  {YELLOW}[3]{RESET}  Insertar pregunta FAQ")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor()

        if choice == "1":
            titulo    = input("Título del documento: ").strip() or "Sin título"
            contenido = input("Contenido: ").strip()
            if not contenido:
                print_error("El contenido no puede estar vacío.")
                cur.close(); conn.close(); wait(); return
            categorias = ["tecnologia","ciencia","negocio","salud","educacion","otro"]
            print(f"Categorías: {', '.join(categorias)}")
            categoria = input("Categoría [otro]: ").strip() or "otro"
            fuente    = input("Fuente/URL (opcional): ").strip() or None

            print(f"\n{YELLOW}⏳ Generando embedding...{RESET}")
            emb = embed_text(contenido)
            if emb is None:
                cur.close(); conn.close(); wait(); return

            cur.execute("""
                INSERT INTO documentos
                    (titulo, contenido, categoria, fuente, n_tokens, embedding)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (titulo, contenido, categoria, fuente,
                  len(contenido.split()), vec_to_pg(emb)))
            new_id = cur.fetchone()[0]
            conn.commit()
            print_success(f"Documento insertado — ID={new_id}")
            print(f"  Embedding: {fmt_vec(emb)}")

        elif choice == "2":
            nombre = input("Nombre del producto: ").strip()
            desc   = input("Descripción: ").strip()
            cat    = input("Categoría: ").strip() or "general"
            precio_str = input("Precio: ").strip() or "0"
            try:
                precio = float(precio_str)
            except ValueError:
                precio = 0.0

            print(f"\n{YELLOW}⏳ Generando embedding para '{nombre}'...{RESET}")
            texto_emb = f"{nombre}. {desc}"
            emb = embed_text(texto_emb)
            if emb is None:
                cur.close(); conn.close(); wait(); return

            cur.execute("""
                INSERT INTO productos (nombre, descripcion, categoria, precio, embedding)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
            """, (nombre, desc, cat, precio, vec_to_pg(emb)))
            new_id = cur.fetchone()[0]
            conn.commit()
            print_success(f"Producto insertado — ID={new_id}")
            print(f"  Embedding: {fmt_vec(emb)}")

        elif choice == "3":
            pregunta  = input("Pregunta: ").strip()
            respuesta = input("Respuesta: ").strip()
            if not pregunta or not respuesta:
                print_error("Pregunta y respuesta son obligatorias.")
                cur.close(); conn.close(); wait(); return

            print(f"\n{YELLOW}⏳ Generando embedding de la pregunta...{RESET}")
            emb = embed_text(pregunta)
            if emb is None:
                cur.close(); conn.close(); wait(); return

            cur.execute("""
                INSERT INTO faq (pregunta, respuesta, embedding)
                VALUES (%s, %s, %s)
                RETURNING id
            """, (pregunta, respuesta, vec_to_pg(emb)))
            new_id = cur.fetchone()[0]
            conn.commit()
            print_success(f"FAQ insertada — ID={new_id}")

        else:
            print_error("Opción no válida.")

        cur.close(); conn.close()
    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error: {e}")
        import traceback; traceback.print_exc()

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 3 — BÚSQUEDA SEMÁNTICA
# ══════════════════════════════════════════════════════════

def semantic_search():
    print_separator()
    print(f"{BOLD}3. Búsqueda semántica (similaridad vectorial){RESET}\n")

    print(f"  {YELLOW}[1]{RESET}  Búsqueda en documentos (distancia coseno)")
    print(f"  {YELLOW}[2]{RESET}  Búsqueda filtrada por categoría")
    print(f"  {YELLOW}[3]{RESET}  Búsqueda con umbral de similitud")
    print(f"  {YELLOW}[4]{RESET}  Comparar métricas (L2 vs Coseno vs Dot product)")
    print(f"  {YELLOW}[5]{RESET}  Búsqueda híbrida (vectorial + texto completo)")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    query = input(f"\n{YELLOW}Texto de búsqueda: {RESET}").strip()
    if not query:
        print_error("La consulta no puede estar vacía.")
        wait(); return

    print(f"\n{YELLOW}⏳ Generando embedding de la consulta...{RESET}")
    emb = embed_text(query)
    if emb is None:
        wait(); return
    print(f"  Query embedding: {fmt_vec(emb)}")

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)
        q_vec = vec_to_pg(emb)

        if choice == "1":
            n = int(input("Número de resultados [5]: ").strip() or "5")
            cur.execute(f"""
                SELECT
                    id, titulo, categoria,
                    LEFT(contenido, 80) AS resumen,
                    1 - (embedding <=> %s::vector) AS similitud
                FROM documentos
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, (q_vec, q_vec, n))
            rows = cur.fetchall()
            _print_search_results(rows, query, "coseno")

        elif choice == "2":
            cat = input("Categoría a filtrar: ").strip()
            n   = int(input("Número de resultados [5]: ").strip() or "5")
            cur.execute(f"""
                SELECT
                    id, titulo, categoria,
                    LEFT(contenido, 80) AS resumen,
                    1 - (embedding <=> %s::vector) AS similitud
                FROM documentos
                WHERE categoria = %s
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, (q_vec, cat, q_vec, n))
            rows = cur.fetchall()
            _print_search_results(rows, query, f"coseno (cat={cat})")

        elif choice == "3":
            umbral = float(input("Umbral de similitud mínimo [0.7]: ").strip() or "0.7")
            cur.execute(f"""
                SELECT
                    id, titulo, categoria,
                    LEFT(contenido, 80) AS resumen,
                    1 - (embedding <=> %s::vector) AS similitud
                FROM documentos
                WHERE 1 - (embedding <=> %s::vector) >= %s
                ORDER BY embedding <=> %s::vector
                LIMIT 20
            """, (q_vec, q_vec, umbral, q_vec))
            rows = cur.fetchall()
            _print_search_results(rows, query, f"coseno ≥ {umbral}")

        elif choice == "4":
            n = 5
            # L2
            cur.execute(f"""
                SELECT titulo,
                    embedding <-> %s::vector AS dist_l2,
                    1 - (embedding <=> %s::vector) AS sim_coseno,
                    (embedding <#> %s::vector) * -1 AS dot_product
                FROM documentos
                ORDER BY embedding <-> %s::vector
                LIMIT %s
            """, (q_vec, q_vec, q_vec, q_vec, n))
            rows = cur.fetchall()
            print(f"\n{BOLD}Comparativa de métricas para: '{query}'{RESET}")
            print_separator("─")
            print(f"  {'Título':<35} {'L2 (↓)':>10} {'Coseno (↑)':>12} {'Dot (↑)':>10}")
            print_separator("─")
            for r in rows:
                print(
                    f"  {str(r['titulo'])[:34]:<35} "
                    f"{CYAN}{float(r['dist_l2']):.4f}{RESET}     "
                    f"{GREEN}{float(r['sim_coseno']):.4f}{RESET}     "
                    f"{YELLOW}{float(r['dot_product']):.4f}{RESET}"
                )
            print_separator("─")
            print_info(
                "L2: distancia euclidiana (↓ mejor)  "
                "Coseno: similitud coseno (↑ mejor)  "
                "Dot: producto escalar (↑ mejor, válido con vectores normalizados)"
            )

        elif choice == "5":
            # Búsqueda híbrida
            n = int(input("Número de resultados [8]: ").strip() or "8")
            peso_vector = 0.6
            peso_texto  = 0.4
            cur.execute(f"""
                SELECT
                    id, titulo, categoria,
                    LEFT(contenido, 80) AS resumen,
                    1 - (embedding <=> %s::vector) AS sim_vector,
                    COALESCE(
                        ts_rank(
                            to_tsvector('spanish', contenido),
                            plainto_tsquery('spanish', %s)
                        ), 0
                    ) AS score_texto,
                    {peso_vector} * (1 - (embedding <=> %s::vector))
                    + {peso_texto} * COALESCE(
                        ts_rank(
                            to_tsvector('spanish', contenido),
                            plainto_tsquery('spanish', %s)
                        ), 0
                    ) AS score_hibrido
                FROM documentos
                ORDER BY score_hibrido DESC
                LIMIT %s
            """, (q_vec, query, q_vec, query, n))
            rows = cur.fetchall()
            print(f"\n{BOLD}Búsqueda híbrida: '{query}'{RESET}")
            print_separator("─")
            print(f"  Ponderación: {CYAN}{peso_vector*100:.0f}% vectorial{RESET} + "
                  f"{YELLOW}{peso_texto*100:.0f}% texto completo{RESET}")
            print_separator("─")
            print(f"  {'Título':<35} {'Vector':>8} {'Texto':>8} {'Híbrido':>9}")
            print_separator("─")
            for r in rows:
                print(
                    f"  {str(r['titulo'])[:34]:<35} "
                    f"{CYAN}{float(r['sim_vector']):.4f}{RESET}   "
                    f"{YELLOW}{float(r['score_texto']):.4f}{RESET}   "
                    f"{GREEN}{float(r['score_hibrido']):.4f}{RESET}"
                )

        cur.close(); conn.close()
    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error en la búsqueda: {e}")
        import traceback; traceback.print_exc()

    wait()


def _print_search_results(rows, query, metrica):
    """Imprime resultados de búsqueda semántica formateados."""
    print(f"\n{BOLD}Resultados para: '{query}' [{metrica}]{RESET}")
    print_separator("─")
    if not rows:
        print_info("No se encontraron resultados.")
        return
    for i, r in enumerate(rows, 1):
        sim = float(r["similitud"])
        print(f"\n  {BOLD}{i}.{RESET} {r['titulo']}")
        print(f"     {CYAN}Categoría:{RESET} {r['categoria']}")
        print(f"     {CYAN}Similitud:{RESET} {similarity_bar(sim)}")
        if r.get("resumen"):
            print(f"     {CYAN}Resumen  :{RESET} {r['resumen']}...")
    print_separator("─")
    print(f"  Total: {BOLD}{len(rows)}{RESET} resultado(s).")


# ══════════════════════════════════════════════════════════
# OPCIÓN 4 — SISTEMA DE RECOMENDACIONES
# ══════════════════════════════════════════════════════════

def recommendations():
    print_separator()
    print(f"{BOLD}4. Sistema de recomendaciones vectorial{RESET}\n")

    print(f"  {YELLOW}[1]{RESET}  Productos similares a un producto dado")
    print(f"  {YELLOW}[2]{RESET}  Buscar productos por descripción")
    print(f"  {YELLOW}[3]{RESET}  Recomendación por preferencias del usuario")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            # Listar productos disponibles
            cur.execute(
                "SELECT id, nombre, categoria, precio FROM productos ORDER BY id"
            )
            prods = cur.fetchall()
            print(f"\n{BOLD}Productos disponibles:{RESET}")
            print_separator("─")
            for p in prods:
                print(f"  {p['id']:3}. {str(p['nombre']):<35} "
                      f"{str(p['categoria']):<15} {p['precio']:.2f}€")
            print_separator("─")

            prod_id = input("\nID del producto de referencia: ").strip()
            n = int(input("Número de recomendaciones [5]: ").strip() or "5")

            cur.execute(f"""
                SELECT
                    b.id, b.nombre, b.descripcion, b.categoria, b.precio,
                    1 - (b.embedding <=> a.embedding) AS similitud
                FROM productos a, productos b
                WHERE a.id = %s
                  AND b.id != %s
                ORDER BY b.embedding <=> a.embedding
                LIMIT %s
            """, (prod_id, prod_id, n))
            rows = cur.fetchall()

            cur.execute("SELECT nombre FROM productos WHERE id = %s", (prod_id,))
            ref = cur.fetchone()
            print(f"\n{BOLD}Productos similares a '{ref['nombre']}':{RESET}")
            print_separator("─")
            for r in rows:
                sim = float(r["similitud"])
                print(f"\n  {BOLD}{r['nombre']}{RESET}  "
                      f"{CYAN}[{r['categoria']}]{RESET}  {r['precio']:.2f}€")
                print(f"  Similitud: {similarity_bar(sim)}")
                print(f"  {r['descripcion'][:80]}...")

        elif choice == "2":
            query = input("Describe el producto que buscas: ").strip()
            if not query:
                print_error("La consulta no puede estar vacía.")
                cur.close(); conn.close(); wait(); return
            cat   = input("Filtrar por categoría (Enter = todas): ").strip() or None
            n     = int(input("Número de resultados [5]: ").strip() or "5")

            print(f"\n{YELLOW}⏳ Generando embedding...{RESET}")
            emb   = embed_text(query)
            if emb is None:
                cur.close(); conn.close(); wait(); return
            q_vec = vec_to_pg(emb)

            where = "WHERE categoria = %s" if cat else ""
            params = (q_vec, q_vec, n) if not cat else (q_vec, cat, q_vec, n)
            cur.execute(f"""
                SELECT nombre, descripcion, categoria, precio,
                    1 - (embedding <=> %s::vector) AS similitud
                FROM productos
                {where}
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, params)
            rows = cur.fetchall()

            print(f"\n{BOLD}Productos para: '{query}'{RESET}")
            print_separator("─")
            for r in rows:
                sim = float(r["similitud"])
                print(f"\n  {BOLD}{r['nombre']}{RESET}  "
                      f"{CYAN}[{r['categoria']}]{RESET}  {r['precio']:.2f}€")
                print(f"  Similitud: {similarity_bar(sim)}")

        elif choice == "3":
            # Simular perfil de usuario como promedio de embeddings de productos vistos
            print(f"\n{CYAN}Simulación de recomendación por historial de usuario.{RESET}")
            print("Introduce los IDs de productos que el usuario ha visto (separados por coma):")
            cur.execute(
                "SELECT id, nombre FROM productos ORDER BY id"
            )
            prods = cur.fetchall()
            for p in prods:
                print(f"  {p['id']:2}. {p['nombre']}")

            ids_str = input("\nIDs vistos (ej: 1,3,5): ").strip()
            try:
                ids_vistos = [int(x.strip()) for x in ids_str.split(",")]
            except ValueError:
                print_error("IDs inválidos.")
                cur.close(); conn.close(); wait(); return

            # Calcular centroide del perfil
            cur.execute(f"""
                SELECT avg(embedding) AS perfil
                FROM productos
                WHERE id = ANY(%s)
            """, (ids_vistos,))
            row = cur.fetchone()
            if not row or row["perfil"] is None:
                print_error("No se pudo calcular el perfil del usuario.")
                cur.close(); conn.close(); wait(); return

            # FIX: con register_vector(conn) activo, psycopg2 decodifica
            # la columna `vector` como un array de numpy. str() sobre un
            # array numpy produce su repr ("[ 0.012 -0.03 ... ]" con
            # notación científica y saltos de línea), que NO es el
            # formato literal que pgvector acepta en SQL ("[0.012,-0.03,...]").
            # Hay que reconstruir el literal explícitamente con vec_to_pg(),
            # igual que se hace con los embeddings generados por el modelo.
            perfil = row["perfil"]
            if hasattr(perfil, "tolist"):
                perfil_str = vec_to_pg(perfil.tolist())
            else:
                # Fallback si llega como string "[..]" tal cual
                perfil_str = str(perfil)
            n = int(input("Número de recomendaciones [5]: ").strip() or "5")

            cur.execute(f"""
                SELECT nombre, descripcion, categoria, precio,
                    1 - (embedding <=> %s::vector) AS afinidad
                FROM productos
                WHERE id != ALL(%s)
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, (perfil_str, ids_vistos, perfil_str, n))
            rows = cur.fetchall()

            print(f"\n{BOLD}Recomendaciones basadas en tu perfil:{RESET}")
            print_separator("─")
            for r in rows:
                afin = float(r["afinidad"])
                print(f"\n  {BOLD}{r['nombre']}{RESET}  "
                      f"{CYAN}[{r['categoria']}]{RESET}  {r['precio']:.2f}€")
                print(f"  Afinidad: {similarity_bar(afin)}")

        cur.close(); conn.close()
    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error: {e}")
        import traceback; traceback.print_exc()

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 5 — RAG (Retrieval Augmented Generation)
# ══════════════════════════════════════════════════════════

def rag_demo():
    print_separator()
    print(f"{BOLD}5. RAG — Retrieval Augmented Generation{RESET}\n")
    print(
        "  RAG = Recuperar chunks relevantes → Inyectar en prompt → LLM genera respuesta\n"
    )

    print(f"  {YELLOW}[1]{RESET}  Buscar en FAQ (preguntas frecuentes)")
    print(f"  {YELLOW}[2]{RESET}  Buscar en chunks de documentos")
    print(f"  {YELLOW}[3]{RESET}  Demo RAG completo (recuperar + mostrar prompt)")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    pregunta = input(f"\n{YELLOW}¿Cuál es tu pregunta? {RESET}").strip()
    if not pregunta:
        print_error("La pregunta no puede estar vacía.")
        wait(); return

    print(f"\n{YELLOW}⏳ Generando embedding de la pregunta...{RESET}")
    emb = embed_text(pregunta)
    if emb is None:
        wait(); return
    q_vec = vec_to_pg(emb)

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            n = int(input("Número de FAQs a recuperar [3]: ").strip() or "3")
            cur.execute(f"""
                SELECT
                    pregunta,
                    respuesta,
                    1 - (embedding <=> %s::vector) AS relevancia
                FROM faq
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, (q_vec, q_vec, n))
            rows = cur.fetchall()

            print(f"\n{BOLD}FAQs más relevantes para: '{pregunta}'{RESET}")
            print_separator("─")
            for i, r in enumerate(rows, 1):
                rel = float(r["relevancia"])
                print(f"\n  {BOLD}{i}. {r['pregunta']}{RESET}")
                print(f"     Relevancia: {similarity_bar(rel)}")
                print(f"\n     {GREEN}Respuesta:{RESET} {r['respuesta']}")
                print_separator("─")

        elif choice == "2":
            n = int(input("Número de chunks a recuperar [4]: ").strip() or "4")
            cur.execute(f"""
                SELECT
                    documento_nombre,
                    chunk_index,
                    contenido,
                    metadatos,
                    1 - (embedding <=> %s::vector) AS relevancia
                FROM chunks_rag
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, (q_vec, q_vec, n))
            rows = cur.fetchall()

            print(f"\n{BOLD}Chunks más relevantes para: '{pregunta}'{RESET}")
            print_separator("─")
            for i, r in enumerate(rows, 1):
                rel = float(r["relevancia"])
                print(f"\n  {BOLD}Chunk {i}{RESET} — {r['documento_nombre']} "
                      f"(#{r['chunk_index']})")
                print(f"  Relevancia: {similarity_bar(rel)}")
                print(f"  Contenido : {r['contenido']}")

        elif choice == "3":
            # Demo RAG completo — mostrar el prompt que se enviaría al LLM
            n = int(input("Número de chunks de contexto [3]: ").strip() or "3")

            cur.execute(f"""
                SELECT contenido,
                    1 - (embedding <=> %s::vector) AS relevancia
                FROM chunks_rag
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, (q_vec, q_vec, n))
            chunks = cur.fetchall()

            cur.execute(f"""
                SELECT pregunta, respuesta,
                    1 - (embedding <=> %s::vector) AS relevancia
                FROM faq
                ORDER BY embedding <=> %s::vector
                LIMIT 2
            """, (q_vec, q_vec))
            faqs = cur.fetchall()

            # Construir el prompt RAG
            contexto_chunks = "\n\n".join([
                f"[Fragmento {i+1} — relevancia {float(c['relevancia']):.3f}]\n{c['contenido']}"
                for i, c in enumerate(chunks)
            ])
            contexto_faqs = "\n\n".join([
                f"[FAQ — relevancia {float(f['relevancia']):.3f}]\n"
                f"P: {f['pregunta']}\nR: {f['respuesta']}"
                for f in faqs
            ])

            prompt_rag = f"""Eres un asistente experto. Responde la pregunta del usuario
basándote EXCLUSIVAMENTE en el contexto proporcionado a continuación.
Si la información no está en el contexto, indícalo claramente.

=== CONTEXTO RECUPERADO ===

{contexto_chunks}

{contexto_faqs}

=== PREGUNTA DEL USUARIO ===
{pregunta}

=== RESPUESTA ===
"""
            print(f"\n{BOLD}{'═'*60}{RESET}")
            print(f"{BOLD}  PROMPT RAG GENERADO{RESET}")
            print(f"{BOLD}{'═'*60}{RESET}")
            print(f"{CYAN}{prompt_rag}{RESET}")
            print(f"{BOLD}{'═'*60}{RESET}")
            print(f"\n{YELLOW}ℹ  Este prompt se enviaría a un LLM (GPT-4, Claude, Llama...).")
            print(f"   Instala 'openai' y añade tu API key para completar el flujo RAG.{RESET}")

        cur.close(); conn.close()
    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error: {e}")
        import traceback; traceback.print_exc()

    wait()


# ══════════════════════════════════════════════════════════
# OPCIÓN 6 — ESTADÍSTICAS Y ANÁLISIS
# ══════════════════════════════════════════════════════════

def statistics():
    print_separator()
    print(f"{BOLD}6. Estadísticas y análisis de vectores{RESET}\n")

    print(f"  {YELLOW}[1]{RESET}  Estadísticas generales de la BD")
    print(f"  {YELLOW}[2]{RESET}  Documentos duplicados / muy similares")
    print(f"  {YELLOW}[3]{RESET}  Distribución de similitudes")
    print(f"  {YELLOW}[4]{RESET}  Centroide por categoría")
    choice = input(f"\n{BOLD}Elige: {RESET}").strip()

    try:
        conn = get_connection(dbname=TARGET_DB)
        cur  = conn.cursor(cursor_factory=RealDictCursor)

        if choice == "1":
            for tabla in ["documentos", "productos", "faq", "chunks_rag"]:
                cur.execute(f"""
                    SELECT
                        COUNT(*) AS total,
                        COUNT(embedding) AS con_embedding,
                        COUNT(*) - COUNT(embedding) AS sin_embedding
                    FROM {tabla}
                """)
                r = cur.fetchone()
                print(f"\n  {BOLD}{tabla}{RESET}")
                print(f"    Total       : {CYAN}{r['total']}{RESET}")
                print(f"    Con embedding: {GREEN}{r['con_embedding']}{RESET}")
                print(f"    Sin embedding: "
                      f"{RED if r['sin_embedding'] > 0 else GREEN}"
                      f"{r['sin_embedding']}{RESET}")

            # Tamaño de índices
            cur.execute("""
                SELECT indexrelname,
                    pg_size_pretty(pg_relation_size(indexrelid)) AS tamaño
                FROM pg_stat_user_indexes
                WHERE indexrelname LIKE '%hnsw%'
                ORDER BY pg_relation_size(indexrelid) DESC
            """)
            indices = cur.fetchall()
            if indices:
                print(f"\n  {BOLD}Índices HNSW:{RESET}")
                for idx in indices:
                    print(f"    {idx['indexrelname']:<40} {CYAN}{idx['tamaño']}{RESET}")

        elif choice == "2":
            umbral = float(
                input("Umbral de similitud para considerar duplicado [0.95]: ").strip()
                or "0.95"
            )
            cur.execute(f"""
                SELECT
                    a.id AS id_a, a.titulo AS titulo_a,
                    b.id AS id_b, b.titulo AS titulo_b,
                    1 - (a.embedding <=> b.embedding) AS similitud
                FROM documentos a
                JOIN documentos b ON a.id < b.id
                WHERE 1 - (a.embedding <=> b.embedding) >= %s
                ORDER BY similitud DESC
                LIMIT 20
            """, (umbral,))
            rows = cur.fetchall()
            print(f"\n{BOLD}Pares con similitud ≥ {umbral}:{RESET}")
            print_separator("─")
            if not rows:
                print_info("No se encontraron documentos casi duplicados.")
            else:
                for r in rows:
                    sim = float(r["similitud"])
                    print(f"\n  {RED}ID {r['id_a']}{RESET}: {r['titulo_a'][:50]}")
                    print(f"  {RED}ID {r['id_b']}{RESET}: {r['titulo_b'][:50]}")
                    print(f"  Similitud: {similarity_bar(sim)}")

        elif choice == "3":
            # Muestrear similitudes aleatorias para ver la distribución
            cur.execute("""
                SELECT
                    1 - (a.embedding <=> b.embedding) AS similitud
                FROM (
                    SELECT id, embedding FROM documentos
                    ORDER BY RANDOM() LIMIT 10
                ) a,
                (
                    SELECT id, embedding FROM documentos
                    ORDER BY RANDOM() LIMIT 10
                ) b
                WHERE a.id < b.id
            """)
            rows = cur.fetchall()
            sims = [float(r["similitud"]) for r in rows]
            if not sims:
                print_info("Insuficientes datos para analizar.")
                cur.close(); conn.close(); wait(); return

            buckets = {
                "0.9 – 1.0 (muy similar)":  sum(1 for s in sims if s >= 0.9),
                "0.7 – 0.9 (similar)":       sum(1 for s in sims if 0.7 <= s < 0.9),
                "0.5 – 0.7 (algo similar)":  sum(1 for s in sims if 0.5 <= s < 0.7),
                "0.3 – 0.5 (poco similar)":  sum(1 for s in sims if 0.3 <= s < 0.5),
                "0.0 – 0.3 (distinto)":      sum(1 for s in sims if s < 0.3),
            }

            print(f"\n{BOLD}Distribución de similitudes coseno (muestra de {len(sims)} pares):{RESET}")
            print_separator("─")
            total = len(sims)
            for label, count in buckets.items():
                pct = count / total if total else 0
                bar = "█" * int(pct * 30)
                print(f"  {label:<30} {bar:<30} {count:>4} ({pct:.1%})")
            print_separator("─")
            if sims:
                print(f"  Media: {sum(sims)/len(sims):.4f}  "
                      f"Mín: {min(sims):.4f}  "
                      f"Máx: {max(sims):.4f}")

        elif choice == "4":
            cur.execute("""
                SELECT
                    categoria,
                    COUNT(*) AS n_docs,
                    avg(embedding) AS centroide
                FROM documentos
                WHERE embedding IS NOT NULL
                GROUP BY categoria
                ORDER BY n_docs DESC
            """)
            cats = cur.fetchall()
            print(f"\n{BOLD}Centroides por categoría:{RESET}")
            print_separator("─")
            for c in cats:
                centroide_str = str(c["centroide"])
                print(f"\n  {BOLD}{c['categoria']}{RESET} ({c['n_docs']} docs)")
                # Mostrar sólo primeras dimensiones del centroide
                try:
                    vals = centroide_str.strip("[]").split(",")
                    preview = ", ".join(f"{float(v):.4f}" for v in vals[:5])
                    print(f"  Centroide: [{preview}, ...] ({len(vals)} dims)")
                except Exception:
                    print(f"  Centroide: {centroide_str[:60]}...")

            # Distancia entre centroides
            if len(cats) >= 2:
                print(f"\n{BOLD}Distancias entre centroides de categorías:{RESET}")
                print_separator("─")
                for i in range(len(cats)):
                    for j in range(i + 1, len(cats)):
                        cur.execute(f"""
                            SELECT
                                1 - (a.centroide <=> b.centroide) AS similitud
                            FROM (
                                SELECT avg(embedding) AS centroide
                                FROM documentos WHERE categoria = %s
                            ) a, (
                                SELECT avg(embedding) AS centroide
                                FROM documentos WHERE categoria = %s
                            ) b
                        """, (cats[i]["categoria"], cats[j]["categoria"]))
                        r = cur.fetchone()
                        if r:
                            sim = float(r["similitud"])
                            print(
                                f"  {str(cats[i]['categoria']):<15} ↔ "
                                f"{str(cats[j]['categoria']):<15} : "
                                f"{similarity_bar(sim, width=15)}"
                            )

        cur.close(); conn.close()
    except OperationalError:
        print_error(f"No se pudo conectar a '{TARGET_DB}'.")
    except Exception as e:
        print_error(f"Error: {e}")
        import traceback; traceback.print_exc()

    wait()


# ══════════════════════════════════════════════════════════
# MENÚ PRINCIPAL
# ══════════════════════════════════════════════════════════

BANNER = f"""
{MAGENTA}{BOLD}╔══════════════════════════════════════════════════════════════╗
║   pgvector Manager — PostgreSQL + Embeddings para IA/ML     ║
║   Modelo: {MODEL_NAME:<49}║
╚══════════════════════════════════════════════════════════════╝{RESET}
"""

MENU = f"""
{CYAN}{BOLD}── MENÚ PRINCIPAL ──────────────────────────────────────────{RESET}

  {YELLOW}[0]{RESET}  Instalar / Verificar pgvector         ← {RED}Empieza aquí{RESET}
  {YELLOW}[1]{RESET}  Crear esquema + datos de muestra con embeddings
  {YELLOW}[2]{RESET}  Insertar documento / producto / FAQ
  {YELLOW}[3]{RESET}  Búsqueda semántica
       └─ Coseno · L2 · Híbrida · Filtros · Umbral
  {YELLOW}[4]{RESET}  Sistema de recomendaciones vectorial
       └─ Por producto · Por descripción · Por perfil de usuario
  {YELLOW}[5]{RESET}  RAG — Retrieval Augmented Generation
       └─ FAQ · Chunks · Demo prompt completo
  {YELLOW}[6]{RESET}  Estadísticas y análisis de vectores
       └─ Duplicados · Distribución · Centroides por categoría
  {YELLOW}[q]{RESET}  Salir

{CYAN}────────────────────────────────────────────────────────────{RESET}
"""


def _check_status_on_startup():
    """
    Comprobación rápida del estado al arrancar.

    FIX: with_vector_adapter=False — en este punto todavía no sabemos
    si 'vector' existe en TARGET_DB.
    """
    # pgvector en la BD
    try:
        conn = get_connection(dbname=TARGET_DB, with_vector_adapter=False)
        cur  = conn.cursor()
        cur.execute(
            "SELECT extversion FROM pg_extension WHERE extname='vector';"
        )
        row = cur.fetchone()
        cur.close(); conn.close()
        if row:
            print(f"  pgvector BD  : {GREEN}✔ Activo (v{row[0]}) en '{TARGET_DB}'{RESET}")
        else:
            print(f"  pgvector BD  : {YELLOW}⚠ Instalado en SO pero no activado → opción [0]{RESET}")
    except Exception:
        print(f"  pgvector BD  : {RED}✗ No disponible en '{TARGET_DB}' → opción [0]{RESET}")

    # Modelo de embeddings
    if ST_OK:
        print(f"  Embeddings   : {GREEN}✔ sentence-transformers disponible{RESET}")
    else:
        print(f"  Embeddings   : {RED}✗ pip install sentence-transformers{RESET}")

    # Adaptador Python
    if PGVECTOR_ADAPTER:
        print(f"  PG adapter   : {GREEN}✔ pgvector Python adapter OK{RESET}")
    else:
        print(f"  PG adapter   : {YELLOW}⚠ pip install pgvector{RESET}")


def main():
    print(BANNER)
    print(f"{CYAN}Configuración de conexión:{RESET}")
    print(f"  Host   : {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print(f"  Usuario: {DB_CONFIG['user']}")
    print(f"  BD     : {BOLD}{TARGET_DB}{RESET}\n")
    print(f"{BOLD}Estado del entorno:{RESET}")
    _check_status_on_startup()
    print(f"\n{YELLOW}ℹ  Edita DB_CONFIG al inicio del script para cambiar la conexión.{RESET}")

    while True:
        print(MENU)
        choice = input(f"{BOLD}Elige una opción: {RESET}").strip().lower()

        if   choice in ("q", "quit", "exit"):
            print(f"\n{GREEN}¡Hasta luego!{RESET}\n")
            sys.exit(0)
        elif choice == "0": install_pgvector()
        elif choice == "1": create_schema()
        elif choice == "2": insert_document()
        elif choice == "3": semantic_search()
        elif choice == "4": recommendations()
        elif choice == "5": rag_demo()
        elif choice == "6": statistics()
        else: print(f"\n{RED}Opción no válida.{RESET}")


if __name__ == "__main__":
    main()
