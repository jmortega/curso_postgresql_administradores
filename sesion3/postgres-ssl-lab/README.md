# PostgreSQL 16 + SSL — Lab completo

> Despliega PostgreSQL con SSL completo en Docker y prueba todos los modos de conexión (`disable` → `verify-full`) con el script Python incluido.

---

## Estructura del proyecto

```
postgres-ssl-lab/
├── generar_certs.sh          ← Paso 1: genera todos los certificados
├── docker-compose.yml        ← Paso 2: levanta PostgreSQL con SSL
├── entrypoint.sh             ← Configura SSL y arranca postgres
├── test_postgres_ssl.py      ← Paso 3: prueba los 6 modos SSL
├── config/
│   └── pg_hba.conf           ← Reglas de autenticación
└── certs/                    ← Generado por generar_certs.sh
    ├── ca/
    │   ├── ca.key            ← Clave privada CA (proteger siempre)
    │   └── ca.crt            ← Certificado público CA
    ├── server/
    │   ├── server.key        ← Clave privada del servidor
    │   └── server.crt        ← Certificado del servidor (firmado por CA)
    └── client/
        ├── client.key        ← Clave privada del cliente
        └── client.crt        ← Certificado del cliente (firmado por CA)
```

---

## Prerequisitos

```bash
# Verificar que tienes las herramientas necesarias
openssl version      # OpenSSL 1.1+ o 3.x
docker --version     # Docker 20+
docker compose version
python3 --version    # Python 3.8+
pip install psycopg2-binary
```

---

## Paso 1 — Generar los certificados SSL

El script `generar_certs.sh` crea automáticamente:
- Una **CA autofirmada** (válida 10 años)
- El **certificado del servidor** con SAN para `localhost` e IP `127.0.0.1`
- El **certificado del cliente** con CN=`pguser` (el usuario de PostgreSQL)

```bash
chmod +x generar_certs.sh
./generar_certs.sh
```

Salida esperada:
```
▸ 1/3 Generando CA autofirmada...
✓ CA generada → certs/ca/ca.crt
▸ 2/3 Generando certificado del servidor (CN=localhost)...
✓ Certificado servidor → certs/server/server.crt
▸ 3/3 Generando certificado del cliente (CN=pguser)...
✓ Certificado cliente → certs/client/client.crt

Verificación de cadena de confianza:
  Servidor: certs/server/server.crt: OK
  Cliente:  certs/client/client.crt: OK
```

> Si necesitas regenerar desde cero: `./generar_certs.sh --clean`

### ¿Por qué tres certificados?

| Certificado | Quién lo usa | Para qué |
|---|---|---|
| `ca.crt` | Servidor y cliente | Verificar que el otro extremo es de confianza |
| `server.crt` | PostgreSQL | Identificarse ante los clientes |
| `client.crt` | psycopg2/psql | Identificarse ante el servidor (modos `verify-ca`/`verify-full`) |

### 1.1 Autoridad Certificadora (CA)

La CA firma todos los certificados. Su clave privada debe estar muy protegida.

```bash
# 1. Generar la clave privada de la CA (4096 bits, cifrada con AES-256)
openssl genrsa -aes256 -out certs/ca/ca.key 4096

# 2. Generar el certificado autofirmado de la CA (válido 10 años)
openssl req -new -x509 \
  -days 3650 \
  -key certs/ca/ca.key \
  -out certs/ca/ca.crt \
  -subj "/C=ES/ST=Madrid/L=Madrid/O=MiEmpresa/OU=DBA/CN=PostgreSQL-CA"

# 3. Verificar el certificado
openssl x509 -in certs/ca/ca.crt -text -noout | grep -E "Subject:|Issuer:|Not"
```

Proteger la clave de la CA:

```bash
chmod 400 certs/ca/ca.key
chmod 444 certs/ca/ca.crt
```

---

### 1.2 Certificado del servidor

El `CN` (Common Name) **debe coincidir** con el hostname o IP del servidor PostgreSQL. Para `verify-full`, el cliente comprueba este campo.

