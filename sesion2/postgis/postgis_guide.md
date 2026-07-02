# PostGIS: Datos Geoespaciales en PostgreSQL

> **Guía completa** — Instalación, tipos de datos, funciones esenciales, casos de uso reales y buenas prácticas para trabajar con información geoespacial en PostgreSQL.

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
python scripts/postgis_manager.py
```

---


## Índice

1. [¿Qué es PostGIS?](#1-qué-es-postgis)
2. [Instalación y configuración](#2-instalación-y-configuración)
3. [Tipos de datos geoespaciales](#3-tipos-de-datos-geoespaciales)
4. [Sistemas de referencia de coordenadas (SRS/SRID)](#4-sistemas-de-referencia-de-coordenadas-srssrid)
5. [Operaciones y funciones esenciales](#5-operaciones-y-funciones-esenciales)
6. [Índices espaciales](#6-índices-espaciales)
7. [Casos de uso reales](#7-casos-de-uso-reales)
8. [Integración con Python](#8-integración-con-python)
9. [Buenas prácticas](#9-buenas-prácticas)
10. [Referencias](#10-referencias)

---

## 1. ¿Qué es PostGIS?

**PostGIS** es una extensión de PostgreSQL que añade soporte para **objetos geográficos y geométricos**, permitiendo que la base de datos funcione como un servidor de información geoespacial (GIS). Implementa los estándares del **Open Geospatial Consortium (OGC)** y de la **ISO SQL/MM**.

### ¿Por qué PostGIS?

| Característica | PostgreSQL sin PostGIS | PostgreSQL + PostGIS |
|---------------|----------------------|---------------------|
| Almacenar coordenadas | Sí (como números) | Sí (como geometría nativa) |
| Calcular distancias reales | No | Sí (en metros, km) |
| Consultas espaciales | No | Sí (`ST_Within`, `ST_Intersects`…) |
| Índices espaciales | No | Sí (GiST, BRIN) |
| Importar/exportar GeoJSON | No | Sí |
| Proyecciones cartográficas | No | Sí (miles de SRID) |

### Estándares que implementa

- **OGC Simple Features** — geometrías básicas (punto, línea, polígono)
- **ISO SQL/MM Part 3** — funciones espaciales estándar con prefijo `ST_`
- **GeoJSON (RFC 7946)** — formato de intercambio estándar
- **WKT / WKB** — Well-Known Text y Well-Known Binary
- **GML, KML, SVG** — formatos de exportación adicionales

---

### conectarse mediante plsql

```sql
-- Conectarse a la base de datos postgis_geo_db
PGPASSWORD=postgres_lab
psql -h localhost -p 5432 -U postgres -d postgis_geo_db

-- Verificar versión instalada
SELECT extversion FROM pg_extension WHERE extname = 'postgis';
-- → 3.6.4

-- Verificar la versión instalada
SELECT PostGIS_Full_Version();

-- Ver tablas
\dt

```

---

## 3. Tipos de datos geoespaciales

PostGIS proporciona dos familias de tipos:

### 3.1 `GEOMETRY` — Geometría plana (cartesiana)

Trabaja en un **plano 2D** con coordenadas X, Y. Adecuado para áreas pequeñas o cálculos en proyecciones locales.

```sql
-- Tipos básicos de geometría
POINT           -- Un punto (x, y)
LINESTRING      -- Una línea (secuencia de puntos)
POLYGON         -- Un polígono (área cerrada)
MULTIPOINT      -- Colección de puntos
MULTILINESTRING -- Colección de líneas
MULTIPOLYGON    -- Colección de polígonos
GEOMETRYCOLLECTION -- Mezcla de cualquier geometría
```

### 3.2 `GEOGRAPHY` — Geografía esférica (geodésica)

Trabaja sobre la **esfera terrestre**. Los cálculos de distancia y área son precisos en coordenadas WGS84 (latitud/longitud). Recomendado para aplicaciones globales.

```sql
-- La diferencia es el tipo de dato al declarar la columna
ubicacion GEOMETRY(POINT, 4326)   -- Geometría plana con SRID 4326
ubicacion GEOGRAPHY(POINT, 4326)  -- Geografía esférica (más precisa)
```

### 3.3 Creación de tablas con columnas geoespaciales

```sql
-- Tabla de puntos de interés (geometría)
CREATE TABLE puntos_interes (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(200) NOT NULL,
    categoria   VARCHAR(100),
    descripcion TEXT,
    ubicacion   GEOMETRY(POINT, 4326),  -- SRID 4326 = WGS84
    creado_en   TIMESTAMP DEFAULT NOW()
);

