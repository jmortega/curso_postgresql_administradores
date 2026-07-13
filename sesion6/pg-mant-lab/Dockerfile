FROM postgres:16-bookworm

LABEL description="PostgreSQL 16 + pg_cron para laboratorio de mantenimiento y sondas de vida"

RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql-16-cron \
        rsync \
        bc \
        procps \
        curl \
        vim \
    && rm -rf /var/lib/apt/lists/*

# Directorios en los que el usuario postgres necesita escribir
RUN mkdir -p /scripts /backup/logico /backup/fisico /backup/wal_archive /var/log/pg_lab \
    && chown -R postgres:postgres /scripts /backup /var/log/pg_lab

COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh 2>/dev/null || true \
    && chown -R postgres:postgres /scripts

USER postgres
