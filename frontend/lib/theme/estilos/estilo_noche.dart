// ================================================================
// Estilo “Noche” — qué hace y cómo se usa
// - Define la paleta y el ícono del modo Noche de la UI.
// - Constantes para fondo, texto, líneas, bordes, rellenos, sombras y etiquetas.
// - Importe esta clase y use sus constantes en temas y widgets.
// ================================================================

// frontend\mareas\lib\theme\estilos\estilo_noche.dart

// ==========================
// 🌙 ESTILO NOCHE
// ==========================
import 'package:flutter/material.dart';

class EstiloNoche {
  static const Color fondo = Color(0xFF0B1E33); // Azul medianoche
  static const Color texto = Color(0xFFE8F0FF); // Azul claro casi blanco
  static const Color linea = Color(0xFF5DAEFF); // Azul celeste nocturno
  static const Color borde = Color(0xFF385A7C); // Azul gris violeta
  static const Color relleno = Color(0xFF1B2F4B); // Fondo widgets
  static const Color sombra = Color(0xFF000000); // Sombra fuerte pixelart
  static const Color etiqueta = Color(0xFFFF9933); // Color destacado
  static const Color textoEtiqueta = Color(0xFFFF9933); // Texto destacado
  static const String icono = 'assets/iconos/barquito.png';
}
