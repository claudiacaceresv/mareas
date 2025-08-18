# ================================================================
# Django settings ejemplo
#
# Propósito: mostrar configuración del proyecto.
# Variables de entorno claves a definir antes de ejecutar:
#   - DJANGO_SECRET_KEY = <REEMPLAZAR: DJANGO_SECRET_KEY>
#   - DJANGO_DEBUG = true|false
#   - DJANGO_ALLOWED_HOSTS = dominio1,dominio2,localhost,127.0.0.1
#   - DB_NAME = <opcional>
#   - DB_USER = <opcional>
#   - DB_PASSWORD = <REEMPLAZAR: DB_PASSWORD>
#   - DB_HOST = <REEMPLAZAR: DB_HOST>
#   - DB_PORT = <REEMPLAZAR: DB_PORT>
# ================================================================

"""
Configuración Django – settings.py

"""

from pathlib import Path
import os

# ==============================
# Rutas base
# ==============================
# Definir directorio base del proyecto
BASE_DIR = Path(__file__).resolve().parent.parent

# ==============================
# Utilidades de entorno
# ==============================
# Leer booleanos y listas desde variables de entorno


def _get_bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


def _get_list(name: str, default=None):
    v = os.getenv(name)
    if v:
        return [s.strip() for s in v.split(",") if s.strip()]
    return default or []


# ==============================
# Seguridad y modo
# ==============================
# Configurar clave secreta y DEBUG desde entorno con mismos valores por defecto
SECRET_KEY = os.getenv(
    "DJANGO_SECRET_KEY", "<REEMPLAZAR: DJANGO_SECRET_KEY>"
)
DEBUG = _get_bool("DJANGO_DEBUG", True)

# Definir hosts permitidos (mantener lista original por defecto)
ALLOWED_HOSTS = _get_list(
    "DJANGO_ALLOWED_HOSTS",
    ["<REEMPLAZAR: DOMINIO_PRODUCCION_1>",
        "<REEMPLAZAR: DOMINIO_PRODUCCION_2>", "localhost", "127.0.0.1"],
)

# Confiar en cabecera de proxy y decidir redirección a HTTPS solo en producción
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = False if DEBUG else True

# ==============================
# Aplicaciones instaladas
# ==============================
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # apps propias
    "app_mareas",
    # apps terceros
    "corsheaders",
]

# ==============================
# Middleware
# ==============================
MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

# ==============================
# URLs y templates
# ==============================
ROOT_URLCONF = "mareas.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],  # agregar rutas si corresponde
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "mareas.wsgi.application"

# ==============================
# Base de datos
# ==============================
# Mantener PostgreSQL y credenciales por defecto actuales; permitir override por entorno
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.getenv("DB_NAME", "railway"),
        "USER": os.getenv("DB_USER", "postgres"),
        "PASSWORD": os.getenv("DB_PASSWORD", "<REEMPLAZAR: DB_PASSWORD>"),
        "HOST": os.getenv("DB_HOST", "<REEMPLAZAR: DB_HOST>"),
        "PORT": os.getenv("DB_PORT", "<REEMPLAZAR: DB_PORT>"),
        # mantener conexiones
        "CONN_MAX_AGE": int(os.getenv("DB_CONN_MAX_AGE", "60")),
        # usar "require" si el proveedor lo exige
        "OPTIONS": {"sslmode": os.getenv("DB_SSLMODE", "prefer")},
    }
}

# ==============================
# Validación de contraseñas
# ==============================
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ==============================
# Internacionalización
# ==============================
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# ==============================
# Archivos estáticos
# ==============================
STATIC_URL = "static/"
STATIC_ROOT = os.path.join(BASE_DIR, "staticfiles")

# ==============================
# CORS
# ==============================
# Mantener configuración original orientada a desarrollo
CORS_ALLOW_ALL_ORIGINS = _get_bool("CORS_ALLOW_ALL_ORIGINS", True)
CORS_ALLOW_CREDENTIALS = _get_bool("CORS_ALLOW_CREDENTIALS", True)

# ==============================
# Varios
# ==============================
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
FORCE_DEPLOY = _get_bool("FORCE_DEPLOY", True)