```bash
# Variables — ajustar a tu entorno
SERVER_HOST="postgres.miempresa.com"   # FQDN o IP del servidor
DAYS=825                               # Máximo recomendado por navegadores modernos

# 1. Generar la clave privada del servidor (sin contraseña para que PostgreSQL
#    pueda arrancar automáticamente)
openssl genrsa -out certs/server/server.key 4096

# 2. Crear la solicitud de firma (CSR)
openssl req -new \
  -key certs/server/server.key \
  -out certs/server/server.csr \
  -subj "/C=ES/ST=Madrid/L=Madrid/O=MiEmpresa/OU=DBA/CN=${SERVER_HOST}"

# 3. Crear fichero de extensiones para SAN (Subject Alternative Names)
#    Esto permite que funcione con verify-full usando IP o FQDN
cat > certs/server/server_ext.cnf <<EOF
[req]
req_extensions = v3_req
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${SERVER_HOST}
DNS.2 = localhost
IP.1  = 127.0.0.1
# Añadir más DNS o IP si el servidor tiene varios nombres
EOF

# 4. Firmar el certificado del servidor con la CA
openssl x509 -req \
  -days ${DAYS} \
  -in  certs/server/server.csr \
  -CA  certs/ca/ca.crt \
  -CAkey certs/ca/ca.key \
  -CAcreateserial \
  -out certs/server/server.crt \
  -extensions v3_req \
  -extfile certs/server/server_ext.cnf

# 5. Verificar la cadena de confianza
openssl verify -CAfile certs/ca/ca.crt certs/server/server.crt

# 6. Permisos — PostgreSQL exige que la clave sea propiedad del usuario postgres
#    y no legible por otros
chmod 600 certs/server/server.key
chmod 644 certs/server/server.crt

# En sistemas Linux, si PostgreSQL corre como usuario 'postgres':
chown postgres:postgres certs/server/server.key certs/server/server.crt
```

---

### 1.3 Certificado del cliente

El `CN` del certificado cliente debe coincidir con el **nombre de usuario de PostgreSQL** cuando se usa autenticación `cert` en `pg_hba.conf`.

```bash
# Variables
PG_USER="mi_usuario"    # Usuario de PostgreSQL al que mapear
DAYS=365

# 1. Generar la clave privada del cliente
openssl genrsa -out certs/client/client.key 4096

# 2. Crear la solicitud de firma (CSR)
#    El CN debe ser el nombre de usuario de PostgreSQL
openssl req -new \
  -key certs/client/client.key \
  -out certs/client/client.csr \
  -subj "/C=ES/ST=Madrid/L=Madrid/O=MiEmpresa/OU=Aplicacion/CN=${PG_USER}"

# 3. Firmar el certificado del cliente con la CA
openssl x509 -req \
  -days ${DAYS} \
  -in  certs/client/client.csr \
  -CA  certs/ca/ca.crt \
  -CAkey certs/ca/ca.key \
  -CAcreateserial \
  -out certs/client/client.crt

# 4. Verificar la cadena de confianza
openssl verify -CAfile certs/ca/ca.crt certs/client/client.crt

# 5. Permisos — psycopg2 requiere permisos 600 en la clave cliente
chmod 600 certs/client/client.key
chmod 644 certs/client/client.crt
```
---

## Paso 2 — Levantar PostgreSQL con SSL

```bash
chmod +x entrypoint.sh
docker compose up -d
```

Verificar que arrancó correctamente:

```bash
# Estado del contenedor
docker compose ps

# Ver que SSL está activo
docker exec postgres-ssl psql -U postgres -c "SHOW ssl;"
#  ssl
# -----
#  on

# Ver protocolo y cipher activos
docker exec postgres-ssl psql -U postgres \
    -c "SELECT pid, ssl, version, cipher, bits FROM pg_stat_ssl WHERE ssl = true;"
```

### ¿Qué hace el entrypoint?

1. Copia los certificados a `/tmp/` y les asigna permisos `600` (requerido por PostgreSQL)
2. Inicializa `PGDATA` si el volumen está vacío (`initdb`)
3. Escribe la configuración SSL en `postgresql.auto.conf`
4. Aplica `pg_hba.conf` con las reglas de autenticación
5. Crea el usuario `pguser` y la base de datos `testdb`
6. Arranca PostgreSQL como proceso principal

### Configuración SSL aplicada

```ini
ssl                       = on
ssl_cert_file             = '/tmp/server.crt'
ssl_key_file              = '/tmp/server.key'
ssl_ca_file               = '/tmp/ca.crt'
ssl_min_protocol_version  = 'TLSv1.2'
ssl_ciphers               = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = on
```

