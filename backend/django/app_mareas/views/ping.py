# ================================================================
# Endpoint Django ejemplo
#
# Propósito: responder un ping de salud del servicio.
#
# ================================================================

"""
Verificar salud del servicio.
"""

from django.http import JsonResponse

# ===============================
# Vista: ping
# ===============================


def ping(request):
    """Devolver estado OK en formato JSON."""
    return JsonResponse({"status": "ok"})
