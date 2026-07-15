#!/bin/bash
# =============================================================
# notify_event.sh
# Recibe eventos de repmgr y los registra con formato legible
#
# Parámetros: node_id event success timestamp detail
# =============================================================
NODE_ID="${1:-?}"
EVENT="${2:-unknown}"
SUCCESS="${3:-0}"
TIMESTAMP="${4:-$(date)}"
DETAIL="${5:-sin detalle}"

LOG="/var/log/repmgr/events.log"
mkdir -p "$(dirname "$LOG")"

# Emoji según el tipo de evento
case "$EVENT" in
    repmgrd_failover_promote|standby_promote)
        ICON="🔴 FAILOVER"
        ;;
    repmgrd_upstream_reconnect|standby_register)
        ICON="🟢 RECOVERY"
        ;;
    primary_register)
        ICON="🟢 INIT"
        ;;
    repmgrd_reload|repmgrd_start)
        ICON="🔵 DAEMON"
        ;;
    *)
        ICON="ℹ️  INFO"
        ;;
esac

[ "$SUCCESS" = "1" ] && STATUS="OK" || STATUS="FAIL"

MSG="[$TIMESTAMP] $ICON | Nodo=$NODE_ID Evento=$EVENT Status=$STATUS | $DETAIL"

echo "$MSG" | tee -a "$LOG"
echo "$MSG" >&2   # También a stderr para que aparezca en docker logs
