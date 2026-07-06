import os

# ── Seguridad ────────────────────────────────────────────────────────────────
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "cambia_esto")

# ── Metastore de Superset (usa la BD compartida, schema propio) ──────────────
# Dentro de Docker los contenedores se hablan por nombre de servicio y puerto interno
SQLALCHEMY_DATABASE_URI = (
    "postgresql+psycopg2://analytics:analytics_pass@db:5432/analytics"
)

# ── Redis ────────────────────────────────────────────────────────────────────
CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_URL": "redis://redis:6379/0",
}

CELERY_CONFIG = {
    "broker_url": "redis://redis:6379/1",
    "result_backend": "redis://redis:6379/2",
}

# ── Seguridad web ────────────────────────────────────────────────────────────
WTF_CSRF_ENABLED = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
