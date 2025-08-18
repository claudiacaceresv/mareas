// ================================================================
// Tema visual por momento del día — resumen
// Qué hace:
// - Define el modelo TemaVisual (colores + ícono) por momento.
// - Expone obtenerTemaVisual(origen), que resuelve la paleta vía:
//   (a) BuildContext → TemaProvider.momentoActual
//   (b) MomentoDelDia explícito
//   (c) Automático por hora actual si no hay origen
// ================================================================


// frontend/mareas/lib/theme/tema_visual.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';
import '../utils/momento_actual.dart';
import 'estilos/estilo_amanecer.dart';
import 'estilos/estilo_dia.dart';
import 'estilos/estilo_atardecer.dart';
import 'estilos/estilo_noche.dart';

// ---------------- Modelo de tema ----------------
// Agrupar colores y recursos visuales para un momento dado.
class TemaVisual {
  final Color fondo;
  final Color texto;
  final Color linea;
  final Color borde;
  final Color relleno;
  final Color sombra;
  final Color etiqueta;
  final Color textoEtiqueta;
  final String icono;

  const TemaVisual({
    required this.fondo,
    required this.texto,
    required this.linea,
    required this.borde,
    required this.relleno,
    required this.sombra,
    required this.etiqueta,
    required this.textoEtiqueta,
    required this.icono,
  });
}

// ---------------- Resolver por momento ----------------
// Seleccionar paleta a partir de MomentoDelDia.
TemaVisual _obtenerTemaPorMomento(MomentoDelDia momentoDelDia) {
  switch (momentoDelDia) {
    case MomentoDelDia.amanecer:
      return TemaVisual(
        fondo: EstiloAmanecer.fondo,
        texto: EstiloAmanecer.texto,
        linea: EstiloAmanecer.linea,
        borde: EstiloAmanecer.borde,
        relleno: EstiloAmanecer.relleno,
        sombra: EstiloAmanecer.sombra,
        etiqueta: EstiloAmanecer.etiqueta,
        textoEtiqueta: EstiloAmanecer.textoEtiqueta,
        icono: EstiloAmanecer.icono,
      );
    case MomentoDelDia.dia:
      return TemaVisual(
        fondo: EstiloDia.fondo,
        texto: EstiloDia.texto,
        linea: EstiloDia.linea,
        borde: EstiloDia.borde,
        relleno: EstiloDia.relleno,
        sombra: EstiloDia.sombra,
        etiqueta: EstiloDia.etiqueta,
        textoEtiqueta: EstiloDia.textoEtiqueta,
        icono: EstiloDia.icono,
      );
    case MomentoDelDia.atardecer:
      return TemaVisual(
        fondo: EstiloAtardecer.fondo,
        texto: EstiloAtardecer.texto,
        linea: EstiloAtardecer.linea,
        borde: EstiloAtardecer.borde,
        relleno: EstiloAtardecer.relleno,
        sombra: EstiloAtardecer.sombra,
        etiqueta: EstiloAtardecer.etiqueta,
        textoEtiqueta: EstiloAtardecer.textoEtiqueta,
        icono: EstiloAtardecer.icono,
      );
    case MomentoDelDia.noche:
      return TemaVisual(
        fondo: EstiloNoche.fondo,
        texto: EstiloNoche.texto,
        linea: EstiloNoche.linea,
        borde: EstiloNoche.borde,
        relleno: EstiloNoche.relleno,
        sombra: EstiloNoche.sombra,
        etiqueta: EstiloNoche.etiqueta,
        textoEtiqueta: EstiloNoche.textoEtiqueta,
        icono: EstiloNoche.icono,
      );
  }
}

// ---------------- Punto de entrada flexible ----------------
// Aceptar:
// - BuildContext: leer TemaProvider.momentoActual
// - MomentoDelDia: usar el valor provisto
// - null/otro: calcular automáticamente por hora actual
TemaVisual obtenerTemaVisual([dynamic origen]) {
  if (origen is BuildContext) {
    final momento = Provider.of<TemaProvider>(origen).momentoActual;
    return _obtenerTemaPorMomento(momento);
  } else if (origen is MomentoDelDia) {
    return _obtenerTemaPorMomento(origen);
  } else {
    return _obtenerTemaPorMomento(obtenerMomentoDelDia());
  }
}
