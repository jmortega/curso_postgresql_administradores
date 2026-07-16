# 🔢 pgvector Lab — PostgreSQL + Búsqueda Vectorial

> Laboratorio práctico de **pgvector**: almacenamiento de embeddings,
> búsqueda semántica por similitud coseno / euclidiana / producto interior,
> índices IVFFlat y HNSW, KNN, clustering y benchmark de rendimiento.

---

## 📋 Índice

1. [¿Qué es pgvector?](#1-qué-es-pgvector)
2. [Arquitectura del laboratorio](#2-arquitectura-del-laboratorio)
3. [Requisitos](#3-requisitos)
4. [Instalación y puesta en marcha](#4-instalación-y-puesta-en-marcha)
5. [Preparar los datos](#5-preparar-los-datos)
6. [Operaciones disponibles](#6-operaciones-disponibles)
7. [Ejecución](#7-ejecución)
8. [Variables de entorno](#8-variables-de-entorno)
9. [Estructura del proyecto](#9-estructura-del-proyecto)
10. [Referencia SQL](#10-referencia-sql)

---

## 1. ¿Qué es pgvector?

**pgvector** es una extensión de PostgreSQL que añade un tipo de dato `vector`
y operadores de distancia para búsqueda por similitud. Permite:

- Almacenar vectores de alta dimensión (embeddings de texto, imagen, audio…)
- Buscar los K vecinos más próximos (KNN) directamente en SQL
- Combinar búsqueda semántica con filtros relacionales (`WHERE precio < 500`)
- Usar índices aproximados (**IVFFlat**, **HNSW**) para escalar a millones de vectores

```
Embedding → [ 0.234, -0.187, 0.912, … ] (384 dimensiones)
                           │
                 almacenado en PostgreSQL
                           │
          SELECT * FROM docs ORDER BY embedding <=> query LIMIT 5;
```

### Operadores de distancia

| Operador | Métrica | Uso |
|---|---|---|
| `<->` | Distancia euclidiana L2 | Vectores sin normalizar |
| `<=>` | Distancia coseno | Vectores normalizados (similitud semántica) |
| `<#>` | Producto interior negativo | Vectores normalizados (equivale a coseno) |

---

## 2. Arquitectura del laboratorio

```
Tu máquina (host)
│
│  ┌─────────────────────────────────────────────────┐
│  │  Docker: pgvector/pgvector:pg16                  │
│  │                                                  │
│  │  PostgreSQL 16 + extensión vector               │
│  │                                                  │
│  │  BD: vectordb                                    │
│  │  Esquema: lab                                    │
│  │    ├── documentos  (50 filas, dim=384)           │
│  │    ├── productos   (30 filas, dim=384)           │
│  │    ├── usuarios    (20 filas, dim=128)           │
│  │    └── benchmark_resultados                      │
│  └─────────────────────────────────────────────────┘
│          localhost:5432
│
├── pgvector_lab.py        ← script principal (menú / demo / op individual)
├── data/prepare_data.py   ← genera los JSON de datos de prueba
└── data/*.json            ← documentos, productos, usuarios
```

---

## 3. Requisitos

| Herramienta | Versión mínima | Obligatorio |
|---|---|---|
| Docker | 24+ | ✅ |
| Docker Compose | 2.20+ | ✅ |
| Python | 3.10+ | ✅ |
| `psycopg2-binary` | 2.9+ | ✅ |
| `pgvector` (Python) | 0.3+ | ✅ |
| `numpy` | 1.24+ | ✅ |
| `sentence-transformers` | 3.0+ | ⭐ recomendado |
| `scikit-learn` | 1.4+ | Solo para op. 10 |

> `sentence-transformers` descarga el modelo `all-MiniLM-L6-v2` (~90 MB)
> la primera vez. Sin él, el laboratorio usa vectores aleatorios normalizados
> como fallback y todas las operaciones siguen funcionando.

---

## 4. Instalación y puesta en marcha

### Paso 1 — Levantar PostgreSQL con pgvector

```bash
docker compose up -d

# Verificar que el contenedor está listo (~10 segundos)
docker compose ps
```

**Salida esperada:**

```
NAME            STATUS          PORTS
pgvector-lab    Up (healthy)    0.0.0.0:5432->5432/tcp
```

El script `scripts/init.sql` se ejecuta automáticamente al arrancar y:
- Activa la extensión `vector`
- Crea el esquema `lab` con las 4 tablas del laboratorio

### Paso 2 — Instalar dependencias Python

```bash
# Crear entorno virtual (recomendado)
python -m venv .venv
source .venv/bin/activate      # Linux / macOS
# .venv\Scripts\activate       # Windows

# Instalar dependencias
pip install -r requirements.txt
```

### Paso 3 — Verificar la instalación

```bash
# Conectar con psql y verificar pgvector
psql -h localhost -p 5432 -U postgres -d vectordb \
     -c "SELECT extname, extversion FROM pg_extension WHERE extname='vector';"
# Password: postgres_lab

# Resultado esperado:
#  extname | extversion
# ---------+------------
#  vector  | 0.8.2
```

---

## 5. Preparar los datos

```bash
# Generar los ficheros JSON de datos de prueba
python data/prepare_data.py
```

**Salida:**

```
✓ documentos.json — 50 documentos
✓ productos.json  — 30 productos
✓ usuarios.json   — 20 usuarios
```

Los JSON contienen texto en español sobre tecnología, ciencia, historia,
arte y economía. Los embeddings se generan durante la ejecución del
script principal (operación 2).

---

## 6. Operaciones disponibles

| # | Operación | Qué demuestra |
|---|---|---|
| 1 | Verificar extensión pgvector | `pg_extension`, versión, operadores |
| 2 | Cargar datos + embeddings | `INSERT`, tipo `vector`, sentence-transformers |
| 3 | Búsqueda por similitud coseno | Operador `<=>`, búsqueda semántica |
| 4 | Búsqueda por distancia euclidiana | Operador `<->` |
| 5 | Búsqueda por producto interior | Operador `<#>` |
| 6 | Búsqueda filtrada (metadatos + vector) | `WHERE` + `ORDER BY embedding <=>` |
| 7 | Crear índices IVFFlat / HNSW | `CREATE INDEX USING ivfflat / hnsw` |
| 8 | Actualizar embeddings en caliente | `UPDATE ... SET embedding = ...` |
| 9 | K vecinos más cercanos (KNN) | KNN entre perfiles de usuario (dim=128) |
| 10 | Clustering de documentos | k-means sobre embeddings con scikit-learn |
| 11 | Benchmark: sin índice vs IVFFlat vs HNSW | Comparativa de tiempos de búsqueda |
| 12 | Estadísticas del laboratorio | Tamaños, distribuciones, resultados |

---

## 7. Ejecución

### Menú interactivo (por defecto)

```bash
python pgvector_lab.py
```

```
======================================================================
  pgvector Lab — PostgreSQL + pgvector
----------------------------------------------------------------------
  [ 1]  Verificar extensión pgvector
  [ 2]  Cargar datos + embeddings
  [ 3]  Búsqueda por similitud coseno (<=>)
  [ 4]  Búsqueda por distancia euclidiana (<->)
  ...
  [ 0]  Ejecutar todo (modo demo)
  [ q]  Salir
======================================================================
Elige operación:
```

---

## 8. Variables de entorno

Todos los parámetros de conexión se pueden configurar mediante variables
de entorno (los argumentos `--host`, `--password`, etc. tienen prioridad):

```bash
export PG_HOST=localhost
export PG_PORT=5432
export PG_USER=postgres
export PG_PASSWORD=postgres_lab
export PG_DBNAME=vectordb

python pgvector_lab.py --demo
```

---

## 9. Estructura del proyecto

```
pgvector-lab/
├── docker-compose.yml              # PostgreSQL 16 + pgvector
├── requirements.txt
├── pgvector_lab.py                 # Script principal — 12 operaciones
│
├── scripts/
│   └── init.sql                    # Activa extensión + crea tablas (auto)
│
└── data/
    ├── prepare_data.py             # Genera los JSON de datos de prueba
    ├── documentos.json             # 50 documentos (generado)
    ├── productos.json              # 30 productos  (generado)
    └── usuarios.json               # 20 usuarios   (generado)
```

---

## 10. Referencia SQL

### Tipo `vector` y operadores


```sql

psql -h localhost -p 5432 -U postgres -d vectordb
password:postgres_lab

-- Crear tabla con columna vector
CREATE TABLE items (
    id        SERIAL PRIMARY KEY,
    contenido TEXT,
    embedding vector(384)
);

```

### Índices vectoriales

```sql
-- IVFFlat: más rápido de construir, bueno para datasets medianos
CREATE INDEX ON items USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);   -- listas ≈ sqrt(n_filas)

-- Ajustar precisión en tiempo de consulta
SET ivfflat.probes = 10;   -- más alto = más preciso, más lento

-- HNSW: mayor velocidad de búsqueda, mejor recall
CREATE INDEX ON items USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- Ajustar precisión en búsqueda
SET hnsw.ef_search = 100;   -- más alto = más preciso, más lento

-- ── 1. Ver todos los índices del esquema lab ──────────────────
SELECT
    indexname                           AS nombre,
    tablename                           AS tabla,
    indexdef                            AS definicion
FROM pg_indexes
WHERE schemaname = 'lab'
ORDER BY tablename, indexname;

          nombre           |        tabla         |                                                        definicion                                                        
---------------------------+----------------------+--------------------------------------------------------------------------------------------------------------------------
 benchmark_resultados_pkey | benchmark_resultados | CREATE UNIQUE INDEX benchmark_resultados_pkey ON lab.benchmark_resultados USING btree (id)
 documentos_pkey           | documentos           | CREATE UNIQUE INDEX documentos_pkey ON lab.documentos USING btree (id)
 idx_doc_hnsw              | documentos           | CREATE INDEX idx_doc_hnsw ON lab.documentos USING hnsw (embedding vector_cosine_ops) WITH (m='16', ef_construction='64')
 idx_doc_ivfflat           | documentos           | CREATE INDEX idx_doc_ivfflat ON lab.documentos USING ivfflat (embedding vector_cosine_ops) WITH (lists='10')
 productos_pkey            | productos            | CREATE UNIQUE INDEX productos_pkey ON lab.productos USING btree (id)
 usuarios_pkey             | usuarios             | CREATE UNIQUE INDEX usuarios_pkey ON lab.usuarios USING btree (id)
(6 rows)


sql-- ── 2. Tipo de índice (ivfflat / hnsw / btree) ────────────────
SELECT
    c.relname                           AS indice,
    t.relname                           AS tabla,
    am.amname                           AS tipo,
    pg_size_pretty(pg_relation_size(i.indexrelid)) AS tamanio
FROM pg_index      i
JOIN pg_class      c  ON c.oid  = i.indexrelid
JOIN pg_class      t  ON t.oid  = i.indrelid
JOIN pg_am         am ON am.oid = c.relam
JOIN pg_namespace  n  ON n.oid  = t.relnamespace
WHERE n.nspname = 'lab'
ORDER BY t.relname, c.relname;

          indice           |        tabla         |  tipo   | tamanio 
---------------------------+----------------------+---------+---------
 benchmark_resultados_pkey | benchmark_resultados | btree   | 16 kB
 documentos_pkey           | documentos           | btree   | 16 kB
 idx_doc_hnsw              | documentos           | hnsw    | 112 kB
 idx_doc_ivfflat           | documentos           | ivfflat | 152 kB
 productos_pkey            | productos            | btree   | 16 kB
 usuarios_pkey             | usuarios             | btree   | 16 kB
(6 rows)


sql-- ── 3. Opciones internas de cada índice vectorial ─────────────
--    (muestra lists, m, ef_construction, etc.)
SELECT
    c.relname                           AS indice,
    am.amname                           AS tipo,
    ix.reloptions                       AS opciones
FROM pg_class      c
JOIN pg_am         am ON am.oid = c.relam
JOIN pg_class      ix ON ix.oid = (
    SELECT indexrelid FROM pg_index WHERE indexrelid = c.oid LIMIT 1
)
JOIN pg_namespace  n  ON n.oid  = c.relnamespace
WHERE n.nspname = 'lab'
  AND am.amname IN ('ivfflat','hnsw','btree')
ORDER BY c.relname;

          indice           |  tipo   |         opciones          
---------------------------+---------+---------------------------
 benchmark_resultados_pkey | btree   | 
 documentos_pkey           | btree   | 
 idx_doc_hnsw              | hnsw    | {m=16,ef_construction=64}
 idx_doc_ivfflat           | ivfflat | {lists=10}
 productos_pkey            | btree   | 
 usuarios_pkey             | btree   | 
(6 rows)


-- Alternativa más directa:
SELECT
    relname         AS indice,
    reloptions      AS opciones
FROM pg_class
WHERE relname IN ('idx_doc_ivfflat','idx_doc_hnsw');

sql-- ── 4. Uso real de cada índice (nº de veces usado) ───────────
SELECT
    indexrelname                        AS indice,
    relname                             AS tabla,
    idx_scan                            AS veces_usado,
    idx_tup_read                        AS entradas_leidas,
    idx_tup_fetch                       AS filas_devueltas,
    pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio
FROM pg_stat_user_indexes
WHERE schemaname = 'lab'
ORDER BY idx_scan DESC;

          indice           |        tabla         | veces_usado | entradas_leidas | filas_devueltas | tamanio 
---------------------------+----------------------+-------------+-----------------+-----------------+---------
 idx_doc_ivfflat           | documentos           |          46 |             218 |             218 | 152 kB
 documentos_pkey           | documentos           |           6 |               7 |               6 | 16 kB
 productos_pkey            | productos            |           0 |               0 |               0 | 16 kB
 usuarios_pkey             | usuarios             |           0 |               0 |               0 | 16 kB
 benchmark_resultados_pkey | benchmark_resultados |           0 |               0 |               0 | 16 kB
 idx_doc_hnsw              | documentos           |           0 |               0 |               0 | 112 kB
(6 rows)


sql-- ── 5. Confirmar que el planificador USA el índice ────────────
SET enable_seqscan = off;   -- forzar uso de índice

EXPLAIN (ANALYZE, BUFFERS)
    SELECT titulo
    FROM lab.documentos
    ORDER BY embedding <=> (SELECT embedding FROM lab.documentos LIMIT 1)
    LIMIT 5;

                                                                      QUERY PLAN                                                                       
-------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=10000000048.15..10000000053.41 rows=5 width=33) (actual time=147.887..147.895 rows=5 loops=1)
   Buffers: shared hit=26
   InitPlan 1 (returns $0)
     ->  Limit  (cost=10000000000.00..10000000000.27 rows=1 width=1544) (actual time=0.027..0.028 rows=1 loops=1)
           Buffers: shared hit=1
           ->  Seq Scan on documentos documentos_1  (cost=10000000000.00..10000000013.50 rows=50 width=1544) (actual time=0.026..0.026 rows=1 loops=1)
                 Buffers: shared hit=1
   ->  Index Scan using idx_doc_ivfflat on documentos  (cost=47.88..100.50 rows=50 width=33) (actual time=0.106..0.112 rows=5 loops=1)
         Order By: (embedding <=> $0)
         Buffers: shared hit=26
 Planning:
   Buffers: shared hit=20 dirtied=1
 Planning Time: 0.270 ms
 JIT:
   Functions: 9
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.801 ms, Inlining 67.675 ms, Optimization 44.946 ms, Emission 35.162 ms, Total 148.583 ms
 Execution Time: 300.625 ms
(18 rows)


RESET enable_seqscan;

-- Buscar en el plan: "Index Scan using idx_doc_hnsw" o "idx_doc_ivfflat"
sql-- ── 6. Resumen rápido — todo en una sola consulta ─────────────
SELECT
    i.indexrelname                                              AS indice,
    am.amname                                                   AS tipo,
    pg_size_pretty(pg_relation_size(i.indexrelid))              AS tamanio,
    i.idx_scan                                                  AS usos,
    CASE WHEN i.idx_scan > 0 THEN '✓ usado' ELSE '— sin usar aún' END AS estado
FROM pg_stat_user_indexes i
JOIN pg_class  c  ON c.oid  = i.indexrelid
JOIN pg_am     am ON am.oid = c.relam
WHERE i.schemaname = 'lab'
ORDER BY i.relname, am.amname;

         indice           |  tipo   | tamanio | usos |     estado     
---------------------------+---------+---------+------+----------------
 benchmark_resultados_pkey | btree   | 16 kB   |    0 | — sin usar aún
 documentos_pkey           | btree   | 16 kB   |    6 | ✓ usado
 idx_doc_hnsw              | hnsw    | 112 kB  |    0 | — sin usar aún
 idx_doc_ivfflat           | ivfflat | 152 kB  |   47 | ✓ usado
 productos_pkey            | btree   | 16 kB   |    0 | — sin usar aún
 usuarios_pkey             | btree   | 16 kB   |    0 | — sin usar aún
(6 rows)

```

### Parámetros de índices

| Parámetro | Índice | Efecto |
|---|---|---|
| `lists` | IVFFlat | Nº de clústeres (≈ √n_filas) |
| `probes` | IVFFlat | Clústeres inspeccionados en búsqueda (precisión) |
| `m` | HNSW | Conexiones por capa (calidad del grafo) |
| `ef_construction` | HNSW | Candidatos durante construcción (calidad) |
| `ef_search` | HNSW | Candidatos durante búsqueda (precisión/velocidad) |

---

## 🛠️ Comandos de gestión

```bash
# Levantar el contenedor
docker compose up -d

# Ver logs
docker compose logs -f

# Conectar con psql
psql -h localhost -p 5432 -U postgres -d vectordb
# Password: postgres_lab

# Ver extensiones activas
psql -h localhost -p 5432 -U postgres -d vectordb \
     -c "SELECT extname, extversion FROM pg_extension;"

# Resetear (elimina todos los datos)
docker compose down -v && docker compose up -d

# Detener sin borrar datos
docker compose stop
```

---

## 📚 Referencias

- [pgvector — GitHub](https://github.com/pgvector/pgvector)
- [pgvector — Docker Hub](https://hub.docker.com/r/pgvector/pgvector)
- [sentence-transformers](https://www.sbert.net/)
- [PostgreSQL — CREATE INDEX](https://www.postgresql.org/docs/current/sql-createindex.html)
- [Approximate Nearest Neighbor Search — HNSW](https://arxiv.org/abs/1603.09320)
