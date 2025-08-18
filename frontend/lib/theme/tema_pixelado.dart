// ================================================================
// Tema “Pixelado” — qué hace y cómo funciona
// - Aplica un ThemeData con estética retro (PressStart) y Material 3.
// - Toma la paleta activa desde TemaVisual y la usa en fondo/texto.
// - Centraliza estilos base: AppBar sin sombra, tipografía y colores.
// Uso: importe `temaPixelado` y asígnele a `MaterialApp(theme: temaPixelado)`.
// ================================================================

// frontend/mareas/lib/theme/tema_pixelado.dart

// ------------------------------------------------------------
// Definir tema visual principal de la app con estética pixel.
// Centralizar colores tipografía y estilos base de Material.
// ------------------------------------------------------------

// ==========================
// Imports
// ==========================
import 'package:flutter/material.dart';
import 'tema_visual.dart';

// ==========================
// Fuente de colores (TemaVisual)
// Obtener paleta actual y aplicarla al ThemeData.
// ==========================
final TemaVisual visual = obtenerTemaVisual();

// ==========================
// ThemeData de la app
// - Fondo y texto según paleta
// - AppBar sin sombra y tipografía retro
// - TextTheme base con PressStart
// - Material 3 activado
// ==========================
final ThemeData temaPixelado = ThemeData(
  scaffoldBackgroundColor: visual.fondo,
  appBarTheme: AppBarTheme(
    backgroundColor: visual.fondo,
    elevation: 0,
    titleTextStyle: const TextStyle(
      fontFamily: 'PressStart',
      fontSize: 14,
      color: Colors.black,
    ),
    iconTheme: IconThemeData(color: visual.texto),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(
      fontFamily: 'PressStart',
      fontSize: 8,
    ),
  ),
  useMaterial3: true,
);
