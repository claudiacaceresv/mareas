// ================================================================
// Gestiona notificaciones FCM de tipo "actualizacion".
// Qué hace:
// - Lee `titulo`, `cuerpo` y `url` del payload y los guarda en SharedPreferences.
// - Evita duplicados si la clave ya figura en `notificacionesLeidas`.
// - Si hay `BuildContext` disponible (via `navigatorKey`), notifica a NotificacionesProvider.
// - No marca como leída: ese flujo ocurre desde la UI/Provider.
// Uso:
// - Invocado por ManejadorNotificaciones.manejar(message).
// - Estructura esperada en `data`: { tipo, titulo?, cuerpo?, url? }.
// ================================================================


import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // contiene navigatorKey global
import '../providers/notificaciones_provider.dart';

class TipoActualizacion {
  /// Procesar payload de notificación y reflejarlo en la UI.
  /// - Evitar duplicados si ya fue leída.
  /// - Guardar título, cuerpo y URL para mostrarlos en el menú.
  /// - Notificar al provider cuando haya contexto disponible.
  static Future<void> procesar(Map<String, dynamic> data) async {
    // ---------------- Preparar preferencias y claves ----------------
    final prefs = await SharedPreferences.getInstance();
    final clave = 'notificacion_actualizacion';

    // Lista de notificaciones ya leídas para evitar repeticiones
    final leidas = prefs.getStringList('notificacionesLeidas') ?? [];

    // ---------------- Idempotencia: salir si ya se procesó ----------------
    if (leidas.contains(clave)) {
      print('🔁 Notificación $clave ya fue leída');
      return; // evitar mostrarla si ya fue leída
    }

    // ---------------- Persistir estado para el menú ----------------
    await prefs.setBool('hayNotificacionMenu', true);
    await prefs.setString('notificacion_actualizacion_titulo', data['titulo'] ?? 'Actualización disponible');
    await prefs.setString('notificacion_actualizacion_cuerpo', data['cuerpo'] ?? '📍 Nuevas estaciones! Zárate y San Fernando');
    await prefs.setString('notificacion_actualizacion_url', data['url'] ?? '');

    print('📌 Notificación de actualización procesada');

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
