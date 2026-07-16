"""
pgvector_lab.py
===============
Demostración práctica de pgvector con PostgreSQL.

Operaciones implementadas
--------------------------
  1. Conexión y verificación de la extensión vector
  2. Generación de embeddings  (sentence-transformers o numpy aleatorio)
  3. INSERT de documentos, productos y usuarios con sus embeddings
  4. Búsqueda por similitud coseno  (operador <=>)
  5. Búsqueda por distancia euclidiana  (operador <->)
  6. Búsqueda por producto interior  (operador <#>)
  7. Búsqueda filtrada por metadatos + similitud vectorial
  8. Creación y comparación de índices  (IVFFlat vs HNSW)
  9. Actualización de embeddings en caliente
 10. Búsqueda de N vecinos más cercanos (KNN)
 11. Clustering de vectores con k-means sobre pgvector
 12. Benchmark: sin índice vs IVFFlat vs HNSW
 13. Resumen de estadísticas del laboratorio

Uso
---
  python pgvector_lab.py                  # menú interactivo
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

# ── Dependencias ──────────────────────────────────────────────
try:
    import psycopg2
    from psycopg2 import sql
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("[ERROR] psycopg2 no instalado.  Ejecuta: pip install psycopg2-binary")
    sys.exit(1)

try:
    import numpy as np
    NUMPY_OK = True
except ImportError:
    print("[AVISO] numpy no disponible: pip install numpy")
    NUMPY_OK = False

try:
    from pgvector.psycopg2 import register_vector
    PGVECTOR_ADAPTER = True
except ImportError:
    PGVECTOR_ADAPTER = False

try:
    from sentence_transformers import SentenceTransformer
    ST_OK = True
except ImportError:
    ST_OK = False

# ── Colores ANSI ──────────────────────────────────────────────
R  = "\033[91m"
G  = "\033[92m"
Y  = "\033[93m"
C  = "\033[96m"
M  = "\033[95m"
B  = "\033[94m"
BO = "\033[1m"
RS = "\033[0m"

# ── Configuración de conexión ─────────────────────────────────
DB_CONFIG = {
    "host":     os.environ.get("PG_HOST",     "localhost"),
    "port":     int(os.environ.get("PG_PORT", "5432")),
    "user":     os.environ.get("PG_USER",     "postgres"),
    "password": os.environ.get("PG_PASSWORD", "postgres_lab"),
    "dbname":   os.environ.get("PG_DBNAME",   "vectordb"),
}

DIM_DOCS     = 384    # dimensión para documentos y productos
DIM_USUARIOS = 128    # dimensión para perfiles de usuario
DATA_DIR     = Path(__file__).parent / "data"

# ── Helpers de salida ─────────────────────────────────────────
def sep(c="=", w=70): print(c * w)
def titulo(t):
    sep()
    print(f"  {BO}{t}{RS}")
    sep("-")

def ok(msg):    print(f"  {G}✓{RS} {msg}")
def warn(msg):  print(f"  {Y}⚠{RS} {msg}")
def err(msg):   print(f"  {R}✗{RS} {msg}")
def info(msg):  print(f"  {C}→{RS} {msg}")

# ── Conexión ──────────────────────────────────────────────────
def get_conn(cfg: dict = None):
    cfg = cfg or DB_CONFIG
    conn = psycopg2.connect(**cfg)
    conn.autocommit = True
    if PGVECTOR_ADAPTER:
        register_vector(conn)
    return conn

# ── Embeddings ────────────────────────────────────────────────
_model = None

def get_model():
    global _model
    if _model is None and ST_OK:
        info("Cargando modelo sentence-transformers/all-MiniLM-L6-v2 …")
        _model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
        ok("Modelo cargado")
    return _model

def embed_textos(textos: list[str], dim: int) -> list[list[float]]:
    """Genera embeddings reales o aleatorios (fallback)."""
    if ST_OK:
        m = get_model()
        vecs = m.encode(textos, normalize_embeddings=True)
        # Ajustar dimensión si es diferente (truncar o rellenar con ceros)
        if vecs.shape[1] != dim:
            if vecs.shape[1] > dim:
                vecs = vecs[:, :dim]
            else:
                pad = np.zeros((len(vecs), dim - vecs.shape[1]))
                vecs = np.concatenate([vecs, pad], axis=1)
        return vecs.tolist()
    else:
        warn("sentence-transformers no disponible — usando vectores aleatorios")
        rng = np.random.default_rng(42)
        vecs = rng.standard_normal((len(textos), dim)).astype(np.float32)
        # Normalizar (coseno)
        norms = np.linalg.norm(vecs, axis=1, keepdims=True)
        vecs = vecs / np.maximum(norms, 1e-9)
        return vecs.tolist()

def vec_to_pg(v: list[float]) -> str:
    """Convierte lista de floats al literal de pgvector."""
    return "[" + ",".join(f"{x:.6f}" for x in v) + "]"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OPERACIONES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def op1_verificar_extension():
    """Verificar que pgvector está instalado y activo."""
    titulo("Operación 1 — Verificar extensión pgvector")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("SELECT extname, extversion FROM pg_extension WHERE extname='vector'")
    row = cur.fetchone()
    if row:
        ok(f"pgvector activo — versión {row['extversion']}")
    else:
        err("pgvector NO está instalado")
        return

    cur.execute("SELECT version()")
    pg_ver = cur.fetchone()["version"]
    ok(f"PostgreSQL: {pg_ver.split(',')[0]}")

    # Verificar operadores vectoriales
    cur.execute("""
        SELECT oprname FROM pg_operator
        WHERE oprname IN ('<->', '<=>', '<#>')
        ORDER BY oprname;
    """)
    ops = [r["oprname"] for r in cur.fetchall()]
    ok(f"Operadores de distancia disponibles: {', '.join(ops)}")
    cur.close(); conn.close()


def op2_cargar_datos():
    """Cargar documentos, productos y usuarios con sus embeddings."""
    titulo("Operación 2 — Cargar datos con embeddings")
    conn = get_conn()
    cur  = conn.cursor()

    # Limpiar tablas para re-ejecución limpia
    cur.execute("TRUNCATE lab.documentos, lab.productos, lab.usuarios RESTART IDENTITY")
    info("Tablas vaciadas (TRUNCATE + RESTART IDENTITY)")

    # ── Documentos ────────────────────────────────────────────
    docs = json.loads((DATA_DIR / "documentos.json").read_text(encoding="utf-8"))
    textos = [f"{d['titulo']}. {d['contenido']}" for d in docs]
    info(f"Generando {len(docs)} embeddings de dimensión {DIM_DOCS} …")
    embeddings = embed_textos(textos, DIM_DOCS)

    cur.executemany(
        """INSERT INTO lab.documentos (titulo, contenido, categoria, embedding)
           VALUES (%s, %s, %s, %s::vector)""",
        [
            (d["titulo"], d["contenido"], d["categoria"], vec_to_pg(e))
            for d, e in zip(docs, embeddings)
        ],
    )
    ok(f"{len(docs)} documentos insertados")

    # ── Productos ────────────────────────────────────────────
    prods = json.loads((DATA_DIR / "productos.json").read_text(encoding="utf-8"))
    textos_p = [f"{p['nombre']}. {p['descripcion']}" for p in prods]
    info(f"Generando {len(prods)} embeddings de productos …")
    emb_prods = embed_textos(textos_p, DIM_DOCS)

    cur.executemany(
        """INSERT INTO lab.productos (nombre, descripcion, precio, categoria, embedding)
           VALUES (%s, %s, %s, %s, %s::vector)""",
        [
            (p["nombre"], p["descripcion"], p["precio"], p["categoria"], vec_to_pg(e))
            for p, e in zip(prods, emb_prods)
        ],
    )
    ok(f"{len(prods)} productos insertados")

    # ── Usuarios ─────────────────────────────────────────────
    users = json.loads((DATA_DIR / "usuarios.json").read_text(encoding="utf-8"))
    textos_u = [" ".join(u["intereses"]) for u in users]
    info(f"Generando {len(users)} embeddings de usuarios (dim={DIM_USUARIOS}) …")
    emb_users = embed_textos(textos_u, DIM_USUARIOS)

    cur.executemany(
        """INSERT INTO lab.usuarios (nombre, intereses, embedding)
           VALUES (%s, %s::text[], %s::vector)""",
        [
            (u["nombre"], u["intereses"], vec_to_pg(e))
            for u, e in zip(users, emb_users)
        ],
    )
    ok(f"{len(users)} usuarios insertados")
    cur.close(); conn.close()


def op3_busqueda_coseno():
    """Búsqueda semántica por similitud coseno (operador <=>)."""
    titulo("Operación 3 — Búsqueda por similitud coseno (<=>)")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    consultas = [
        "redes neuronales y aprendizaje profundo",
        "historia del Imperio Romano",
        "economía y mercados financieros",
    ]

    for consulta in consultas:
        info(f"Consulta: {BO}\"{consulta}\"{RS}")
        [emb] = embed_textos([consulta], DIM_DOCS)
        emb_str = vec_to_pg(emb)

        cur.execute(
            """SELECT titulo, categoria,
                      1 - (embedding <=> %s::vector) AS similitud_coseno
               FROM lab.documentos
               ORDER BY embedding <=> %s::vector
               LIMIT 3""",
            (emb_str, emb_str),
        )
        for row in cur.fetchall():
            print(f"    {G}{row['similitud_coseno']:.4f}{RS}  [{row['categoria']:12}]  {row['titulo']}")
        print()

    cur.close(); conn.close()


def op4_busqueda_euclidiana():
    """Búsqueda por distancia euclidiana (operador <->)."""
    titulo("Operación 4 — Búsqueda por distancia euclidiana (<->)")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    consulta = "fotografía profesional con cámara sin espejo"
    info(f"Consulta: {BO}\"{consulta}\"{RS}")
    [emb] = embed_textos([consulta], DIM_DOCS)
    emb_str = vec_to_pg(emb)

    cur.execute(
        """SELECT nombre, categoria, precio,
                  embedding <-> %s::vector AS distancia_euclidiana
           FROM lab.productos
           ORDER BY embedding <-> %s::vector
           LIMIT 5""",
        (emb_str, emb_str),
    )
    print(f"  {'Distancia':>10}  {'Precio':>10}  {'Categoría':15}  Producto")
    sep("-", 70)
    for row in cur.fetchall():
        print(
            f"  {row['distancia_euclidiana']:>10.4f}  "
            f"{row['precio']:>10.2f}€  "
            f"{row['categoria']:15}  {row['nombre']}"
        )
    cur.close(); conn.close()


def op5_busqueda_producto_interior():
    """Búsqueda por producto interior (operador <#> — negativo: menor es mejor)."""
    titulo("Operación 5 — Búsqueda por producto interior (<#>)")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    consulta = "auriculares y dispositivos de audio de alta calidad"
    info(f"Consulta: {BO}\"{consulta}\"{RS}")
    info("(con vectores normalizados, producto interior ≈ similitud coseno)")
    [emb] = embed_textos([consulta], DIM_DOCS)
    emb_str = vec_to_pg(emb)

    cur.execute(
        """SELECT nombre, categoria,
                  -(embedding <#> %s::vector) AS producto_interior
           FROM lab.productos
           ORDER BY embedding <#> %s::vector
           LIMIT 5""",
        (emb_str, emb_str),
    )
    for row in cur.fetchall():
        print(f"  {G}{row['producto_interior']:.4f}{RS}  [{row['categoria']:15}]  {row['nombre']}")
    cur.close(); conn.close()


def op6_busqueda_filtrada():
    """Búsqueda vectorial combinada con filtros de metadatos (WHERE + ORDER BY)."""
    titulo("Operación 6 — Búsqueda filtrada (metadatos + similitud)")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    # Buscar documentos de ciencia similares a una consulta
    consulta  = "partículas subatómicas y física cuántica"
    categoria = "ciencia"
    info(f"Consulta: \"{consulta}\"  |  Filtro categoría = '{categoria}'")
    [emb] = embed_textos([consulta], DIM_DOCS)
    emb_str = vec_to_pg(emb)

    cur.execute(
        """SELECT titulo, categoria,
                  1 - (embedding <=> %s::vector) AS similitud
           FROM lab.documentos
           WHERE categoria = %s
           ORDER BY embedding <=> %s::vector
           LIMIT 4""",
        (emb_str, categoria, emb_str),
    )
    ok(f"Top 4 documentos de '{categoria}':")
    for row in cur.fetchall():
        print(f"    {G}{row['similitud']:.4f}{RS}  {row['titulo']}")

    # Buscar productos de audio por precio máximo y similitud
    print()
    consulta2    = "auriculares cancelación de ruido"
    precio_max   = 400
    info(f"Consulta: \"{consulta2}\"  |  Filtro precio ≤ {precio_max}€")
    [emb2] = embed_textos([consulta2], DIM_DOCS)
    emb2_str = vec_to_pg(emb2)

    cur.execute(
        """SELECT nombre, precio, categoria,
                  1 - (embedding <=> %s::vector) AS similitud
           FROM lab.productos
           WHERE precio <= %s
           ORDER BY embedding <=> %s::vector
           LIMIT 4""",
        (emb2_str, precio_max, emb2_str),
    )
    ok(f"Top 4 productos ≤ {precio_max}€:")
    for row in cur.fetchall():
        print(f"    {G}{row['similitud']:.4f}{RS}  {row['precio']:7.2f}€  {row['nombre']}")

    cur.close(); conn.close()


def op7_indices():
    """Crear índices IVFFlat y HNSW y comparar sus planes de ejecución."""
    titulo("Operación 7 — Índices vectoriales: IVFFlat vs HNSW")

    def recrear_indice(nombre: str, create_sql: str) -> float:
        """
        Elimina el índice si existe (verificado desde Python) y lo crea.
        Usa una conexión independiente con autocommit para cada operación DDL.
        """
        # Paso 1 — DROP en su propia conexión/transacción
        c = get_conn()
        c.autocommit = True
        with c.cursor() as cx:
            cx.execute(f"DROP INDEX IF EXISTS {nombre}")
        c.close()

        # Paso 2 — Verificar desde Python que ya no existe antes del CREATE
        c2 = get_conn()
        c2.autocommit = True
        with c2.cursor() as cx:
            cx.execute(
                "SELECT 1 FROM pg_indexes WHERE indexname = %s", (nombre,)
            )
            existe = cx.fetchone() is not None
        c2.close()

        if existe:
            warn(f"El índice '{nombre}' no se pudo eliminar, omitiendo CREATE")
            return 0.0

        # Paso 3 — CREATE en su propia conexión/transacción
        c3 = get_conn()
        c3.autocommit = True
        t0 = time.time()
        with c3.cursor() as cx:
            cx.execute(create_sql)
        elapsed = time.time() - t0
        c3.close()
        return elapsed

    # IVFFlat
    info("Creando índice IVFFlat (coseno) …")
    elapsed = recrear_indice(
        "idx_doc_ivfflat",
        "CREATE INDEX idx_doc_ivfflat ON lab.documentos "
        "USING ivfflat (embedding vector_cosine_ops) WITH (lists=10)",
    )
    ok(f"IVFFlat creado en {elapsed:.3f}s")

    # HNSW
    info("Creando índice HNSW (coseno) …")
    elapsed = recrear_indice(
        "idx_doc_hnsw",
        "CREATE INDEX idx_doc_hnsw ON lab.documentos "
        "USING hnsw (embedding vector_cosine_ops) WITH (m=16, ef_construction=64)",
    )
    ok(f"HNSW creado en {elapsed:.3f}s")

    # Consultas de catálogo en una conexión de solo lectura
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    # Mostrar índices creados
    cur.execute("""
        SELECT indexname, indexdef
        FROM pg_indexes
        WHERE tablename='documentos' AND schemaname='lab'
        ORDER BY indexname
    """)
    print()
    for row in cur.fetchall():
        print(f"  {B}{row['indexname']}{RS}")
        print(f"    {row['indexdef']}\n")

    # Comparar tamaños
    cur.execute("""
        SELECT indexrelname AS idx,
               pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio
        FROM pg_stat_user_indexes
        WHERE relid = 'lab.documentos'::regclass
        ORDER BY pg_relation_size(indexrelid) DESC
    """)
    ok("Tamaños de índices:")
    for row in cur.fetchall():
        print(f"    {row['tamanio']:>10}  {row['idx']}")

    cur.close(); conn.close()


def op8_actualizar_embeddings():
    """Actualizar el embedding de un documento existente."""
    titulo("Operación 8 — Actualizar embeddings en caliente")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    # Leer el documento con id=1
    cur.execute("SELECT id, titulo, categoria FROM lab.documentos WHERE id=1")
    doc = cur.fetchone()
    info(f"Documento a actualizar: [{doc['id']}] {doc['titulo']}")

    nuevo_texto = "Transformers y atención multi-cabeza en NLP y visión computacional"
    info(f"Nuevo texto semántico: \"{nuevo_texto}\"")

    [nuevo_emb] = embed_textos([nuevo_texto], DIM_DOCS)

    cur.execute(
        "UPDATE lab.documentos SET embedding = %s::vector WHERE id = %s",
        (vec_to_pg(nuevo_emb), doc["id"]),
    )
    ok(f"Embedding del documento {doc['id']} actualizado")

    # Verificar con una búsqueda
    [qemb] = embed_textos(["modelos de atención en deep learning"], DIM_DOCS)
    cur.execute(
        """SELECT titulo, 1-(embedding<=>%s::vector) AS sim
           FROM lab.documentos ORDER BY embedding<=>%s::vector LIMIT 3""",
        (vec_to_pg(qemb), vec_to_pg(qemb)),
    )
    ok("Verificación — top 3 más similares a 'modelos de atención en deep learning':")
    for row in cur.fetchall():
        print(f"    {G}{row['sim']:.4f}{RS}  {row['titulo']}")

    cur.close(); conn.close()


def op9_knn():
    """Búsqueda K vecinos más cercanos entre perfiles de usuario."""
    titulo("Operación 9 — K Vecinos más cercanos (KNN) en perfiles de usuario")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    # Perfil de consulta: intereses tecnológicos
    intereses_consulta = ["machine learning", "bases de datos", "programación", "cloud"]
    texto_consulta     = " ".join(intereses_consulta)
    info(f"Perfil de consulta: {intereses_consulta}")

    [emb_q] = embed_textos([texto_consulta], DIM_USUARIOS)

    cur.execute(
        """SELECT nombre, intereses,
                  1-(embedding<=>%s::vector) AS afinidad
           FROM lab.usuarios
           ORDER BY embedding<=>%s::vector
           LIMIT 5""",
        (vec_to_pg(emb_q), vec_to_pg(emb_q)),
    )
    ok("Top 5 usuarios con perfil más afín:")
    for i, row in enumerate(cur.fetchall(), 1):
        print(f"    {i}. {G}{row['afinidad']:.4f}{RS}  {row['nombre']}")
        print(f"       Intereses: {', '.join(row['intereses'])}")
    cur.close(); conn.close()


def op10_clustering():
    """Agrupar documentos mediante k-means sobre los embeddings."""
    titulo("Operación 10 — Clustering de documentos con k-means")

    if not NUMPY_OK:
        warn("numpy no disponible — omitiendo clustering")
        return

    from sklearn.cluster import KMeans
    import importlib.util
    if importlib.util.find_spec("sklearn") is None:
        warn("scikit-learn no disponible (pip install scikit-learn) — omitiendo")
        return

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id, titulo, categoria, embedding::text FROM lab.documentos")
    rows = cur.fetchall()

    # Parsear embeddings de texto a numpy
    def parse_vec(s):
        return np.array([float(x) for x in s.strip("[]").split(",")], dtype=np.float32)

    X       = np.stack([parse_vec(r["embedding"]) for r in rows])
    titulos = [r["titulo"] for r in rows]
    cats    = [r["categoria"] for r in rows]

    K = 5
    info(f"Aplicando k-means con K={K} sobre {len(X)} embeddings de dim={X.shape[1]} …")
    km = KMeans(n_clusters=K, random_state=42, n_init=10)
    labels = km.fit_predict(X)

    # Mostrar los grupos
    clusters = {}
    for lbl, ttl, cat in zip(labels, titulos, cats):
        clusters.setdefault(int(lbl), []).append((ttl, cat))

    for cid, items in sorted(clusters.items()):
        cats_cluster  = [c for _, c in items]
        cat_principal = max(set(cats_cluster), key=cats_cluster.count)
        print(f"\n  {B}Cluster {cid}{RS} ({len(items)} docs, categoría dominante: {cat_principal})")
        for ttl, cat in items[:3]:
            print(f"    · [{cat:10}] {ttl}")
        if len(items) > 3:
            print(f"    … y {len(items)-3} más")

    cur.close(); conn.close()


def op11_benchmark():
    """Comparar tiempos de búsqueda: sin índice vs IVFFlat vs HNSW."""
    titulo("Operación 11 — Benchmark: sin índice vs IVFFlat vs HNSW")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    consulta = "inteligencia artificial y machine learning"
    [emb] = embed_textos([consulta], DIM_DOCS)
    emb_str = vec_to_pg(emb)
    N       = 20   # número de repeticiones por escenario

    def medir(label: str, index_hint: str = ""):
        tiempos = []
        for _ in range(N):
            t0 = time.perf_counter()
            cur.execute(
                f"""SELECT titulo FROM lab.documentos
                    ORDER BY embedding <=> %s::vector LIMIT 5""",
                (emb_str,),
            )
            cur.fetchall()
            tiempos.append((time.perf_counter() - t0) * 1000)
        media = np.mean(tiempos) if NUMPY_OK else sum(tiempos) / len(tiempos)
        std   = np.std(tiempos)  if NUMPY_OK else 0
        info(f"{label:20}  media={media:7.2f}ms  ±{std:.2f}ms  ({N} iteraciones)")
        # Registrar en tabla de benchmark
        # float() convierte np.float64 → float Python nativo (psycopg2 lo requiere)
        cur.execute(
            """INSERT INTO lab.benchmark_resultados
               (operacion, n_vectores, dimensiones, tipo_indice, tiempo_ms)
               VALUES (%s, %s, %s, %s, %s)""",
            ("coseno_top5", 50, DIM_DOCS, label.strip(), float(round(media, 4))),
        )
        return float(media)

    def drop_indice(nombre: str) -> None:
        """Elimina un índice si existe, verificando desde Python."""
        c = get_conn()
        c.autocommit = True
        with c.cursor() as cx:
            cx.execute(f"DROP INDEX IF EXISTS {nombre}")
        c.close()

    def recrear_indice(nombre: str, create_sql: str) -> None:
        """
        DROP en una conexión, verifica desde Python que desapareció,
        luego CREATE en una conexión nueva.
        """
        # DROP
        c = get_conn()
        c.autocommit = True
        with c.cursor() as cx:
            cx.execute(f"DROP INDEX IF EXISTS {nombre}")
        c.close()

        # Verificar que ya no existe
        c2 = get_conn()
        c2.autocommit = True
        with c2.cursor() as cx:
            cx.execute("SELECT 1 FROM pg_indexes WHERE indexname = %s", (nombre,))
            existe = cx.fetchone() is not None
        c2.close()

        if existe:
            warn(f"No se pudo eliminar '{nombre}', omitiendo CREATE")
            return

        # CREATE
        c3 = get_conn()
        c3.autocommit = True
        with c3.cursor() as cx:
            cx.execute(create_sql)
        c3.close()

    # 1. Sin índice — eliminar cualquier índice previo para medir seq scan puro
    drop_indice("idx_doc_ivfflat")
    drop_indice("idx_doc_hnsw")
    t_seq = medir("Sin índice (seq scan)")

    # 2. IVFFlat
    recrear_indice(
        "idx_doc_ivfflat",
        "CREATE INDEX idx_doc_ivfflat ON lab.documentos "
        "USING ivfflat (embedding vector_cosine_ops) WITH (lists=10)",
    )
    cur.execute("SET ivfflat.probes = 5")
    t_ivf = medir("IVFFlat (probes=5)")

    # 3. HNSW
    recrear_indice(
        "idx_doc_hnsw",
        "CREATE INDEX idx_doc_hnsw ON lab.documentos "
        "USING hnsw (embedding vector_cosine_ops) WITH (m=16, ef_construction=64)",
    )
    cur.execute("SET hnsw.ef_search = 40")
    t_hns = medir("HNSW (ef_search=40)")

    if t_ivf > 0 and t_hns > 0:
        print()
        ok(f"Aceleración IVFFlat vs seq scan: {t_seq/t_ivf:.1f}×")
        ok(f"Aceleración HNSW    vs seq scan: {t_seq/t_hns:.1f}×")

    cur.close(); conn.close()


def op12_estadisticas():
    """Mostrar estadísticas generales del laboratorio."""
    titulo("Operación 12 — Estadísticas del laboratorio")
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    # Tablas y tamaños
    cur.execute("""
        SELECT
            schemaname,
            relname                                         AS tabla,
            n_live_tup                                      AS filas,
            pg_size_pretty(pg_total_relation_size(
                quote_ident(schemaname)||'.'||quote_ident(relname)
            ))                                              AS tamanio_total
        FROM pg_stat_user_tables
        WHERE schemaname = 'lab'
        ORDER BY pg_total_relation_size(
            quote_ident(schemaname)||'.'||quote_ident(relname)
        ) DESC
    """)
    ok("Tablas del laboratorio:")
    print(f"  {'Tabla':20}  {'Filas':>6}  Tamaño total")
    sep("-", 50)
    for row in cur.fetchall():
        print(f"  {row['tabla']:20}  {row['filas']:>6,}  {row['tamanio_total']}")

    # Índices vectoriales
    cur.execute("""
        SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio
        FROM pg_stat_user_indexes
        WHERE relid IN (
            SELECT oid FROM pg_class WHERE relname IN ('documentos','productos','usuarios')
        )
        ORDER BY pg_relation_size(indexrelid) DESC
    """)
    rows = cur.fetchall()
    if rows:
        print()
        ok("Índices vectoriales:")
        for row in rows:
            print(f"  {row['tamanio']:>10}  {row['indexrelname']}")

    # Distribución por categoría
    cur.execute("""
        SELECT categoria, count(*) AS n
        FROM lab.documentos GROUP BY categoria ORDER BY n DESC
    """)
    print()
    ok("Documentos por categoría:")
    for row in cur.fetchall():
        bar = "█" * row["n"]
        print(f"  {row['categoria']:12} {bar} {row['n']}")

    # Benchmark
    cur.execute("""
        SELECT tipo_indice, round(avg(tiempo_ms),4) AS avg_ms
        FROM lab.benchmark_resultados
        GROUP BY tipo_indice ORDER BY avg_ms
    """)
    rows = cur.fetchall()
    if rows:
        print()
        ok("Resultados de benchmark (promedio):")
        for row in rows:
            print(f"  {row['tipo_indice']:25}  {row['avg_ms']:>8.4f} ms")

    cur.close(); conn.close()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MENÚ Y PUNTO DE ENTRADA
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OPERACIONES = {
    1:  ("Verificar extensión pgvector",                op1_verificar_extension),
    2:  ("Cargar datos + embeddings",                   op2_cargar_datos),
    3:  ("Búsqueda por similitud coseno (<=>)",         op3_busqueda_coseno),
    4:  ("Búsqueda por distancia euclidiana (<->)",     op4_busqueda_euclidiana),
    5:  ("Búsqueda por producto interior (<#>)",        op5_busqueda_producto_interior),
    6:  ("Búsqueda filtrada metadatos + vectores",      op6_busqueda_filtrada),
    7:  ("Crear y comparar índices IVFFlat / HNSW",     op7_indices),
    8:  ("Actualizar embeddings en caliente",           op8_actualizar_embeddings),
    9:  ("K vecinos más cercanos (KNN)",                op9_knn),
    10: ("Clustering de documentos (k-means)",          op10_clustering),
    11: ("Benchmark: sin índice vs IVFFlat vs HNSW",   op11_benchmark),
    12: ("Estadísticas del laboratorio",                op12_estadisticas),
}

ORDEN_DEMO = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]


