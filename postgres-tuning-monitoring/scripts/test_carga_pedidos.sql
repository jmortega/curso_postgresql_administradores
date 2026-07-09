-- test_carga_pedidos.sql
-- Script de pgbench para simular tráfico de lectura concurrente
-- sobre la tabla pedidos, usado en la sección de pruebas de carga.
--
-- Uso:
--   docker exec -it postgres pgbench -c 50 -j 4 -T 120 \
--       -f /scripts/test_carga_pedidos.sql -U pguser appdb

\set cliente_id random(1, 100000)

SELECT * FROM pedidos WHERE cliente_id = :cliente_id ORDER BY fecha_creacion DESC LIMIT 10;
