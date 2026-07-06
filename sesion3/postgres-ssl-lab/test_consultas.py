#!/usr/bin/env python3
"""
test_consultas.py
=================
Ejecuta consultas de diagnóstico sobre PostgreSQL cubriendo:
  1. pg_catalog y vistas de metadatos
  2. Bases de datos, roles, esquemas, tablespaces y objetos
  3. Estadísticas del sistema y pg_stat_statements
  4. Actividad, bloqueos y sesiones

Soporta dos modos de conexión:
  - Sin certificado cliente  (sslmode=require)
  - Con certificado cliente  (sslmode=verify-full)

Uso:
  # Sin cert cliente
  python test_consultas.py --host localhost --password pgpassword

  # Con cert cliente (verify-full)
  python test_consultas.py --host localhost --password pgpassword \
      --sslcert certs/client/client.crt \
      --sslkey  certs/client/client.key \
      --sslrootcert certs/ca/ca.crt
"""

import argparse
import sys
import os

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("[ERROR] psycopg2 no encontrado. Instálalo con: pip install psycopg2-binary")
    sys.exit(1)

GREEN  = "\033[92m"; RED  = "\033[91m"; YELLOW = "\033[93m"
CYAN   = "\033[96m"; BOLD = "\033[1m";  RESET  = "\033[0m"

def header(text):
    print(f"\n{BOLD}{CYAN}{'─'*62}{RESET}")
    print(f"{BOLD}{CYAN}  {text}{RESET}")
    print(f"{BOLD}{CYAN}{'─'*62}{RESET}")

def subheader(text):
    print(f"\n{BOLD}▸ {text}{RESET}")

def ok(text):   print(f"  {GREEN}✓{RESET} {text}")
def warn(text): print(f"  {YELLOW}⚠{RESET} {text}")
def err(text):  print(f"  {RED}✗{RESET} {text}")

def run_query(cur, sql, title, show_rows=True, max_rows=10):
    subheader(title)
    try:
        cur.execute(sql)
        rows = cur.fetchall()
        if not rows:
            warn("Sin resultados")
            return []
        if show_rows:
            cols = list(rows[0].keys())
            col_w = {c: max(len(str(c)), max(len(str(r[c])) for r in rows)) for c in cols}
            header_line = "  " + "  ".join(str(c).ljust(col_w[c]) for c in cols)
            print(f"{BOLD}{header_line}{RESET}")
            print("  " + "  ".join("─" * col_w[c] for c in cols))
            for row in rows[:max_rows]:
                print("  " + "  ".join(str(row[c]).ljust(col_w[c]) for c in cols))
            if len(rows) > max_rows:
                print(f"  {YELLOW}... {len(rows)-max_rows} filas más{RESET}")
        ok(f"{len(rows)} fila(s)")
        return rows
    except Exception as e:
        err(f"Error: {e}")
        return []


def connect(args):
    params = {
        "host":    args.host,
        "port":    args.port,
        "dbname":  args.dbname,
        "user":    args.user,
        "password": args.password,
        "connect_timeout": 10,
    }
    has_certs = args.sslcert and args.sslkey and args.sslrootcert

    if has_certs:
        params.update({
            "sslmode":     "verify-full",
            "sslcert":     args.sslcert,
            "sslkey":      args.sslkey,
            "sslrootcert": args.sslrootcert,
        })
        mode_label = "verify-full (con certificado cliente)"
    else:
        params["sslmode"] = "require"
        mode_label = "require (sin certificado cliente)"

    try:
        conn = psycopg2.connect(**params)
        ok(f"Conectado en modo {BOLD}{mode_label}{RESET}")
        return conn
    except Exception as e:
        err(f"Conexión fallida: {e}")
        sys.exit(1)


def seccion_ssl_info(cur):
    header("INFORMACIÓN DE LA CONEXIÓN SSL")
    run_query(cur, """
        SELECT
            ssl,
            version         AS protocolo,
            cipher,
            bits,
            client_dn       AS cert_cliente
        FROM pg_stat_ssl
        WHERE pid = pg_backend_pid()
    """, "Estado SSL de esta sesión")

    run_query(cur, """
        SELECT
            current_user        AS usuario,
            current_database()  AS base_datos,
            inet_client_addr()  AS ip_cliente,
            inet_server_addr()  AS ip_servidor,
            pg_backend_pid()    AS pid
    """, "Contexto de la sesión")