-- Tabla de rutas (líneas)
CREATE TABLE rutas (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(200),
    tipo        VARCHAR(50),  -- 'carretera', 'ferroviaria', 'ciclista'
    longitud_m  FLOAT,
    trazado     GEOMETRY(LINESTRING, 4326)
);

-- Tabla de zonas/regiones (polígonos)
CREATE TABLE zonas (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(200),
    tipo        VARCHAR(100), -- 'municipio', 'parque', 'zona_comercial'
    area_m2     FLOAT,
    perimetro   GEOMETRY(POLYGON, 4326)
);

-- Tabla con tipo GEOGRAPHY para mayor precisión global
CREATE TABLE sensores_iot (
    id              SERIAL PRIMARY KEY,
    sensor_id       VARCHAR(50) UNIQUE,
    tipo            VARCHAR(50),
    posicion        GEOGRAPHY(POINT, 4326),
    ultima_lectura  TIMESTAMP,
    activo          BOOLEAN DEFAULT TRUE
);
```

---

## 4. Sistemas de Referencia de Coordenadas (SRS/SRID)

El **SRID** (Spatial Reference System Identifier) define cómo se interpretan las coordenadas.

### SRIDs más comunes

| SRID | Nombre | Uso |
|------|--------|-----|
| **4326** | WGS84 (GPS) | Estándar global, lat/lon en grados |
| **3857** | Web Mercator | Google Maps, OpenStreetMap, tiles web |
| **25830** | ETRS89 UTM zona 30N | España peninsular (metros) |
| **25829** | ETRS89 UTM zona 29N | Galicia, Portugal |
| **32630** | WGS84 UTM zona 30N | Global zona 30 (metros) |
| **4258** | ETRS89 geográfico | Europa (grados) |

### Consultar SRIDs disponibles

```sql
-- Buscar sistemas de referencia por nombre
SELECT srid, srtext, proj4text
FROM spatial_ref_sys
WHERE srtext ILIKE '%Spain%'
   OR srtext ILIKE '%WGS%'
LIMIT 10;

-- Ver el SRID de una geometría
SELECT ST_SRID(ubicacion) FROM puntos_interes LIMIT 1;
```

### Transformar entre sistemas de referencia

```sql
-- Convertir de WGS84 (4326) a Web Mercator (3857)
SELECT ST_Transform(ubicacion::geometry, 3857) AS ubicacion_mercator
FROM puntos_interes;

-- Convertir de WGS84 a UTM zona 30N (25830) para cálculos en metros
SELECT
    nombre,
    ST_Length(ST_Transform(trazado, 25830)) AS longitud_metros
FROM rutas;
```

---

## 5. Operaciones y funciones esenciales

### 5.1 Crear geometrías

```sql
-- Crear un punto desde longitud y latitud
SELECT ST_SetSRID(ST_MakePoint(-3.7038, 40.4168), 4326) AS madrid;

-- Desde texto WKT
SELECT ST_GeomFromText('POINT(-3.7038 40.4168)', 4326) AS madrid;

-- Desde GeoJSON
SELECT ST_GeomFromGeoJSON(
    '{"type":"Point","coordinates":[-3.7038, 40.4168]}'
) AS madrid;

-- Crear un polígono (cuadrado)
SELECT ST_MakeEnvelope(-3.72, 40.41, -3.68, 40.43, 4326) AS bbox_madrid;

