# ecommercedb — PostgreSQL de prueba con Docker Compose

Levanta un PostgreSQL 16 con una base de datos `ecommercedb` precargada con datos
de prueba (categorías, clientes, productos, pedidos y líneas de pedido), más
Adminer como interfaz web para explorar los datos sin instalar ningún cliente.

## Estructura

```
ecommerce-db/
├── docker-compose.yml
├── init/
│   └── 01-init.sql      # se ejecuta automáticamente la primera vez
└── README.md
```

## Arrancar

```bash
cd ecommerce-db
docker compose up -d
```

El script `init/01-init.sql` solo se ejecuta **la primera vez** que se crea el
volumen de datos (comportamiento estándar de la imagen oficial de Postgres).
Si necesitas reiniciar los datos desde cero:

```bash
docker compose down -v   # -v borra también el volumen con los datos
docker compose up -d
```

## Conexión

| Parámetro | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `5432` |
| Base de datos | `ecommercedb` |
| Usuario | `ecommerce_user` |
| Password | `ecommerce_pass` |

```bash
psql -h localhost -p 5432 -U ecommerce_user -d ecommercedb
```

Cadena de conexión JDBC:
```
jdbc:postgresql://localhost:5432/ecommercedb
```

## Adminer (interfaz web)

Disponible en [http://localhost:8081](http://localhost:8081)

- **Sistema:** PostgreSQL
- **Servidor:** `postgres`
- **Usuario:** `ecommerce_user`
- **Contraseña:** `ecommerce_pass`
- **Base de datos:** `ecommercedb`

## Esquema

| Tabla | Descripción |
|---|---|
| `categories` | Categorías de productos (5 filas) |
| `customers` | Clientes (10 filas) |
| `products` | Catálogo de productos (17 filas) |
| `orders` | Pedidos (10 filas, distintos estados) |
| `order_items` | Líneas de pedido (relación N:M entre orders y products) |

Relaciones:
```
categories 1──N products
customers  1──N orders
orders     1──N order_items N──1 products
```

## Comandos útiles

```bash
# Ver logs
docker compose logs -f postgres

# Entrar al contenedor y abrir psql
docker compose exec postgres psql -U ecommerce_user -d ecommercedb

# Parar sin borrar datos
docker compose stop

# Parar y eliminar contenedores (datos persisten en el volumen)
docker compose down

# Parar y eliminar todo incluyendo datos
docker compose down -v
```

## Consultas de ejemplo

```sql
-- Pedidos con total y nombre del cliente
SELECT o.id, c.first_name, c.last_name, o.status, o.total
FROM orders o JOIN customers c ON c.id = o.customer_id
ORDER BY o.order_date DESC;

-- Producto más vendido
SELECT p.name, SUM(oi.quantity) AS total_sold
FROM order_items oi JOIN products p ON p.id = oi.product_id
GROUP BY p.name
ORDER BY total_sold DESC;

-- Ingresos por categoría
SELECT cat.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p ON p.id = oi.product_id
JOIN categories cat ON cat.id = p.category_id
GROUP BY cat.name
ORDER BY revenue DESC;
```
