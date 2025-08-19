// ================================================================
// Estilo “Atardecer”: qué hace y cómo funciona
// - Define la paleta y el ícono para el modo atardecer de la UI.
// - Las constantes se usan en widgets/temas para fondo, texto, líneas,
//   bordes, rellenos, sombras y etiquetas.
// - Se importa y se referencian las constantes donde haga falta.
// ================================================================

// frontend\mareas\lib\theme\estilos\estilo_atardecer.dart

// ==========================
// 🌇 ESTILO ATARDECER
// ==========================
import 'package:flutter/material.dart';

class EstiloAtardecer {
  static const Color fondo = Color(0xFF3E1F47); // Violeta profundo
  static const Color texto = Color(0xFFFFEEDD); // Blanco cálido
  static const Color linea = Color(0xFFFF6F61); // Coral anaranjado
  static const Color borde = Color(0xFFAD4B50); // Rojo ladrillo desaturado
  static const Color relleno = Color(0xFF58324A); // Fondo widgets translúcido
  static const Color sombra = Color(0xFF1A0E1F); // Sombra noche
  static const Color etiqueta = Color.fromARGB(255, 246, 218, 244); // Color destacado
  static const Color textoEtiqueta = Color.fromARGB(255, 246, 218, 244); // Texto destacado
  static const String icono = 'assets/iconos/barquito.png';
}