-- Crear una línea
SELECT ST_MakeLine(
    ST_MakePoint(-3.7038, 40.4168),
    ST_MakePoint(2.1734, 41.3851)
) AS madrid_barcelona;
```

### 5.2 Calcular distancias

```sql
-- Distancia en grados (GEOMETRY) — NO recomendado para distancias reales
SELECT
    ST_Distance(
        ST_GeomFromText('POINT(-3.7038 40.4168)', 4326),
        ST_GeomFromText('POINT(2.1734 41.3851)', 4326)
    ) AS distancia_grados;

-- Distancia en metros (GEOGRAPHY) — RECOMENDADO
SELECT
    ST_Distance(
        ST_GeogFromText('POINT(-3.7038 40.4168)'),
        ST_GeogFromText('POINT(2.1734 41.3851)')
    ) AS distancia_metros;

-- Resultado: ~504,000 metros (~504 km entre Madrid y Barcelona)

-- Distancia en metros transformando primero a UTM
SELECT
    ST_Distance(
        ST_Transform(ST_GeomFromText('POINT(-3.7038 40.4168)', 4326), 25830),
        ST_Transform(ST_GeomFromText('POINT(2.1734 41.3851)', 4326), 25830)
    ) AS distancia_metros_utm;
```

### 5.3 Consultas de contenencia y proximidad

```sql
-- ¿Qué puntos están dentro de un polígono?
SELECT p.nombre
FROM puntos_interes p, zonas z
WHERE z.nombre = 'Centro Madrid'
  AND ST_Within(p.ubicacion::geometry, z.perimetro);

-- Puntos en un radio de 1 km alrededor de un punto
SELECT nombre, categoria,
    ST_Distance(
        ubicacion::geography,
        ST_GeogFromText('POINT(-3.7038 40.4168)')
    ) AS distancia_m
FROM puntos_interes
WHERE ST_DWithin(
    ubicacion::geography,
    ST_GeogFromText('POINT(-3.7038 40.4168)'),
    1000   -- 1000 metros
)
ORDER BY distancia_m;

-- Los 5 puntos más cercanos a una ubicación (KNN)
SELECT nombre,
    ubicacion <-> ST_SetSRID(ST_MakePoint(-3.7038, 40.4168), 4326)
        AS distancia_grados
FROM puntos_interes
ORDER BY distancia_grados
LIMIT 5;
```

### 5.4 Relaciones espaciales

```sql
-- ST_Intersects: ¿se cruzan dos geometrías?
SELECT a.nombre, b.nombre
FROM rutas a, zonas b
WHERE ST_Intersects(a.trazado, b.perimetro);

-- ST_Contains: ¿A contiene completamente a B?
SELECT z.nombre AS zona, p.nombre AS punto
FROM zonas z, puntos_interes p
WHERE ST_Contains(z.perimetro, p.ubicacion);

-- ST_Touches: ¿comparten frontera pero no interior?
SELECT a.nombre, b.nombre
FROM zonas a, zonas b
WHERE a.id <> b.id
  AND ST_Touches(a.perimetro, b.perimetro);

-- ST_Overlaps: ¿se solapan parcialmente?
SELECT a.nombre, b.nombre
FROM zonas a, zonas b
WHERE a.id < b.id
  AND ST_Overlaps(a.perimetro, b.perimetro);
```

### 5.5 Operaciones de geometría

```sql
-- Buffer: zona de influencia de 500 metros alrededor de un punto
SELECT ST_Buffer(ubicacion::geography, 500)::geometry AS area_influencia
FROM puntos_interes
WHERE nombre = 'Hospital Central';

-- Unión de varios polígonos
SELECT ST_Union(perimetro) AS union_total
FROM zonas
WHERE tipo = 'municipio';

-- Intersección de dos zonas
SELECT ST_Intersection(a.perimetro, b.perimetro) AS zona_comun
FROM zonas a, zonas b
WHERE a.nombre = 'Zona Norte' AND b.nombre = 'Zona Centro';

-- Centroide de un polígono
SELECT nombre, ST_Centroid(perimetro) AS centro
FROM zonas;