def menu_interactivo():
    sep()
    print(f"  {BO}pgvector Lab — PostgreSQL + pgvector{RS}")
    sep("-")
    for n, (desc, _) in OPERACIONES.items():
        print(f"  {Y}[{n:2}]{RS}  {desc}")
    sep("-")
    print(f"  {Y}[ 0]{RS}  Ejecutar todo (modo demo)")
    print(f"  {Y}[ q]{RS}  Salir")
    sep()

    while True:
        opcion = input(f"\n{C}Elige operación: {RS}").strip().lower()
        if opcion in ("q", "salir", "exit"):
            print("¡Hasta luego!")
            break
        if opcion == "0":
            for n in ORDEN_DEMO:
                OPERACIONES[n][1]()
            break
        try:
            n = int(opcion)
            if n in OPERACIONES:
                OPERACIONES[n][1]()
            else:
                warn(f"Opción {n} no válida")
        except ValueError:
            warn("Introduce un número válido")


def main():
    p = argparse.ArgumentParser(
        description="pgvector Lab — operaciones demostrativas con PostgreSQL + pgvector"
    )
    p.add_argument("--demo",  action="store_true",
                   help="Ejecutar todas las operaciones en secuencia")
    p.add_argument("--op",    type=int, metavar="N",
                   help="Ejecutar sólo la operación N")
    p.add_argument("--host",  default=None, help="Host de PostgreSQL")
    p.add_argument("--port",  type=int, default=None)
    p.add_argument("--user",  default=None)
    p.add_argument("--password", default=None)
    p.add_argument("--dbname",   default=None)
    args = p.parse_args()

    # Sobreescribir config si se pasan argumentos
    if args.host:     DB_CONFIG["host"]     = args.host
    if args.port:     DB_CONFIG["port"]     = args.port
    if args.user:     DB_CONFIG["user"]     = args.user
    if args.password: DB_CONFIG["password"] = args.password
    if args.dbname:   DB_CONFIG["dbname"]   = args.dbname

    # Verificar conexión antes de continuar
    try:
        conn = get_conn()
        conn.close()
        ok(f"Conexión a {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['dbname']} establecida")
    except Exception as e:
        err(f"No se pudo conectar a PostgreSQL: {e}")
        sys.exit(1)

    if args.op:
        if args.op in OPERACIONES:
            OPERACIONES[args.op][1]()
        else:
            err(f"Operación {args.op} no existe. Válidas: 1-{max(OPERACIONES)}")
            sys.exit(1)
    elif args.demo:
        for n in ORDEN_DEMO:
            OPERACIONES[n][1]()
    else:
        menu_interactivo()


if __name__ == "__main__":
    main()
