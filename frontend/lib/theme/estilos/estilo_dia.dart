// ================================================================
// Estilo “Día” — qué es y cómo se usa
// - Define la paleta y el ícono del modo Día de la UI.
// - Constantes para fondo, texto, líneas, bordes, rellenos, sombras y etiquetas.
// - Se importa y se usan estas constantes en temas y widgets.
// ================================================================

// frontend\mareas\lib\theme\estilos\estilo_dia.dart

// ==========================
// ☀️ ESTILO DÍA
// ==========================
import 'package:flutter/material.dart';

class EstiloDia {
  static const Color fondo = Color(0xFFCCECFF); // Celeste pastel
  static const Color texto = Color(0xFF204F75); // Azul grisáceo
  static const Color linea = Color(0xFF3399FF); // Azul brillante gráfico
  static const Color borde = Color(0xFFB3DEFF); // Azul claro
  static const Color relleno = Color(0xFFE9F6FF); // Fondo widgets
  static const Color sombra = Color(0xFF1A3F66); // Sombra azul marino
  static const Color etiqueta = Color(0xFFCC5500); // Color destacado
  static const Color textoEtiqueta = Color(0xFFCC5500); // Texto destacado
  static const String icono = 'assets/iconos/barquito.png';
}
