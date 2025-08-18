# ================================================================
# Django urls.py ejemplo
#
# Propósito: exponer panel de administración y enrutar endpoints de la app "marea".
# ================================================================

"""
Enrutamiento principal del proyecto Django.
"""

from django.contrib import admin
from django.urls import path, include

# ==========================
# URL patterns
# ==========================
urlpatterns = [
    # Exponer panel de administración
    path("admin/", admin.site.urls),

    # Montar endpoints del dominio de marea
    # Ejemplo: /marea/alturas/<estacion>/
    path("marea/", include("marea.urls")),
]
