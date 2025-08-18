// ================================================================
// Gestiona notificaciones FCM de tipo "promocion".
// Qué hace:
// - Lee `titulo`, `cuerpo` y `url` del payload y los guarda en SharedPreferences.
// - Evita duplicados usando `notificacionesLeidas`.
// - Si hay `BuildContext` (vía `navigatorKey`), notifica a NotificacionesProvider.
// - No marca como leída; eso ocurre desde la UI/Provider.
// Uso:
// - Invocado por ManejadorNotificaciones.manejar(message).
// - `data` esperado: { tipo, titulo?, cuerpo?, url? }.
// ================================================================


import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/notificaciones_provider.dart';

class TipoPromocion {
  /// Procesar payload promocional y reflejarlo en la app.
  /// - Evitar duplicados si ya fue marcado como leído.
  /// - Guardar título, cuerpo y URL para mostrarlos luego.
  /// - Notificar al provider si hay contexto disponible.
  static Future<void> procesar(Map<String, dynamic> data) async {
    // ---------------- Preparar acceso a preferencias ----------------
    final prefs = await SharedPreferences.getInstance();
    final clave = 'notificacion_promocion';

    // Verificar si la promoción ya fue leída para no repetirla
    final leidas = prefs.getStringList('notificacionesLeidas') ?? [];
    if (leidas.contains(clave)) {
      print('🔁 Notificación $clave ya fue leída');
      return;
    }

    // ---------------- Persistir datos para el menú ----------------
    await prefs.setBool('hayNotificacionMenu', true);
    await prefs.setString('notificacion_promocion_titulo', data['titulo'] ?? '¡Promo Marea!');
    await prefs.setString('notificacion_promocion_cuerpo', data['cuerpo'] ?? 'Aprovechá esta promo para tener Mareas Pro 🐬');
    await prefs.setString('notificacion_promocion_url', data['url'] ?? '');

    print('📌 Notificación de promoción procesada');

    // ---------------- Intentar refrescar UI vía provider ----------------
    final context = navigatorKey.currentState?.overlay?.context;
    if (context != null) {
      print('📲 context disponible, notificando al provider');
      await Provider.of<NotificacionesProvider>(context, listen: false).cargarDesdePreferencias();
    } else {
      print('⚠️ context no disponible, se actualizará al abrir el engranaje');
    }
  }
}
