FROM postgres:16-bookworm

LABEL description="PostgreSQL 16 + PostGIS + pgvector + pg_wait_sampling para Sesión 2"

# Añadir repositorio de PostGIS y extensiones
RUN apt-get update && apt-get install -y --no-install-recommends \
        # PostGIS
        postgresql-16-postgis-3 \
        postgresql-16-postgis-3-scripts \
        # pgvector
        postgresql-16-pgvector \
        # pg_wait_sampling
        postgresql-16-pg-wait-sampling \
    && rm -rf /var/lib/apt/lists/*

USER postgres