-- Área en metros cuadrados
SELECT nombre,
    ST_Area(perimetro::geography) AS area_m2,
    ST_Area(perimetro::geography) / 1000000 AS area_km2
FROM zonas;

-- Longitud de una línea en metros
SELECT nombre,
    ST_Length(trazado::geography) AS longitud_m
FROM rutas;

-- Simplificar geometría compleja (para visualización)
SELECT nombre,
    ST_Simplify(perimetro, 0.001) AS perimetro_simplificado
FROM zonas;
```

### 5.6 Exportar a formatos estándar

```sql
-- Exportar como GeoJSON
SELECT ST_AsGeoJSON(ubicacion) AS geojson
FROM puntos_interes;

-- Exportar como WKT
SELECT ST_AsText(ubicacion) AS wkt
FROM puntos_interes;

-- Exportar como KML (para Google Earth)
SELECT ST_AsKML(ubicacion) AS kml
FROM puntos_interes;

-- Exportar colección completa como GeoJSON FeatureCollection
SELECT json_build_object(
    'type', 'FeatureCollection',
    'features', json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', ST_AsGeoJSON(ubicacion)::json,
            'properties', json_build_object(
                'id', id,
                'nombre', nombre,
                'categoria', categoria
            )
        )
    )
) AS feature_collection
FROM puntos_interes;
```

---

## 6. Índices espaciales

Los índices espaciales son **críticos** para el rendimiento de consultas geoespaciales sobre grandes volúmenes de datos.

### Crear índices GiST (recomendado)

```sql
-- Índice espacial estándar sobre geometría
CREATE INDEX idx_puntos_interes_ubicacion
    ON puntos_interes USING GIST (ubicacion);

-- Índice sobre columna geography
CREATE INDEX idx_sensores_posicion
    ON sensores_iot USING GIST (posicion);

-- Índice sobre rutas (líneas)
CREATE INDEX idx_rutas_trazado
    ON rutas USING GIST (trazado);

-- Índice sobre polígonos
CREATE INDEX idx_zonas_perimetro
    ON zonas USING GIST (perimetro);
