# Añadir el repositorio oficial de PostgreSQL (PGDG)
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list'

curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

# Instalar solo el cliente 17 (sin instalar el servidor)
sudo apt-get update
sudo apt-get install -y postgresql-client-17

# Verificar
psql --version
# → psql (PostgreSQL) 17.x