// ================================================================
// Administra el tema visual de la app.
// Qué hace:
// - Determina el “momento del día” efectivo: automático (según hora) o manual.
// - Expone getters: `momentoActual` y `tema` (paleta TemaVisual lista para usar).
// - Persiste preferencias en SharedPreferences: `modoAutomatico` y `temaManual`.
// - Acciones públicas: `toggleAutomatico(bool)` y `cambiarMomento(MomentoDelDia)`.
// - Inicialización: `cargarDesdePreferencias()` rehidrata estado y notifica a la UI.
// Notas: sin llamadas de red; usa notifyListeners() para actualizar widgets.
// ================================================================


import 'package:flutter/material.dart';
import '../utils/momento_actual.dart';
import '../theme/tema_visual.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemaProvider extends ChangeNotifier {
  // ---------------- Preferencias de tema ----------------
  bool usarAutomatico = true;
  MomentoDelDia seleccionado = MomentoDelDia.dia;

  // Determinar momento efectivo: automático o manual
  MomentoDelDia get momentoActual =>
      usarAutomatico ? obtenerMomentoDelDia() : seleccionado;

  // Resolver paleta/estilos a partir del momento actual
  TemaVisual get tema => obtenerTemaVisual(momentoActual);

  // ---------------- Acciones de usuario ----------------
  // Activar/desactivar modo automático y persistir.
  Future<void> toggleAutomatico(bool activo) async {
    usarAutomatico = activo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modoAutomatico', activo);
    notifyListeners();
  }

  // Cambiar momento manualmente y persistir.
  Future<void> cambiarMomento(MomentoDelDia nuevo) async {
    seleccionado = nuevo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('temaManual', nuevo.name);
    notifyListeners();
  }

  // ---------------- Inicialización ----------------
  // Cargar preferencias guardadas y notificar a la UI.
  Future<void> cargarDesdePreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    usarAutomatico = prefs.getBool('modoAutomatico') ?? true;
    final temaStr = prefs.getString('temaManual') ?? 'dia';

    try {
      seleccionado = MomentoDelDia.values.firstWhere(
        (e) => e.name == temaStr,
        orElse: () => MomentoDelDia.dia,
      );
    } catch (_) {
      seleccionado = MomentoDelDia.dia;
    }

    notifyListeners();
  }
}