def seccion_pg_catalog(cur):
    header("1 · pg_catalog Y VISTAS DE METADATOS ESENCIALES")

    run_query(cur, """
        SELECT
            c.relname                               AS tabla,
            n.nspname                               AS esquema,
            c.relkind                               AS tipo,
            pg_size_pretty(pg_total_relation_size(c.oid)) AS tamanio_total,
            c.reltuples::BIGINT                     AS filas_estimadas,
            obj_description(c.oid, 'pg_class')      AS comentario
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('ventas','rrhh')
          AND c.relkind IN ('r','v','m')
        ORDER BY n.nspname, c.relname
    """, "pg_class — tablas y vistas del lab")

    run_query(cur, """
        SELECT
            a.attname                               AS columna,
            pg_catalog.format_type(a.atttypid, a.atttypmod) AS tipo,
            a.attnotnull                            AS obligatorio,
            a.atthasdef                             AS tiene_default,
            col_description(a.attrelid, a.attnum)   AS comentario
        FROM pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_class c      ON c.oid = a.attrelid
        JOIN pg_catalog.pg_namespace n  ON n.oid = c.relnamespace
        WHERE n.nspname = 'ventas'
          AND c.relname = 'pedidos'
          AND a.attnum > 0
          AND NOT a.attisdropped
        ORDER BY a.attnum
    """, "pg_attribute — columnas de ventas.pedidos")

    run_query(cur, """
        SELECT
            i.relname               AS indice,
            ix.indisunique          AS unico,
            ix.indisprimary         AS primario,
            array_to_string(
                ARRAY(SELECT pg_get_indexdef(ix.indexrelid, k+1, true)
                      FROM generate_subscripts(ix.indkey, 1) k),
            ', ')                   AS columnas,
            pg_size_pretty(pg_relation_size(i.oid)) AS tamanio
        FROM pg_catalog.pg_index ix
        JOIN pg_catalog.pg_class t ON t.oid = ix.indrelid
        JOIN pg_catalog.pg_class i ON i.oid = ix.indexrelid
        JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'ventas'
        ORDER BY t.relname, i.relname
    """, "pg_index — índices del esquema ventas")

    run_query(cur, """
        SELECT
            conname                 AS restriccion,
            contype                 AS tipo,
            conrelid::regclass      AS tabla,
            confrelid::regclass     AS tabla_ref
        FROM pg_catalog.pg_constraint
        WHERE conrelid::regclass::text LIKE 'ventas.%'
        ORDER BY contype, conname
    """, "pg_constraint — restricciones del esquema ventas")


def seccion_objetos(cur):
    header("2 · BASES DE DATOS, ROLES, ESQUEMAS, TABLESPACES Y OBJETOS")

    run_query(cur, """
        SELECT
            datname                 AS base_datos,
            pg_size_pretty(pg_database_size(datname)) AS tamanio,
            datcollate              AS collation,
            datconnlimit            AS max_conexiones,
            datistemplate           AS es_template
        FROM pg_catalog.pg_database
        WHERE NOT datistemplate
        ORDER BY pg_database_size(datname) DESC
    """, "Bases de datos")

    run_query(cur, """
        SELECT
            rolname                 AS rol,
            rolsuper                AS superuser,
            rolcreatedb             AS puede_crear_bd,
            rolcreaterole           AS puede_crear_rol,
            rolcanlogin             AS puede_hacer_login,
            rolconnlimit            AS max_conexiones,
            rolvaliduntil           AS expira
        FROM pg_catalog.pg_roles
        WHERE rolname NOT LIKE 'pg_%'
        ORDER BY rolname
    """, "Roles y usuarios")

    run_query(cur, """
        SELECT
            nspname                 AS esquema,
            pg_catalog.pg_get_userbyid(nspowner) AS propietario,
            array_to_string(nspacl, ', ')         AS permisos
        FROM pg_catalog.pg_namespace
        WHERE nspname NOT LIKE 'pg_%'
          AND nspname != 'information_schema'
        ORDER BY nspname
    """, "Esquemas")

    run_query(cur, """
        SELECT
            spcname                 AS tablespace,
            pg_catalog.pg_get_userbyid(spcowner) AS propietario,
            pg_tablespace_location(oid)           AS ubicacion,
            pg_size_pretty(pg_tablespace_size(oid)) AS tamanio
        FROM pg_catalog.pg_tablespace
        ORDER BY spcname
    """, "Tablespaces")

    run_query(cur, """
        SELECT
            n.nspname               AS esquema,
            c.relname               AS tabla,
            pg_size_pretty(pg_relation_size(c.oid))       AS datos,
            pg_size_pretty(pg_indexes_size(c.oid))        AS indices,
            pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
            c.reltuples::BIGINT                            AS filas_est
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'r'
          AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
        ORDER BY pg_total_relation_size(c.oid) DESC
        LIMIT 15
    """, "Tamaño de tablas (top 15)")

    run_query(cur, """
        SELECT
            proname                 AS funcion,
            n.nspname               AS esquema,
            pg_get_function_identity_arguments(p.oid) AS argumentos,
            prokind                 AS tipo,
            prosecdef               AS security_definer
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname NOT IN ('pg_catalog','information_schema')
        ORDER BY n.nspname, proname
        LIMIT 10
    """, "Funciones y procedimientos (top 10)")


