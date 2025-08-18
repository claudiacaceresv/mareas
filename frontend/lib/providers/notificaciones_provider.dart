// ================================================================
// Administra los avisos que se muestran en el menú (banners).
// Qué hace:
// - Lee desde SharedPreferences y arma la lista visible.
// - Filtra tipos por flavor: FREE (actualizacion, promocion) / PRO (actualizacion, alerta_*).
// - Expone `notificaciones` y el flag `hayNotificacionMenu` para la UI.
// - Marca como leída: actualiza lista, limpia claves (titulo/cuerpo/url),
//   ajusta `hayNotificacionMenu` y mantiene idempotencia.
// Notas:
// - Todo es asíncrono para no bloquear la UI.
// - No hace llamadas de red; solo persiste en local.
// ================================================================


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../flavors.dart'; 

class NotificacionesProvider with ChangeNotifier {
  // ---------------- Estado interno ----------------
  List<Map<String, String>> _notificaciones = [];

  // Exponer lista inmutable para la UI
  List<Map<String, String>> get notificaciones => _notificaciones;

  // Indicar si hay notificaciones pendientes de mostrar
  bool get hayNotificacionMenu => _notificaciones.isNotEmpty;

  // ---------------- Carga desde almacenamiento local ----------------
  // Leer preferencias, filtrar por flavor y poblar la lista para el menú.
  Future<void> cargarDesdePreferencias() async {
    print('🧪 cargarDesdePreferencias ejecutado');
    final prefs = await SharedPreferences.getInstance();
    final lista = <Map<String, String>>[];

    // Notificaciones habilitadas por edición (free/pro)
    final tipos = F.appFlavor == Flavor.free
        ? ['actualizacion', 'promocion']
        : ['actualizacion', 'alerta_maxima', 'alerta_promedio', 'alerta_minima'];

    // Armar entrada por cada tipo disponible
    for (final tipo in tipos) {
      final clave = 'notificacion_$tipo';
      final titulo = prefs.getString('${clave}_titulo');
      final cuerpo = prefs.getString('${clave}_cuerpo');

      if (titulo != null && cuerpo != null) {
        lista.add({
          'clave': clave,
          'titulo': titulo,
          'cuerpo': cuerpo,
          'url': prefs.getString('${clave}_url') ?? '',
        });
      }
    }

    _notificaciones = lista;
    print('📥 Notificaciones cargadas: $_notificaciones');
    notifyListeners();
  }

  // ---------------- Marcado como leído ----------------
  // Quitar una notificación de la lista y limpiar su persistencia.
  void marcarComoLeida(String clave) async {
    _notificaciones.removeWhere((n) => n['clave'] == clave);

    final prefs = await SharedPreferences.getInstance();
    List<String> leidas = prefs.getStringList('notificacionesLeidas') ?? [];

    // Eliminar la clave para permitir que vuelva a mostrarse en el futuro
    leidas.remove(clave);
    await prefs.setStringList('notificacionesLeidas', leidas);

    // Desactivar indicador de menú (se reactivará si aparece otra)
    await prefs.setBool('hayNotificacionMenu', false);

    // Borrar detalles persistidos de la notificación
    await prefs.remove('${clave}_titulo');
    await prefs.remove('${clave}_cuerpo');
    await prefs.remove('${clave}_url');

    notifyListeners();
  }
}
