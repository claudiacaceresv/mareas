// ================================================================
// Estilo “Amanecer” — qué es y cómo se usa
// - Define una paleta y recursos visuales para la UI en modo amanecer.
// - Colores para fondo, texto, líneas, bordes, rellenos y sombras.
// - Incluye la ruta del icono temático usado en la interfaz.
// Uso: importar esta clase y referenciar sus constantes en widgets/temas.
// ================================================================

// frontend\mareas\lib\theme\estilos\estilo_amanecer.dart

// ==========================
// 🌅 ESTILO AMANECER
// ==========================
import 'package:flutter/material.dart';

class EstiloAmanecer {
  static const Color fondo = Color(0xFFFFE5EC); // Rosa pastel claro (cielo)
  static const Color texto = Color(0xFF7B3F00); // Marrón suave
  static const Color linea = Color(0xFFFFB3C1); // Rosa salmón medio
  static const Color borde = Color(0xFFFFD6DC); // Rosa claro para bordes
  static const Color relleno = Color(0xFFFFF1F5); // Fondo widgets
  static const Color sombra = Color(0xFFAA6677); // Sombra pixel art cálida
  static const Color etiqueta = Color(0xFF003366); // Color destacado para etiquetas
  static const Color textoEtiqueta = Color(0xFF003366); // Texto de etiquetas
  static const String icono = 'assets/iconos/barquito.png';
}
