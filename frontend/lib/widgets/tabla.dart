// ================================================================
// Tabla de mareas — resumen
// Qué hace: muestra por hora las alturas mín/prom/máx para una fecha.
// Cómo funciona: filtra por 'yyyy-MM-dd', usa StickyHeader para encabezado fijo, 
// tipografías PressStart/Roboto y colores desde TemaVisual.
// Uso: TablaMareaHoy(datos: listaINA, fecha: DateTime(...)).
// ================================================================

// frontend/mareas/lib/widgets/tabla.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:app_mareas/theme/tema_visual.dart';

class TablaMareaHoy extends StatelessWidget {
  // ---------------- Props ----------------
  final List<dynamic> datos; // dataset completo de registros INA
  final DateTime fecha;      // fecha a renderizar

  const TablaMareaHoy({super.key, required this.datos, required this.fecha});

  @override
  Widget build(BuildContext context) {
    // ---------------- Tema y filtrado ----------------
    final tema = obtenerTemaVisual(context);
    final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);

    // Filtrar registros que correspondan a la fecha seleccionada
    final datosFiltrados = datos.where((item) {
      return item['fecha'].toString().startsWith(fechaStr);
    }).toList();

    // ---------------- Contenedor principal ----------------
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tema.fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
      ),

      // Encabezado pegajoso + contenido scrolleable
      child: StickyHeader(
        // ---------- Encabezado: fecha + fila de títulos ----------
        header: Container(
          color: tema.fondo, // fondo sólido para cubrir el scroll
          child: Column(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(fecha),
                    style: TextStyle(
                      fontFamily: 'PressStart',
                      fontSize: 10,
                      color: tema.texto,
                    ),
                  ),
                ),
              ),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                border: TableBorder.all(color: Colors.white, width: 1.0),
                children: [
                  _buildFilaTitulo(tema),
                ],
              ),
            ],
          ),
        ),

        // ---------- Cuerpo: filas por hora ----------
        content: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 300),
          child: SingleChildScrollView(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              border: TableBorder.all(color: Colors.white, width: 1.0),
              children: datosFiltrados.map((item) {
                // Formatear alturas con 2 decimales
                final alturaMin = (item['altura_minima'] as num).toDouble().toStringAsFixed(2);
                final alturaProm = (item['altura_promedio'] as num).toDouble().toStringAsFixed(2);
                final alturaMax = (item['altura_maxima'] as num).toDouble().toStringAsFixed(2);

                return TableRow(children: [
                  _celda(item['hora'].toString().substring(0, 5), tema),
                  _celda("$alturaMin m", tema),
                  _celda("$alturaProm m", tema),
                  _celda("$alturaMax m", tema),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Fila de encabezados de columna ----------------
  TableRow _buildFilaTitulo(TemaVisual tema) {
    return TableRow(children: [
      _celda("Hora", tema, esTitulo: true),
      _celda("Mín", tema, esTitulo: true),
      _celda("Prom", tema, esTitulo: true),
      _celda("Máx", tema, esTitulo: true),
    ]);
  }

  // ---------------- Celda con estilo ----------------
  Widget _celda(String texto, TemaVisual tema, {bool esTitulo = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: esTitulo ? 'PressStart' : 'Roboto',
          fontSize: esTitulo ? 9 : 11,
          fontWeight: esTitulo ? FontWeight.normal : FontWeight.w500,
          color: tema.texto,
        ),
      ),
    );
  }
}
