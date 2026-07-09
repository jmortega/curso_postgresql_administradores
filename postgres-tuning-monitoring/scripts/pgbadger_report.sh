#!/bin/bash
# =============================================================
# pgbadger_report.sh
# Genera un reporte HTML de pgBadger a partir de los logs de
# PostgreSQL (requiere logging_collector=on y log_directory
# montado en /var/log/postgresql, ver docker-compose.yml).
#
# Uso dentro del contenedor:
#   docker exec -it postgres /scripts/pgbadger_report.sh
# =============================================================
set -euo pipefail

LOG_DIR="/var/log/postgresql"
OUT_DIR="/pgbadger_reports"
STAMP="$(date '+%Y%m%d_%H%M%S')"

mkdir -p "$OUT_DIR"

if ! ls "$LOG_DIR"/*.log >/dev/null 2>&1; then
    echo "No se encontraron logs en $LOG_DIR."
    echo "Verifica que postgresql.conf tenga logging_collector=on y log_directory=/var/log/postgresql"
    exit 1
fi

pgbadger "$LOG_DIR"/*.log -o "$OUT_DIR/report_${STAMP}.html"

echo "Reporte generado: $OUT_DIR/report_${STAMP}.html"
echo "Cópialo al host con:"
echo "  docker cp postgres:$OUT_DIR/report_${STAMP}.html ./report_${STAMP}.html"