### Reglas pg_hba.conf

```
# Socket local → siempre permitido (administración interna)
local   all   all                trust

# localhost → scram-sha-256 (permite todos los modos SSL para el lab)
host    all   all  127.0.0.1/32  scram-sha-256

# Red → SOLO SSL obligatorio
hostssl    all  all  0.0.0.0/0   scram-sha-256

# Red sin SSL → rechazado explícitamente
hostnossl  all  all  0.0.0.0/0   reject
```

> La línea `hostnossl reject` garantiza que cualquier intento de conexión sin cifrado desde la red sea rechazado, incluso si el cliente solicita `sslmode=disable`.

# Ver dónde está el postgresql.conf dentro del contenedor
docker exec postgres-ssl psql -U postgres -c "SHOW config_file;"

# Ver todos los parámetros SSL activos
docker exec postgres-ssl psql -U postgres -c "
SELECT name, setting, source
FROM pg_settings
WHERE name LIKE 'ssl%'
ORDER BY name;"

# Ver si SSL está on
docker exec postgres-ssl psql -U postgres -c "SHOW ssl;"

# Ver los ficheros de certificados configurados
docker exec postgres-ssl psql -U postgres -c "
SELECT name, setting FROM pg_settings
WHERE name IN (
    'ssl',
    'ssl_cert_file',
    'ssl_key_file',
    'ssl_ca_file',
    'ssl_min_protocol_version',
    'ssl_ciphers',
    'ssl_prefer_server_ciphers'
)
ORDER BY name;"

# Ver el contenido real del postgresql.auto.conf (donde escribimos la config SSL)
docker exec postgres-ssl cat /var/lib/postgresql/data/postgresql.auto.conf

# Ver el pg_hba.conf activo
docker exec postgres-ssl cat /var/lib/postgresql/data/pg_hba.conf

# Ver parámetros que requieren reinicio para aplicarse (pending_restart)
docker exec postgres-ssl psql -U postgres -c "
SELECT name, setting, pending_restart
FROM pg_settings
WHERE pending_restart = true;"

# Verificar que el certificado del servidor que usa PG es el que generamos
# El cert está montado en el contenedor pero también accesible desde el host
# en la ruta que definiste en docker-compose.yml
openssl x509 -in certs/server/server.crt -noout -subject -enddate

# Comparar fingerprint del cert local con el que usa el contenedor
openssl x509 -in certs/server/server.crt -noout -fingerprint -sha256

# Comparar fingerprint del cert montado vs el que reporta pg_stat_ssl
docker exec postgres-ssl psql -U postgres -c "
SELECT ssl, version, cipher, bits, client_dn
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();"
---

## Instalación del script Python

```bash
# Crear entorno virtual (recomendado)
python3 -m venv venv
source venv/bin/activate

# Instalar dependencia
pip install psycopg2-binary

# Dar permisos de ejecución al script
chmod +x test_postgres_ssl.py
```

## Paso 3 — Ejecutar el script de pruebas SSL

### Prueba básica (modos `disable` → `require`)

```bash
python3 test_postgres_ssl.py \
    --host localhost \
    --port 5432 \
    --dbname testdb \
    --user pguser \
    --password pgpassword
```

**Resultado esperado:**
- `disable` → **FAIL** (rechazado por `hostnossl reject` en pg_hba.conf)
- `allow` → **OK** (Seguridad baja)
- `prefer` → **OK** (negocia SSL automáticamente)
- `require` → **OK** (SSL sin verificar cert del servidor)

### Prueba completa con certificados (`verify-ca` y `verify-full`)

```bash
python3 test_postgres_ssl.py \
    --host localhost \
    --port 5432 \
    --dbname testdb \
    --user pguser \
    --password pgpassword \
    --sslcert     certs/client/client.crt \
    --sslkey      certs/client/client.key \
    --sslrootcert certs/ca/ca.crt
```

**Resultado esperado (todos los modos con certificados):**
- `disable` → **FAIL** (rechazado por pg_hba)
- `allow` → **OK** (Seguridad baja)
- `prefer` → **OK** — TLSv1.3
- `require` → **OK** — TLSv1.3
- `verify-ca` → **OK** — TLSv1.3 (verifica que el cert está firmado por nuestra CA)
- `verify-full` → **OK** — TLSv1.3 (verifica CA + que el hostname coincide con el SAN del cert)

