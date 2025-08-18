// ================================================================
// Fondos por momento — resumen
// - Mapea MomentoDelDia a la ruta de imagen correspondiente.
// - Centraliza assets para mantener consistencia visual.
// Uso: obtenerFondoPorMomento(momento) → ruta del asset.
// ================================================================

// frontend/mareas/lib/utils/fondos_por_momento.dart


import 'momento_actual.dart';

// Devolver la ruta del asset según el momento recibido.
String obtenerFondoPorMomento(MomentoDelDia momento) {
  switch (momento) {
    case MomentoDelDia.amanecer:
      return 'assets/fondos/fondo_amanecer.png';
    case MomentoDelDia.dia:
      return 'assets/fondos/fondo_dia.png';
    case MomentoDelDia.atardecer:
      return 'assets/fondos/fondo_atardecer.png';
    case MomentoDelDia.noche:
      return 'assets/fondos/fondo_noche.png';
  }
}