```

### Verificar uso del índice

```sql
-- Explicar plan de consulta (debe mostrar Bitmap Index Scan)
EXPLAIN ANALYZE
SELECT nombre
FROM puntos_interes
WHERE ST_DWithin(
    ubicacion::geography,
    ST_GeogFromText('POINT(-3.7038 40.4168)'),
    1000
);
```

### Cuándo usar cada operador

| Operador | Índice | Descripción |
|----------|--------|-------------|
| `ST_DWithin` | ✅ Usa índice | Puntos dentro de un radio |
| `ST_Within` | ✅ Usa índice | Contenido en geometría |
| `ST_Intersects` | ✅ Usa índice | Intersección |
| `&&` | ✅ Usa índice | Bounding boxes se superponen |
| `<->` | ✅ Usa índice | Distancia KNN (ORDER BY) |
| `ST_Distance` en WHERE | ❌ No usa índice | Usar `ST_DWithin` en su lugar |

---

## 7. Casos de uso

### 7.1 Geolocalización de usuarios y negocios

**Escenario:** Aplicación de comercio local — encontrar tiendas cerca del usuario.

```sql
-- Tabla de negocios
CREATE TABLE negocios (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(200),
    categoria   VARCHAR(100),
    direccion   TEXT,
    telefono    VARCHAR(20),
    horario     JSONB,
    valoracion  NUMERIC(3,2),
    ubicacion   GEOGRAPHY(POINT, 4326),
    activo      BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_negocios_ubicacion ON negocios USING GIST (ubicacion);

-- Consulta: negocios de restauración a menos de 500m, ordenados por distancia
SELECT
    nombre,
    categoria,
    valoracion,
    ROUND(ST_Distance(
        ubicacion,
        ST_GeogFromText('POINT(-3.7038 40.4168)')
    )::numeric, 0) AS distancia_m
FROM negocios
WHERE categoria = 'restaurante'
  AND activo = TRUE
  AND ST_DWithin(
        ubicacion,
        ST_GeogFromText('POINT(-3.7038 40.4168)'),
        500
      )
ORDER BY distancia_m
LIMIT 10;
```

---

### 7.2 Seguimiento de flotas y vehículos

**Escenario:** Sistema de logística — registrar posiciones GPS en tiempo real.

```sql
-- Tabla de vehículos
CREATE TABLE vehiculos (
    id          SERIAL PRIMARY KEY,
    matricula   VARCHAR(20) UNIQUE,
    tipo        VARCHAR(50),
    conductor   VARCHAR(100),
    activo      BOOLEAN DEFAULT TRUE
);

-- Tabla de trazas GPS (una entrada por lectura)
CREATE TABLE trazas_gps (
    id          BIGSERIAL PRIMARY KEY,
    vehiculo_id INTEGER REFERENCES vehiculos(id),
    timestamp   TIMESTAMP NOT NULL DEFAULT NOW(),
    posicion    GEOGRAPHY(POINT, 4326),
    velocidad   NUMERIC(6,2),  -- km/h
    rumbo       NUMERIC(5,2),  -- grados 0-360
    altitud_m   NUMERIC(8,2)
);

CREATE INDEX idx_trazas_vehiculo_ts
    ON trazas_gps (vehiculo_id, timestamp DESC);
CREATE INDEX idx_trazas_posicion
    ON trazas_gps USING GIST (posicion);

-- Última posición conocida de cada vehículo
SELECT DISTINCT ON (v.matricula)
    v.matricula,
    v.conductor,
    t.timestamp,
    ST_Y(t.posicion::geometry) AS latitud,
    ST_X(t.posicion::geometry) AS longitud,
    t.velocidad
FROM vehiculos v
JOIN trazas_gps t ON t.vehiculo_id = v.id
ORDER BY v.matricula, t.timestamp DESC;

-- Distancia total recorrida por un vehículo en un día
SELECT
    v.matricula,
    ROUND(
        ST_Length(
            ST_MakeLine(posicion::geometry ORDER BY timestamp)::geography
        )::numeric / 1000,
        2
    ) AS km_recorridos
FROM trazas_gps t
JOIN vehiculos v ON v.id = t.vehiculo_id
WHERE t.timestamp::date = CURRENT_DATE
  AND v.matricula = '1234ABC'
GROUP BY v.matricula;

-- Vehículos dentro de una zona geofence (polígono)
SELECT v.matricula, v.conductor
FROM vehiculos v
JOIN LATERAL (
    SELECT posicion FROM trazas_gps
    WHERE vehiculo_id = v.id
    ORDER BY timestamp DESC LIMIT 1
) ultima ON TRUE
WHERE ST_Within(
    ultima.posicion::geometry,
    ST_GeomFromText('POLYGON((-3.72 40.41, -3.68 40.41,
                               -3.68 40.43, -3.72 40.43,
                               -3.72 40.41))', 4326)
);
```

---

### 7.3 Análisis de zonas de cobertura

**Escenario:** Planificación urbana — calcular zonas de influencia de hospitales.

```sql
-- Hospitales con sus zonas de cobertura
CREATE TABLE hospitales (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(200),
    nivel           INTEGER,    -- 1=Centro Salud, 2=Hospital, 3=Gran Hospital
    num_camas       INTEGER,
    ubicacion       GEOGRAPHY(POINT, 4326),
    zona_cobertura  GEOMETRY(POLYGON, 4326)
);

-- Calcular zona de cobertura como buffer según nivel
UPDATE hospitales SET zona_cobertura =
    ST_Buffer(
        ubicacion::geometry,
        CASE nivel
            WHEN 1 THEN 0.005    -- ~500m centro de salud
            WHEN 2 THEN 0.02     -- ~2km hospital comarcal
            WHEN 3 THEN 0.05     -- ~5km gran hospital
        END
    );

-- Población en zonas sin cobertura hospitalaria
SELECT p.nombre AS barrio, p.poblacion
FROM barrios p
WHERE NOT EXISTS (
    SELECT 1 FROM hospitales h
    WHERE ST_Intersects(p.perimetro, h.zona_cobertura)
)
ORDER BY p.poblacion DESC;

