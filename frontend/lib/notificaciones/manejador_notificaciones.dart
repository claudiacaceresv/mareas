// ================================================================
// Orquesta el enrutamiento de notificaciones FCM.
// Qué hace:
// - Lee `data['tipo']` y delega a cada handler (actualizacion, promocion).
// - Centraliza trazas de depuración y facilita extender nuevos tipos.
// - Deja la idempotencia al handler correspondiente.
// ================================================================


import 'package:firebase_messaging/firebase_messaging.dart';

import 'actualizacion.dart';
import 'promocion.dart';

// Punto de extensión: agregar nuevos tipos cuando existan handlers.
// import 'tipo_alerta.dart';
// import 'tipo_otro.dart';

class ManejadorNotificaciones {
  /// Recibir un `RemoteMessage` y derivarlo según el campo `tipo` en `data`.
  /// Mantener idempotencia y trazas de depuración mediante prints.
  static Future<void> manejar(RemoteMessage message) async {
    print("🔍 Datos recibidos: ${message.data}");
    final data = message.data;
    final tipo = data['tipo'];

    switch (tipo) {
      // ---- Tipo: actualización de la app ----
      case 'actualizacion':
        await TipoActualizacion.procesar(data);
        print('🧪 Ejecutando TipoActualizacion.procesar con data: $data');
        break;

      // ---- Tipo: promoción de producto/feature ----
      case 'promocion':
        await TipoPromocion.procesar(data);
        print('🎯 Ejecutando TipoPromocion.procesar con data: $data');
        break;

      // ---- Ejemplo de futura ampliación ----
      // case 'alerta_marea':
      //   await TipoAlertaMarea.procesar(data);
      //   break;

      // ---- Fallback: tipo desconocido ----
      default:
        print('🔕 Tipo de notificación desconocido: $tipo');
    }
  }
}