def seccion_estadisticas(cur):
    header("3 · ESTADÍSTICAS DEL SISTEMA Y pg_stat_statements")

    run_query(cur, """
        SELECT
            datname                 AS base_datos,
            blks_read,
            blks_hit,
            round(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2)
                                    AS cache_hit_pct,
            tup_returned,
            tup_fetched,
            tup_inserted,
            tup_updated,
            tup_deleted,
            xact_commit,
            xact_rollback,
            deadlocks
        FROM pg_stat_database
        WHERE datname = current_database()
    """, "pg_stat_database — estadísticas de la BD actual")

    run_query(cur, """
        SELECT
            schemaname              AS esquema,
            relname               AS tabla,
            seq_scan,
            seq_tup_read,
            idx_scan,
            idx_tup_fetch,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_live_tup,
            n_dead_tup,
            last_autovacuum::TIMESTAMP(0),
            last_autoanalyze::TIMESTAMP(0)
        FROM pg_stat_user_tables
        WHERE schemaname IN ('ventas','rrhh')
        ORDER BY seq_scan DESC
    """, "pg_stat_user_tables — actividad por tabla")

    run_query(cur, """
        SELECT
            schemaname              AS esquema,
            relname               AS tabla,
            indexrelname               AS indice,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch
        FROM pg_stat_user_indexes
        WHERE schemaname IN ('ventas','rrhh')
        ORDER BY idx_scan DESC
    """, "pg_stat_user_indexes — uso de índices")

    run_query(cur, """
        SELECT
            left(query, 70)         AS consulta,
            calls,
            round(mean_exec_time::numeric, 2)   AS media_ms,
            round(max_exec_time::numeric, 2)    AS max_ms,
            round(total_exec_time::numeric, 2)  AS total_ms,
            rows
        FROM pg_stat_statements
        WHERE query NOT LIKE '%pg_stat%'
          AND calls > 0
        ORDER BY mean_exec_time DESC
        LIMIT 8
    """, "pg_stat_statements — consultas más lentas")

    run_query(cur, """
        SELECT
            name,
            setting,
            unit,
            context
        FROM pg_settings
        WHERE name IN (
            'shared_buffers','work_mem','maintenance_work_mem',
            'effective_cache_size','max_connections',
            'wal_level','max_wal_senders',
            'ssl','ssl_min_protocol_version'
        )
        ORDER BY name
    """, "pg_settings — parámetros clave del servidor")


def seccion_actividad(cur):
    header("4 · ACTIVIDAD, BLOQUEOS Y SESIONES")

    run_query(cur, """
        SELECT
            pid,
            usename                 AS usuario,
            application_name        AS aplicacion,
            client_addr             AS ip,
            state,
            wait_event_type,
            wait_event,
            round(EXTRACT(EPOCH FROM (now()-query_start))::numeric,1) AS duracion_s,
            left(query, 60)         AS consulta
        FROM pg_stat_activity
        WHERE pid <> pg_backend_pid()
        ORDER BY duracion_s DESC NULLS LAST
    """, "pg_stat_activity — sesiones activas")

    run_query(cur, """
        SELECT
            pid,
            locktype                AS tipo,
            relation::regclass      AS objeto,
            mode,
            granted,
            CASE granted WHEN true THEN 'obtenido' ELSE 'esperando' END AS estado
        FROM pg_locks
        WHERE pid <> pg_backend_pid()
          AND locktype != 'virtualxid'
        ORDER BY granted, locktype
        LIMIT 15
    """, "pg_locks — bloqueos activos (excluye esta sesión)")

    run_query(cur, """
        SELECT
            blocked.pid             AS pid_bloqueado,
            blocked.usename         AS usuario_bloqueado,
            blocking.pid            AS pid_bloqueador,
            blocking.usename        AS usuario_bloqueador,
            round(EXTRACT(EPOCH FROM (now()-blocked.query_start))::numeric,1) AS espera_s,
            left(blocked.query, 50) AS consulta_bloqueada
        FROM pg_stat_activity blocked
        JOIN pg_stat_activity blocking
            ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
        WHERE blocked.wait_event_type = 'Lock'
    """, "Cadena de bloqueos activos")

    run_query(cur, """
        SELECT
            pid,
            ssl,
            version     AS protocolo,
            cipher,
            bits,
            client_dn   AS cert_cliente
        FROM pg_stat_ssl
        WHERE ssl = true
        ORDER BY pid
    """, "pg_stat_ssl — conexiones SSL activas")

    run_query(cur, """
        SELECT
            pid,
            application_name,
            client_addr,
            state,
            sent_lsn,
            write_lsn,
            flush_lsn,
            replay_lsn,
            sync_state
        FROM pg_stat_replication
    """, "pg_stat_replication — réplicas conectadas")

    run_query(cur, """
        SELECT
            count(*)                                    AS total_sesiones,
            count(*) FILTER (WHERE state = 'active')    AS activas,
            count(*) FILTER (WHERE state = 'idle')      AS idle,
            count(*) FILTER (WHERE state LIKE 'idle in%') AS idle_en_tx,
            count(*) FILTER (WHERE wait_event_type='Lock') AS esperando_lock
        FROM pg_stat_activity
        WHERE pid <> pg_backend_pid()
    """, "Resumen de sesiones por estado")


