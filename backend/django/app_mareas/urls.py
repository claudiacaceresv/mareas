# ================================================================
# marea/urls.py ejemplo
#
# Propósito: mapear endpoints de la app "marea".
# ================================================================

"""
Enrutamiento de la app marea.
"""

from django.urls import path
from .views import ping, alturas, estaciones, actualizar_alturas

# ==========================
# URL patterns
# ==========================
urlpatterns = [
    # Verificar salud del servicio
    path("ping/", ping, name="ping"),

    # Obtener alturas cacheadas por estación
    path("alturas/<str:estacion_id>/",
         alturas.obtener_alturas_estacion, name="alturas_por_estacion"),

    # Listar estaciones disponibles
    path("estaciones/", estaciones.listar_estaciones, name="listar_estaciones"),

    # Actualizar y cachear datos de todas las estaciones
    path("actualizar-mareas/", actualizar_alturas.actualizar_mareas_view,
         name="actualizar_alturas"),
]