### Probar un solo modo con informe detallado

```bash
python3 test_postgres_ssl.py \
    --host localhost \
    --mode verify-full \
    --dbname testdb \
    --user pguser \
    --password pgpassword \
    --sslcert     certs/client/client.crt \
    --sslkey      certs/client/client.key \
    --sslrootcert certs/ca/ca.crt \
    --verbose
```

---

## Por qué `disable` falla

La configuración `pg_hba.conf` del laboratorio usa `hostnossl reject`, lo que hace que el servidor rechace cualquier conexión de red sin cifrar antes de llegar a la autenticación. Esto es el comportamiento correcto en producción.

Si quisieras probar los modos `disable`/`allow` de todas formas, tendrías que conectarte desde dentro del mismo contenedor (conexión local por socket Unix, que usa la regla `local trust`):

```bash
# Conexión local por socket — evita pg_hba de red
docker exec postgres-ssl psql -U pguser -d testdb -c "SELECT version();"
```

---

## Referencia de comandos de verificación

### Inspeccionar contenido de certificados

```bash
# Ver todos los campos del certificado de la CA
openssl x509 -in certs/ca/ca.crt -text -noout

# Ver subject, issuer y fechas de validez del servidor
openssl x509 -in certs/server/server.crt -noout \
  -subject -issuer -startdate -enddate

# Ver Subject Alternative Names (SAN) — necesario para verify-full
openssl x509 -in certs/server/server.crt -noout -ext subjectAltName

# Ver el CN del certificado de cliente (debe coincidir con usuario PG)
openssl x509 -in certs/client/client.crt -noout \
  -subject -issuer -enddate
```

### Fechas de validez y expiración

```bash
# Fecha de expiración de los tres certificados de un vistazo
for f in certs/ca/ca.crt certs/server/server.crt certs/client/client.crt; do
  echo -n "$f → "; openssl x509 -in $f -noout -enddate
done

# Alerta si el servidor expira en menos de 30 días (útil en scripts de monitorización)
openssl x509 -in certs/server/server.crt -noout -checkend 2592000 \
  && echo "OK — no expira en 30 días" \
  || echo "⚠ EXPIRA en menos de 30 días"

# Calcular días exactos hasta expiración
expiry=$(openssl x509 -in certs/server/server.crt -noout -enddate | cut -d= -f2)
echo "Expira: $expiry"
python3 -c "
from datetime import datetime
exp = datetime.strptime('$expiry', '%b %d %H:%M:%S %Y %Z')
print(f'Días restantes: {(exp - datetime.utcnow()).days}')
"
```

### Verificar cadena de confianza

```bash
# Verificar que el cert del servidor está firmado por la CA
openssl verify -CAfile certs/ca/ca.crt certs/server/server.crt

# Verificar que el cert del cliente está firmado por la CA
openssl verify -CAfile certs/ca/ca.crt certs/client/client.crt

# Verificar que la clave privada corresponde al certificado del servidor
diff \
  <(openssl x509 -in certs/server/server.crt -noout -modulus | md5sum) \
  <(openssl rsa  -in certs/server/server.key -noout -modulus | md5sum) \
  && echo "✓ Clave y certificado coinciden" \
  || echo "✗ No coinciden — regenerar"
```

### Probar la conexión SSL en vivo

```bash
# Simular handshake SSL contra el servidor PostgreSQL
openssl s_client -connect localhost:5432 -starttls postgres \
  -CAfile certs/ca/ca.crt \
  -showcerts 2>/dev/null | grep -E "subject|issuer|Verify|Protocol|Cipher"

# Ver protocolo TLS y cipher negociado en la conexión
openssl s_client -connect localhost:5432 -starttls postgres \
  -CAfile certs/ca/ca.crt 2>/dev/null \
  | grep -E "Protocol|Cipher|Verify return"

# Forzar TLSv1.2 y ver si el servidor lo acepta
openssl s_client -connect localhost:5432 -starttls postgres \
  -tls1_2 -CAfile certs/ca/ca.crt 2>&1 | head -20
```

### Verificar desde PostgreSQL

