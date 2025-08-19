# ================================================================
# Endpoint Django ejemplo
#
# Propósito: devolver el contenido estático de estaciones.json.
#
# Supuestos:
#   - Archivo en: <BASE_DIR>/marea/scripts/data/estaciones.json
# ================================================================

"""
Listar estaciones de medición desde el archivo estático.
"""

from django.conf import settings
from django.http import JsonResponse
from pathlib import Path
import json

# ===============================
# Vista: listar todas las estaciones
# ===============================


def listar_estaciones(request):
    """
    Devolver contenido de estaciones.json.
    Ruta: /marea/estaciones/
    """
    try:
        # Construir ruta absoluta a estaciones.json
        archivo = Path(settings.BASE_DIR) / "marea" / \
            "scripts" / "data" / "estaciones.json"

        # Validar existencia
        if not archivo.exists():
            return JsonResponse({"error": "Archivo estaciones.json no encontrado"}, status=404)

        # Leer y devolver JSON
        with open(archivo, "r", encoding="utf-8") as f:
            data = json.load(f)
            return JsonResponse(data, safe=False)

    except Exception as e:
        # Responder error controlado
        return JsonResponse({"error": f"Error al leer estaciones.json: {str(e)}"}, status=500)