-- Solapamiento entre zonas de cobertura (hospitales cercanos)
SELECT
    a.nombre AS hospital_a,
    b.nombre AS hospital_b,
    ROUND(ST_Area(
        ST_Intersection(a.zona_cobertura, b.zona_cobertura)::geography
    )::numeric / 1000000, 2) AS area_solapamiento_km2
FROM hospitales a, hospitales b
WHERE a.id < b.id
  AND ST_Intersects(a.zona_cobertura, b.zona_cobertura);
```

---

### 7.4 Análisis medioambiental

**Escenario:** Monitorización de calidad del aire con sensores IoT.

```sql
-- Sensores de calidad del aire
CREATE TABLE sensores_aire (
    id          SERIAL PRIMARY KEY,
    codigo      VARCHAR(50) UNIQUE,
    posicion    GEOGRAPHY(POINT, 4326),
    instalado   DATE,
    activo      BOOLEAN DEFAULT TRUE
);

-- Lecturas de los sensores
CREATE TABLE lecturas_aire (
    id          BIGSERIAL PRIMARY KEY,
    sensor_id   INTEGER REFERENCES sensores_aire(id),
    timestamp   TIMESTAMP NOT NULL,
    pm25        NUMERIC(6,2),   -- µg/m³ partículas finas
    pm10        NUMERIC(6,2),
    no2         NUMERIC(6,2),   -- ppb dióxido de nitrógeno
    co          NUMERIC(6,2),   -- ppm monóxido de carbono
    temperatura NUMERIC(5,2),
    humedad     NUMERIC(5,2)
);

CREATE INDEX idx_lecturas_sensor_ts
    ON lecturas_aire (sensor_id, timestamp DESC);
CREATE INDEX idx_sensores_posicion
    ON sensores_aire USING GIST (posicion);

-- Mapa de calor: promedio de PM2.5 por sector (cuadrícula 0.01°)
SELECT
    ROUND(ST_X(posicion::geometry)::numeric / 0.01) * 0.01 AS lon_sector,
    ROUND(ST_Y(posicion::geometry)::numeric / 0.01) * 0.01 AS lat_sector,
    ROUND(AVG(l.pm25)::numeric, 2) AS pm25_promedio,
    COUNT(*) AS num_lecturas
FROM sensores_aire s
JOIN lecturas_aire l ON l.sensor_id = s.id
WHERE l.timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY lon_sector, lat_sector
ORDER BY pm25_promedio DESC;

-- Zonas con contaminación crítica (PM2.5 > 25 µg/m³ OMS)
SELECT
    s.codigo,
    AVG(l.pm25) AS pm25_medio,
    ST_AsGeoJSON(s.posicion) AS geojson,
    ST_Buffer(s.posicion::geometry, 0.005) AS zona_afectada
FROM sensores_aire s
JOIN lecturas_aire l ON l.sensor_id = s.id
WHERE l.timestamp >= NOW() - INTERVAL '1 hour'
GROUP BY s.id, s.codigo, s.posicion
HAVING AVG(l.pm25) > 25
ORDER BY pm25_medio DESC;
```

---

### 7.5 Análisis de redes de transporte

**Escenario:** Calcular tiempo de viaje y accesibilidad en red viaria.

```sql
-- Red de carreteras (requiere extensión pgRouting)
CREATE EXTENSION IF NOT EXISTS pgrouting;

CREATE TABLE red_viaria (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(200),
    tipo        VARCHAR(50),      -- 'autopista','nacional','local'
    velocidad   INTEGER,          -- km/h máxima
    sentido     VARCHAR(10),      -- 'ambos','ida','vuelta'
    trazado     GEOMETRY(LINESTRING, 4326),
    source      INTEGER,          -- nodo origen (pgRouting)
    target      INTEGER,          -- nodo destino (pgRouting)
    cost        FLOAT,            -- coste (tiempo en minutos)
    reverse_cost FLOAT
);

