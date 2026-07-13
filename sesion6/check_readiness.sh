#!/bin/bash
# Script automatizado para la Readiness Probe del Nodo Primario (Escrituras)

IS_IN_RECOVERY=$(psql -U ecommerce_user -h localhost -d ecommercedb -t -A -c "SELECT pg_is_in_recovery();")

if [ "$IS_IN_RECOVERY" = "f" ]; then
    # El nodo es el Primario/Master, está listo para recibir lecturas y escrituras.
    echo "OK"
else
    # El nodo está en modo réplica (Solo Lectura) o recuperándose.
    echo "NO_OK"
fi
