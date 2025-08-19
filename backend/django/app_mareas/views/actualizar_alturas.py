# ================================================================
# Endpoint Django ejemplo
#
# Propósito: expone un endpoint protegido por token para actualizar y
#            cachear alturas de marea por estación.
#
# Autenticación:
#   - Header:  Authorization: Bearer <REEMPLAZAR: MAREA_JOB_TOKEN>
#   - Alternativas (solo si su caso lo requiere): ?token=<...> o body form 'token'
# ================================================================

"""
Endpoint para actualizar y cachear alturas de marea por estación.
"""

import os
import hmac
import logging
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from app_mareas.scripts.jobs.actualizacion import actualizar_datos_marea, ESTACIONES

logger = logging.getLogger(__name__)

# ---------------- Utilidades ----------------


def _extraer_token(request) -> str:
    """Extraer token desde Authorization: Bearer <token> o query/body 'token'."""
    auth = request.META.get("HTTP_AUTHORIZATION", "")
    if auth.startswith("Bearer "):
        return auth[7:].strip()
    return request.GET.get("token") or request.POST.get("token") or ""


def _token_valido(provisto: str, esperado: str) -> bool:
    """Comparar tokens con tiempo constante."""
    return bool(esperado) and hmac.compare_digest(provisto, esperado)

# ---------------- Vista ----------------


@csrf_exempt
@require_http_methods(["GET", "POST"])
def actualizar_mareas_view(request):
    """Actualizar todas las estaciones y devolver resumen JSON."""
    esperado = os.getenv("MAREA_JOB_TOKEN", "")
    provisto = _extraer_token(request)

    if not _token_valido(provisto, esperado):
        return JsonResponse({"error": "Unauthorized"}, status=401)

    ok, errores = [], []
    for est, config in ESTACIONES.items():
        try:
            actualizar_datos_marea(
                est, config["series_id"], config["site_code"], config["cal_id"])
            ok.append(est)
        except Exception as e:
            logger.exception("Error actualizando estación %s", est)
            errores.append({"estacion": est, "error": str(e)})

    status = 200 if not errores else 200  # mantener 200 y reportar parcial
    return JsonResponse({"ok": ok, "errores": errores}, status=status)
