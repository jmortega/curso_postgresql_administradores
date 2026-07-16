import psycopg2
from sentence_transformers import SentenceTransformer

# 1. Conectar a tu base de datos PostgreSQL
conn = psycopg2.connect("dbname=vectordb user=postgres password=postgres_lab host=localhost")
cur = conn.cursor()

# 2. Inicializar el modelo UNA SOLA VEZ
print("[*] Cargando modelo de embeddings...")
model = SentenceTransformer('all-MiniLM-L6-v2')

# 3. Generar e insertar los embeddings de varios documentos
documentos = [
    "PostgreSQL es un sistema de gestión de bases de datos relacional de código abierto, conocido por su fiabilidad y su cumplimiento del estándar SQL.",
    "La extensión pgvector permite almacenar embeddings vectoriales en PostgreSQL y realizar búsquedas por similitud coseno, euclidiana o producto interior.",
    "La receta tradicional de la paella valenciana lleva arroz, pollo, conejo, judía verde, garrofón, tomate, aceite de oliva y azafrán.",
]

print(f"[*] Insertando {len(documentos)} documentos...")
for texto in documentos:
    embedding_lista = model.encode(texto).tolist()  # Lista de 384 floats
    embedding_string = str(embedding_lista)
    cur.execute(
        "INSERT INTO items (contenido, embedding) VALUES (%s, %s);",
        (texto, embedding_string)
    )
    print(f"    + \"{texto[:60]}...\"")

# === CRÍTICO: Confirmar los INSERT antes de buscar ===
conn.commit()
print("[+] Registros insertados y confirmados en la base de datos.")

# 4. Tu consulta en lenguaje natural — relacionada con los documentos insertados
query_usuario = "¿Qué es PostgreSQL y para qué sirve pgvector?"
query_embedding = model.encode(query_usuario).tolist()  # Lista de 384 floats
query_embedding_str = str(query_embedding)

# 5. Ejecutar la búsqueda por similitud del coseno
sql = """
SELECT contenido, 1 - (embedding <=> %s::vector) AS similitud
FROM items
ORDER BY embedding <=> %s::vector
LIMIT 5;
"""
print("\n[*] Ejecutando búsqueda por similitud...")
cur.execute(sql, (query_embedding_str, query_embedding_str))

# 6. Mostrar resultados
resultados = cur.fetchall()
print("\n=== RESULTADOS DE BÚSQUEDA ===")
if not resultados:
    print("[-] No se encontraron resultados (verifica si la tabla tiene datos reales).")
else:
    for fila in resultados:
        print(f"Contenido: {fila[0]} | Similitud: {fila[1]:.4f}")

# Cerrar conexiones de forma limpia
cur.close()
conn.close()
