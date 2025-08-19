# ================================================================
# Endpoint Django ejemplo
#
# Propósito: exponer JSON cacheado de alturas de marea por estación.
#
# Entradas/supuestos:
#   - Archivos generados por un job previo en:
#       * Producción (Railway): /app/marea/cache/marea_<estacion_id>.json
#       * Desarrollo local:     <repo>/marea/cache/marea_<estacion_id>.json
# ================================================================

"""
Exponer alturas de marea cacheadas por estación.
"""

from django.http import JsonResponse
import os
from pathlib import Path
import json

# ===============================
# Vista: obtener alturas por estación
# ===============================


def obtener_alturas_estacion(request, estacion_id):
    """
    Devolver JSON de alturas para la estación indicada.
    Ejemplo: /marea/alturas/san_fernando/
    """
    try:
        # Determinar directorio de cache según entorno
        if os.environ.get("RAILWAY_ENVIRONMENT"):
            # Producción (Railway)
            cache_dir = Path("/app/marea/cache")
        else:
            cache_dir = Path(__file__).resolve(
            ).parents[2] / "marea" / "cache"  # Desarrollo local

        # Construir ruta del archivo de la estación
        archivo = cache_dir / f"marea_{estacion_id}.json"

        # Validar existencia del archivo
        if not archivo.exists():
            return JsonResponse({"error": f"Archivo no encontrado para estación {estacion_id}"}, status=404)

        # Leer y devolver contenido JSON
        with open(archivo, "r", encoding="utf-8") as f:
            datos = json.load(f)
            return JsonResponse(datos, safe=False)

    except Exception as e:
        # Responder error genérico controlado
        return JsonResponse({"error": f"Error al cargar datos: {str(e)}"}, status=500)
