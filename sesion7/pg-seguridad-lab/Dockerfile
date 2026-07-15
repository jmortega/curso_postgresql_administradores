FROM postgres:16-bookworm

LABEL description="PostgreSQL 16 + pgAudit para laboratorio de seguridad y endurecimiento"

# Instalar pgAudit, openssl y utilidades
RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql-16-pgaudit \
        openssl \
        curl \
        vim \
        procps \
        iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Directorios para logs y certificados
RUN mkdir -p \
        /var/log/postgresql \
        /etc/postgresql/ssl \
        /scripts \
    && chown -R postgres:postgres \
        /var/log/postgresql \
        /etc/postgresql/ssl \
        /scripts

COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh 2>/dev/null || true \
    && chown -R postgres:postgres /scripts

USER postgres