CREATE INDEX idx_red_viaria_trazado ON red_viaria USING GIST (trazado);

-- Calcular topología de la red
SELECT pgr_createTopology('red_viaria', 0.0001, 'trazado', 'id');

-- Ruta más corta entre dos puntos (Dijkstra)
SELECT
    r.seq,
    rv.nombre,
    rv.tipo,
    r.cost AS minutos,
    ST_AsGeoJSON(rv.trazado) AS tramo_geojson
FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM red_viaria',
    1,    -- nodo origen
    150,  -- nodo destino
    directed := true
) r
JOIN red_viaria rv ON rv.id = r.edge
ORDER BY r.seq;
```

---

## 8. Integración con Python

### Librerías principales

| Librería | Función |
|----------|---------|
| `psycopg2` | Conexión a PostgreSQL |
| `geopandas` | DataFrames geoespaciales |
| `shapely` | Creación y manipulación de geometrías |
| `folium` | Mapas interactivos (Leaflet.js) |
| `SQLAlchemy` + `GeoAlchemy2` | ORM con soporte geoespacial |

### Instalación

```bash
pip install psycopg2-binary geopandas shapely folium sqlalchemy geoalchemy2
```

---

## 9. Buenas prácticas

### ✅ Recomendaciones generales

1. **Usa `GEOGRAPHY` para coordenadas globales** (lat/lon WGS84) y `GEOMETRY` para coordenadas proyectadas locales (UTM en metros).

2. **Crea siempre índices GiST** sobre columnas espaciales antes de cargar datos en producción.

3. **Usa `ST_DWithin` en lugar de `ST_Distance` en cláusulas WHERE** — `ST_DWithin` usa el índice espacial, `ST_Distance` no.

4. **Especifica siempre el SRID** al crear geometrías. Una geometría sin SRID es una fuente de errores difíciles de detectar.

5. **Normaliza los datos antes de importar**: elimina geometrías nulas con `ST_IsValid()` y repara geometrías inválidas con `ST_MakeValid()`.

6. **Usa `ST_Simplify` para visualización** — Las geometrías complejas (miles de vértices) pueden simplificarse para renderizado sin perder precisión en el análisis.

7. **Mantén estadísticas actualizadas**: ejecuta `ANALYZE` regularmente para que el planificador de consultas tome decisiones óptimas.

### ⚠️ Errores comunes a evitar

```sql
-- ❌ MAL: ST_Distance en WHERE (no usa índice)
WHERE ST_Distance(ubicacion, ST_GeogFromText('POINT(...)')) < 1000

-- ✅ BIEN: ST_DWithin en WHERE (usa índice)
WHERE ST_DWithin(ubicacion, ST_GeogFromText('POINT(...)'), 1000)

-- ❌ MAL: Geometría sin SRID
INSERT INTO puntos (ubicacion) VALUES (ST_MakePoint(-3.7, 40.4));

-- ✅ BIEN: Geometría con SRID explícito
INSERT INTO puntos (ubicacion)
VALUES (ST_SetSRID(ST_MakePoint(-3.7, 40.4), 4326));

-- ❌ MAL: Mezclar GEOMETRY y GEOGRAPHY sin conversión
WHERE ST_DWithin(geom_col, geog_col, 1000)  -- Error de tipos

-- ✅ BIEN: Conversión explícita
WHERE ST_DWithin(geom_col::geography, geog_col, 1000)
```

---

## 10. Referencias

- [PostGIS Documentation](https://postgis.net/documentation/) — Documentación oficial completa
- [PostGIS Cheatsheet](https://postgis.net/docs/PostGIS_Special_Functions_Index.html) — Índice de funciones
- [OGC Standards](https://www.ogc.org/standards/) — Estándares geoespaciales
- [EPSG Registry](https://epsg.io/) — Búsqueda de SRIDs
- [pgRouting](https://pgrouting.org/) — Extensión para análisis de redes
- [GeoJSON.io](https://geojson.io/) — Editor visual de GeoJSON

---