```bash
# Ver si SSL está activo en el servidor
docker exec postgres-ssl psql -U postgres -c "SHOW ssl;"

# Ver protocolo, cipher y bits de todas las conexiones SSL activas
docker exec postgres-ssl psql -U postgres -c "
SELECT pid, ssl, version AS tls_version, cipher, bits
FROM pg_stat_ssl
WHERE ssl = true;"

# Ver qué usuario y cliente usa cada conexión SSL
docker exec postgres-ssl psql -U postgres -c "
SELECT a.pid, a.usename, a.client_addr,
       s.ssl, s.version, s.cipher, s.bits
FROM pg_stat_activity a
JOIN pg_stat_ssl s USING (pid)
WHERE a.pid <> pg_backend_pid()
ORDER BY s.ssl DESC;"

# Ver rutas de certificados configuradas en el servidor
docker exec postgres-ssl psql -U postgres -c "
SELECT name, setting FROM pg_settings
WHERE name LIKE 'ssl%'
ORDER BY name;"

# Ver el estado de la conexión desde el cliente psql
psql "host=localhost port=5432 dbname=testdb user=pguser \
  sslmode=verify-full \
  sslrootcert=certs/ca/ca.crt \
  sslcert=certs/client/client.crt \
  sslkey=certs/client/client.key" \
  -c "\conninfo"
```

### Resumen compacto de los tres certificados

```bash
# Imprimir subject, issuer, fechas y fingerprint SHA-256 de cada cert
for label in "CA" "Servidor" "Cliente"; do
  case $label in
    CA)       f=certs/ca/ca.crt ;;
    Servidor) f=certs/server/server.crt ;;
    Cliente)  f=certs/client/client.crt ;;
  esac
  echo "── $label ($f) ──"
  openssl x509 -in $f -noout \
    -subject -issuer -startdate -enddate \
    -fingerprint -sha256
  echo ""
done

# Fingerprint SHA-256 del servidor (para comparar con lo que reporta el cliente)
openssl x509 -in certs/server/server.crt -noout -fingerprint -sha256
```


## Recomendaciones de seguridad en producción

### Lista de comprobación

- [ ] `ssl = on` en `postgresql.conf`
- [ ] `ssl_min_protocol_version = 'TLSv1.2'` (preferir `TLSv1.3`)
- [ ] Certificados firmados por CA propia o de confianza (no autofirmados directamente)
- [ ] Claves privadas con permisos `600` y propiedad del usuario `postgres`
- [ ] `pg_hba.conf` usa `hostssl` en lugar de `host` para conexiones de red
- [ ] `hostnossl` con `reject` para bloquear conexiones no cifradas desde red
- [ ] Método `scram-sha-256` en lugar de `md5`
- [ ] `clientcert=verify-full` para aplicaciones críticas
- [ ] Certificados con fecha de expiración monitorizados (alertas con 30 días de antelación)
- [ ] Rotación de certificados documentada y probada
- [ ] `disable`, `allow` y `prefer` bloqueados a nivel de firewall o `pg_hba.conf` en producción

### Monitorización de conexiones SSL

```sql
-- Ver qué conexiones activas usan SSL y qué protocolo/cipher
$ docker exec postgres-ssl psql -U postgres -c "SELECT
    pid,
    usename,
    application_name,
    client_addr,
    ssl,
    version   AS tls_version,
    cipher,
    bits      AS key_bits
FROM pg_stat_activity a
JOIN pg_stat_ssl s USING (pid)
WHERE a.pid <> pg_backend_pid()
ORDER BY ssl DESC, usename;"

 pid  | usename  | application_name | client_addr | ssl | tls_version |         cipher         | key_bits 
------+----------+------------------+-------------+-----+-------------+------------------------+----------
 1264 | pguser   | psql             | 172.27.0.1  | t   | TLSv1.3     | TLS_AES_256_GCM_SHA384 |      256
 1569 | postgres | psql             | 172.27.0.1  | t   | TLSv1.3     | TLS_AES_256_GCM_SHA384 |      256
(2 rows)


### Gestión del contenedor

```bash
# Ver logs del contenedor
docker logs postgres-ssl --tail 30

# Parar y destruir todo (incluyendo volumen de datos)
docker compose down -v
```

---

## Credenciales

| Parámetro | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `5432` |
| Base de datos | `testdb` |
| Usuario | `pguser` |
| Contraseña | `pgpassword` |
| CN certificado cliente | `pguser` |
