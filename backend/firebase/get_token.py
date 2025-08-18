# ================================================================
# Ejemplo: Enviar una notificación FCM a un topic con Firebase Admin
#
# Para lectores:
# - Propósito: script mínimo que publica una notificación FCM a un topic.
# - Requisitos:
#   * Python 3.10+
#   * Paquete: firebase-admin
#   * Un Service Account JSON de un proyecto Firebase con FCM habilitado.
# - Configuración (variables de entorno):
#   * GOOGLE_APPLICATION_CREDENTIALS: ruta absoluta al JSON del Service Account
#       Ej.: /ruta/al/archivo.json  |  Placeholder: <REEMPLAZAR: RUTA_SERVICE_ACCOUNT_JSON>
#   * FCM_TOPIC: topic destino (por defecto "free").
#   * FCM_TIPO: clave de notificación a usar desde `notificaciones_free`
#       (por defecto "actualizacion").
# - Ejecución:
#   python get_token.py
# - Seguridad:
#   Use variables de entorno o un gestor de secretos para inyectar la ruta.
# ================================================================

"""
Enviar una notificación FCM al topic indicado.
"""

import os
import firebase_admin
from firebase_admin import credentials, messaging


# ---------------- Credenciales ----------------
# Leer ruta del service account desde GOOGLE_APPLICATION_CREDENTIALS
# Fallback: usar placeholder para repositorio público
CRED_PATH = os.getenv(
    "GOOGLE_APPLICATION_CREDENTIALS",
    # Ruta local al JSON del Service Account
    "<REEMPLAZAR: RUTA_SERVICE_ACCOUNT_JSON>",
)
cred = credentials.Certificate(CRED_PATH)

# Inicializar app Firebase si no existe
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)


# ---------------- Parámetros ----------------
# Mantener defaults actuales y permitir override por entorno
topic = os.getenv("FCM_TOPIC", "free")  # Ej.: "free" o el topic que use su app
# Debe existir en `notificaciones_free`
tipo_notificacion = os.getenv("FCM_TIPO", "actualizacion")

notificaciones_free = {
    "actualizacion": {
        "titulo": "Mareas se actualizó",
        "cuerpo": "📍 Nuevas estaciones! Zárate y San Fernando",
        "url": "https://play.google.com/store/apps/details?id=com.appmareas.app_mareas",
    },
    "promocion": {
        "titulo": "Promo Marea",
        "cuerpo": "Aprovechá esta promo para tener Mareas Pro 🐬",
        "url": "",
    },
}


# ---------------- Envío ----------------
def main():
    texto = notificaciones_free.get(tipo_notificacion)
    if texto is None:
        print(f"❌ No existe la notificación '{tipo_notificacion}'")
        return

    message = messaging.Message(
        topic=topic,
        data={
            "tipo": tipo_notificacion,
            "titulo": texto["titulo"],
            "cuerpo": texto["cuerpo"],
            "url": texto.get("url", ""),
        },
        notification=messaging.Notification(
            title=texto["titulo"],
            body=texto["cuerpo"],
        ),
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="chipap",
                icon="ic_stat_notification",
            ),
        ),
    )

    try:
        response = messaging.send(message)
        print(f"✅ Notificación enviada al topic '{topic}': {response}")
    except Exception as e:
        print(f"❌ Error al enviar: {e}")


if __name__ == "__main__":
    main()
