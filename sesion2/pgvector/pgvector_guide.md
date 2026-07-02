# pgvector: Almacenamiento y Búsqueda de Vectores en PostgreSQL para IA/ML

> **Guía completa** — Instalación, tipos de datos, índices, operadores de similitud,
> casos de uso en IA/ML y buenas prácticas para sistemas de búsqueda semántica,
> RAG, recomendaciones y detección de anomalías.

---

## 🐳 Entorno Docker

> Este guia asume que el contenedor está levantado con `docker compose up -d`.
> Consulta el **README.md** principal para los pasos de instalación.

### Conexión utilizada por el script

```bash
# Variables de entorno (valores por defecto → apuntan al contenedor)
PG_HOST=localhost
PG_PORT=5432
PG_USER=postgres
PG_PASSWORD=postgres_lab
```

### Ejecutar el script

```bash
pip install -r requeriments.txt
python scripts/pgvector_manager.py
```

---


## Índice

1. [¿Qué es pgvector?](#1-qué-es-pgvector)
2. [Instalación y configuración](#2-instalación-y-configuración)
3. [Tipo de dato VECTOR](#3-tipo-de-dato-vector)
4. [Comparativa con soluciones alternativas](#4-comparativa-con-soluciones-alternativas)
5. [Buenas prácticas](#5-buenas-prácticas)
6. [Referencias](#6-referencias)

---

## 1. ¿Qué es pgvector?

**pgvector** es una extensión de código abierto para PostgreSQL que añade soporte
nativo para **vectores de alta dimensionalidad** (embeddings), permitiendo almacenar,
indexar y realizar búsquedas de similitud semántica directamente en la base de datos
relacional.

Un **embedding** es una representación numérica de un objeto — texto, imagen,
audio, producto, usuario — en un espacio vectorial de N dimensiones, donde la
proximidad geométrica refleja similitud semántica.

### ¿Por qué pgvector?

| Necesidad | Sin pgvector | Con pgvector |
|-----------|-------------|--------------|
| Almacenar embeddings | Serializar como BLOB o JSON | Tipo `vector` nativo |
| Búsqueda por similitud | Aplicación externa | `SELECT … ORDER BY embedding <-> query` |
| Combinar filtros SQL + similitud | Imposible en DB | `WHERE categoria='X' ORDER BY similitud` |
| Infraestructura adicional | Pinecone, Weaviate, Milvus | Solo PostgreSQL |
| Transacciones ACID | Complicado | Nativo |
| Joins con otras tablas | Imposible | SQL estándar |

### Dimensiones de vectores por modelo

| Modelo | Dimensiones | Uso típico |
|--------|------------|-----------|
| `text-embedding-3-small` (OpenAI) | 1,536 | Texto general, búsqueda semántica |
| `text-embedding-3-large` (OpenAI) | 3,072 | Alta precisión semántica |
| `sentence-transformers/all-MiniLM-L6-v2` | 384 | Rápido, eficiente, código abierto |
| `sentence-transformers/all-mpnet-base-v2` | 768 | Equilibrio precisión/velocidad |
| `nomic-embed-text` | 768 | Contexto largo (8192 tokens) |
| `CLIP` (OpenAI) | 512 | Texto e imágenes en mismo espacio |
| `text-embedding-ada-002` (OpenAI, legacy) | 1,536 | Embedding clásico de OpenAI |
| `mxbai-embed-large` | 1,024 | Estado del arte open source |

---

## 2. Instalación y configuración

### Opción A — Compilar desde fuente (Linux/macOS)

```bash
# Prerequisitos
sudo apt-get install postgresql-server-dev-16  # Debian/Ubuntu
# brew install postgresql@16                   # macOS

# Clonar y compilar pgvector
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

### Opción B — Gestor de paquetes(opcion utilizada)

```bash
# Ubuntu / Debian (repositorio oficial PostgreSQL)
sudo apt-get install postgresql-16-pgvector

# macOS con Homebrew
brew install pgvector

# Docker — imagen oficial con pgvector incluido
docker run -e POSTGRES_PASSWORD=postgres \
           -p 5432:5432 \
           pgvector/pgvector:pg16
```

### Opción C — Docker Compose

```yaml
# docker-compose.yml
version: "3.9"
services:
  postgres:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: vectordb
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

### conectarse mediante plsql

```sql
-- Conectarse a la base de datos pgvector_db
PGPASSWORD=postgres_lab
psql -h localhost -p 5432 -U postgres -d pgvector_db

-- Verificar versión instalada
SELECT extversion FROM pg_extension WHERE extname = 'vector';
-- → 0.8.3

-- Ver tablas
\dt

-- Ver estructura de una tabla con su columna vector
\d documentos
```

---

## 3. Tipo de dato VECTOR

### Declaración de columnas

```sql
-- Vector de 384 dimensiones (all-MiniLM-L6-v2)
CREATE TABLE documentos (
    id          SERIAL PRIMARY KEY,
    contenido   TEXT NOT NULL,
    embedding   vector(384)
);

-- Vector de 1536 dimensiones (OpenAI text-embedding-3-small)
CREATE TABLE articulos (
    id          SERIAL PRIMARY KEY,
    titulo      TEXT,
    cuerpo      TEXT,
    fuente      VARCHAR(100),
    embedding   vector(1536),
    creado_en   TIMESTAMP DEFAULT NOW()
);

-- Máximo soportado: 16,000 dimensiones (pgvector >= 0.5.0)
-- Para índices HNSW/IVFFlat: máximo 2,000 dimensiones
```

### Insertar vectores

```sql
-- Insertar directamente con sintaxis de array
INSERT INTO documentos (contenido, embedding)
VALUES (
    'El machine learning transforma la industria',
    '[0.023, -0.142, 0.891, ..., 0.034]'   -- 384 valores
);
```

### Operaciones sobre vectores

```sql
-- Dimensiones de un vector
SELECT vector_dims(embedding) FROM documentos LIMIT 1;
-- → 384

-- Promedio de múltiples vectores (centroide)
SELECT avg(embedding) AS centroide FROM documentos;

```

---

## Comparativa con Soluciones Alternativas

| Característica | pgvector | Pinecone | Weaviate | Milvus | Chroma |
|---------------|----------|----------|----------|--------|--------|
| Tipo | Extensión SQL | SaaS | BD vectorial | BD vectorial | Librería |
| Infraestructura | PostgreSQL existente | Servicio cloud | Servicio propio | Servicio propio | En proceso |
| SQL + vectores | ✅ Nativo | ❌ | Parcial | ❌ | ❌ |
| ACID | ✅ | ❌ | Parcial | ❌ | ❌ |
| Joins con tablas | ✅ | ❌ | ❌ | ❌ | ❌ |
| Filtros híbridos | ✅ | ✅ | ✅ | ✅ | ✅ |
| Escalabilidad | Media | Alta | Alta | Alta | Baja |
| Coste | Muy bajo | Alto | Medio | Medio | Bajo |
| Curva de aprendizaje | Baja (SQL) | Baja | Media | Alta | Baja |
| Ideal para | Apps existentes PG, <50M vectors | Producción cloud, >50M vectors | Multimodal | Escala masiva | Prototipado |

---

## Buenas Prácticas

### ✅ Recomendaciones

1. **Normaliza los embeddings** antes de insertar si usas producto escalar (`<#>`) — es más rápido que coseno para vectores normalizados.

2. **Elige el tipo de índice correctamente:**
   - HNSW para consultas frecuentes con pocos insertos
   - IVFFlat para inserciones frecuentes o >1M vectores

3. **Crea el índice después de la carga inicial** — insertar millones de filas con un índice HNSW es mucho más lento que crear el índice al final.

4. **Usa `halfvec` si la memoria es limitada** (pgvector >= 0.7.0) — reduce el tamaño a la mitad con impacto mínimo en precisión.

5. **Almacena el texto original junto al embedding** — nunca almacenes solo el vector sin el contenido que lo generó.

6. **Versiona tu modelo de embeddings** — añade una columna `modelo_embedding VARCHAR(100)` para saber qué modelo generó cada vector.

7. **Monitoriza el recall** con un conjunto de evaluación — ajusta `ef_search` (HNSW) o `probes` (IVFFlat) hasta lograr >95% de recall.

### ⚠️ Errores comunes

```sql
-- ❌ MAL: Comparar embeddings de modelos distintos
-- Si mezclas OpenAI (1536 dims) con MiniLM (384 dims) → error o resultados sin sentido

-- ❌ MAL: Crear índice antes de insertar datos (IVFFlat)
CREATE INDEX ... USING ivfflat ...;   -- Con tabla vacía → índice inútil
INSERT INTO ...;                       -- El índice no indexa estos datos

-- ✅ BIEN: Insertar datos primero, luego crear el índice
INSERT INTO documentos ...;
CREATE INDEX ... USING ivfflat ...;

-- ❌ MAL: Usar ORDER BY similitud sin LIMIT (fuerza bruta sobre toda la tabla)
SELECT * FROM documentos ORDER BY embedding <=> query;          -- Sin LIMIT

-- ✅ BIEN: Siempre usa LIMIT con búsquedas vectoriales
SELECT * FROM documentos ORDER BY embedding <=> query LIMIT 20;

-- ❌ MAL: Umbral de distancia sin índice-friendly operator
WHERE embedding <-> query < 0.5                 -- Puede no usar el índice

-- ✅ BIEN: Usar ORDER BY + LIMIT, filtrar por similitud en post-proceso
SELECT *, 1-(embedding<=>query) AS sim
FROM documentos
ORDER BY embedding <=> query
LIMIT 100
-- Luego filtrar en Python: [r for r in rows if r['sim'] > 0.8]
```

---

## Referencias

- [pgvector GitHub](https://github.com/pgvector/pgvector) — Repositorio oficial, changelog y ejemplos
- [pgvector Docs](https://github.com/pgvector/pgvector#readme) — Documentación completa de operadores e índices
- [HNSW Paper](https://arxiv.org/abs/1603.09320) — "Efficient and robust approximate nearest neighbor search"
- [Sentence Transformers](https://www.sbert.net/) — Modelos open source de embeddings
- [OpenAI Embeddings Guide](https://platform.openai.com/docs/guides/embeddings) — API de embeddings de OpenAI
- [LangChain + pgvector](https://python.langchain.com/docs/integrations/vectorstores/pgvector) — Integración con LangChain para RAG
- [LlamaIndex + pgvector](https://docs.llamaindex.ai/en/stable/examples/vector_stores/postgres/) — Integración con LlamaIndex

---
