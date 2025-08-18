// ================================================================
// Momento del día — qué hace y lógica
// - Devuelve amanecer/día/atardecer/noche según hora y estación.
// - Permite forzar un valor fijo para pruebas (testing=true).
// - Útil para adaptar colores y fondos en la UI.
// ================================================================

// frontend/mareas/lib/utils/momento_actual.dart

// ==========================
// ⏰ Enum de momentos
// ==========================
enum MomentoDelDia {
  amanecer,
  dia,
  atardecer,
  noche,
}

// ==========================
// 🔧 Detección del momento actual
// - Usar rangos por estación (mes) y hora local.
// - Permitir forzar un valor fijo para pruebas.
// ==========================
MomentoDelDia obtenerMomentoDelDia() {
  const bool testing = false; // Cambiar a true solo para forzar un momento fijo en pruebas

  if (testing) {
    const String test = 'dia'; // Opciones válidas: amanecer, dia, atardecer, noche
    switch (test) {
      case 'amanecer':
        return MomentoDelDia.amanecer;
      case 'dia':
        return MomentoDelDia.dia;
      case 'atardecer':
        return MomentoDelDia.atardecer;
      case 'noche':
        return MomentoDelDia.noche;
    }
  }

  // Hora y mes actuales
  final ahora = DateTime.now();
  final hora = ahora.hour;
  final mes = ahora.month;

  // Agrupar meses por estación
  final primavera = [9, 10, 11];
  final verano = [12, 1, 2];
  final otono = [3, 4, 5];
  final invierno = [6, 7, 8];

  // Reglas por estación: devolver tramo correspondiente
  if (verano.contains(mes)) {
    if (hora >= 5 && hora < 8) return MomentoDelDia.amanecer;
    if (hora >= 7 && hora < 20) return MomentoDelDia.dia;
    if (hora >= 20 && hora < 21) return MomentoDelDia.atardecer;
    return MomentoDelDia.noche;
  }

  if (primavera.contains(mes)) {
    if (hora >= 6 && hora < 9) return MomentoDelDia.amanecer;
    if (hora >= 8 && hora < 19) return MomentoDelDia.dia;
    if (hora >= 19 && hora < 20) return MomentoDelDia.atardecer;
    return MomentoDelDia.noche;
  }

  if (otono.contains(mes)) {
    if (hora >= 7 && hora < 9) return MomentoDelDia.amanecer;
    if (hora >= 8 && hora < 18) return MomentoDelDia.dia;
    if (hora >= 18 && hora < 19) return MomentoDelDia.atardecer;
    return MomentoDelDia.noche;
  }

  if (invierno.contains(mes)) {
    if (hora >= 7 && hora < 9) return MomentoDelDia.amanecer;
    if (hora >= 8 && hora < 17) return MomentoDelDia.dia;
    if (hora >= 17 && hora < 18) return MomentoDelDia.atardecer;
    return MomentoDelDia.noche;
  }

  // Fallback por si no se encuadra
  return MomentoDelDia.dia;
}
