FROM postgres:16-bookworm

LABEL description="PostgreSQL 16 + repmgr para laboratorio de replicación y HA"

RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql-16-repmgr \
        postgresql-client-16 \
        iproute2 \
        iputils-ping \
        netcat-openbsd \
        curl \
        vim \
        procps \
        sudo \
        rsync \
        gosu \
    && rm -rf /var/lib/apt/lists/* \
    && gosu nobody true

RUN mkdir -p /var/log/repmgr /etc/repmgr \
    && chown -R postgres:postgres /var/log/repmgr /etc/repmgr

COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh 2>/dev/null || true \
    && chown -R postgres:postgres /scripts

WORKDIR /var/lib/postgresql
# Sin USER postgres: el entrypoint arranca como root,
# corrige permisos del volumen y hace exec gosu postgres.