def seccion_datos_prueba(cur):
    header("CONSULTAS SOBRE LAS TABLAS DE PRUEBA")

    run_query(cur, """
        SELECT
            p.id,
            c.nombre    AS cliente,
            pr.nombre   AS producto,
            p.cantidad,
            p.total,
            p.estado,
            p.fecha::TIMESTAMP(0)
        FROM ventas.pedidos p
        JOIN ventas.clientes c  ON c.id = p.cliente_id
        JOIN ventas.productos pr ON pr.id = p.producto_id
        ORDER BY p.fecha DESC
        LIMIT 10
    """, "Últimos 10 pedidos con detalle")

    run_query(cur, """
        SELECT
            c.segmento,
            count(p.id)                     AS num_pedidos,
            sum(p.total)                    AS importe_total,
            round(avg(p.total)::numeric, 2) AS ticket_medio
        FROM ventas.pedidos p
        JOIN ventas.clientes c ON c.id = p.cliente_id
        GROUP BY c.segmento
        ORDER BY importe_total DESC
    """, "Ventas por segmento de cliente")

    run_query(cur, """
        SELECT
            departamento,
            count(*)                        AS empleados,
            round(avg(salario)::numeric, 2) AS salario_medio,
            min(salario)                    AS salario_min,
            max(salario)                    AS salario_max
        FROM rrhh.empleados
        WHERE activo
        GROUP BY departamento
        ORDER BY salario_medio DESC
    """, "Estadísticas salariales por departamento")

    # Registrar el acceso en el log
    try:
        cur.execute("""
            INSERT INTO ventas.log_accesos (accion, tabla, ssl_usado)
            SELECT 'SELECT', 'ventas.pedidos', ssl
            FROM pg_stat_ssl
            WHERE pid = pg_backend_pid()
        """)
        ok("Acceso registrado en ventas.log_accesos")
    except Exception as e:
        warn(f"No se pudo registrar en log_accesos: {e}")


def parse_args():
    p = argparse.ArgumentParser(
        description="Ejecuta consultas de diagnóstico PostgreSQL con/sin cert cliente.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument("--host",        default="localhost")
    p.add_argument("--port",        type=int, default=5432)
    p.add_argument("--dbname",      default="testdb")
    p.add_argument("--user",        default="pguser")
    p.add_argument("--password",    default="")
    p.add_argument("--sslcert",     default="")
    p.add_argument("--sslkey",      default="")
    p.add_argument("--sslrootcert", default="")
    p.add_argument("--seccion",     default="todas",
        choices=["todas","ssl","catalog","objetos","estadisticas","actividad","datos"],
        help="Ejecutar solo una sección")
    return p.parse_args()


def main():
    args = parse_args()
    if not args.password:
        args.password = os.environ.get("PGPASSWORD", "")

    print(f"\n{BOLD}{'═'*62}{RESET}")
    print(f"{BOLD}  Test de consultas PostgreSQL — {args.host}:{args.port}/{args.dbname}{RESET}")
    print(f"{BOLD}{'═'*62}{RESET}")

    conn = connect(args)
    conn.autocommit = True

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        secciones = {
            "ssl":          seccion_ssl_info,
            "catalog":      seccion_pg_catalog,
            "objetos":      seccion_objetos,
            "estadisticas": seccion_estadisticas,
            "actividad":    seccion_actividad,
            "datos":        seccion_datos_prueba,
        }

        if args.seccion == "todas":
            for fn in secciones.values():
                fn(cur)
        else:
            secciones[args.seccion](cur)

    conn.close()
    print(f"\n{BOLD}{'═'*62}{RESET}")
    print(f"{GREEN}{BOLD}  Consultas completadas.{RESET}")
    print(f"{BOLD}{'═'*62}{RESET}\n")


if __name__ == "__main__":
    main()
