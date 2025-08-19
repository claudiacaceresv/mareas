// ================================================================
// Gráfico de marea expandido — resumen
// Qué hace:
// - Muestra la curva diaria en lienzo ancho con scroll horizontal.
// - Centra la vista cerca de la hora actual y la marca con una línea.
// - Renderiza tres series: mínimo, promedio y máximo.
// - Calcula dominio Y con margen y pasos de 0.2 m.
// - Usa paleta desde TemaVisual. Botón para recentrar en “hora actual”.
// Cómo funciona:
// 1) Filtra datos por fecha.
// 2) Genera FlSpot[] para min/prom/máx.
// 3) Configura ejes y grilla en fl_chart.
// 4) Dibuja overlay de hora actual y etiquetas.
// Uso: GraficoExpandido(datos: ..., fecha: ...).
// ================================================================

// frontend/mareas/lib/widgets/grafico_expandido.dart

import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/tema_visual.dart';
import 'package:app_mareas/services/gestor_anuncios.dart';

class GraficoExpandido extends StatefulWidget {
  // ---------------- Props ----------------
  final List<dynamic> datos;
  final DateTime? fecha;

  const GraficoExpandido({
    super.key,
    required this.datos,
    this.fecha,
  });

  @override
  State<GraficoExpandido> createState() => _GraficoExpandidoState();
}

class _GraficoExpandidoState extends State<GraficoExpandido> {
  // ---------------- Estado interno ----------------
  late final ScrollController scrollController;

  // ---------------- Ciclo de vida ----------------
  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    final horaActualDouble = ahora.hour + ahora.minute / 60;
    // Posicionar el scroll con ~2h de margen a la izquierda
    scrollController = ScrollController(
      initialScrollOffset: ((horaActualDouble - 2) * 48.0).clamp(0, double.infinity),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  // ---------------- Render ----------------
  @override
  Widget build(BuildContext context) {
    final tema = obtenerTemaVisual(context);

    // ---- Preparación de datos por fecha ----
    final ahora = DateTime.now();
    final horaActualDouble = ahora.hour + ahora.minute / 60;
    final fechaSeleccionada = DateFormat('yyyy-MM-dd').format(widget.fecha ?? ahora);

    final datosFiltrados = widget.datos.where((item) {
      final itemFecha = item['fecha'].toString().substring(0, 10);
      return itemFecha == fechaSeleccionada;
    }).toList();

    if (datosFiltrados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No hay datos para mostrar.',
          style: TextStyle(fontFamily: 'PressStart', fontSize: 8),
        ),
      );
    }

    // Escala base para tamaños responsivos
    final escala = MediaQuery.of(context).size.width / 300;

    // ---- Series de puntos (mín/prom/máx) ----
    final List<FlSpot> puntosProm = [];
    final List<FlSpot> puntosMin = [];
    final List<FlSpot> puntosMax = [];

    for (final item in datosFiltrados) {
      final partes = item['hora'].toString().split(":");
      final hora = int.parse(partes[0]) + int.parse(partes[1]) / 60;
      puntosProm.add(FlSpot(hora, (item['altura_promedio'] as num).toDouble()));
      puntosMin.add(FlSpot(hora, (item['altura_minima'] as num).toDouble()));
      puntosMax.add(FlSpot(hora, (item['altura_maxima'] as num).toDouble()));
    }

    // ---- Dominio Y con margen y pasos de 0.2m ----
    double minY = puntosMin.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = puntosMax.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    const margenY = 0.1;
    minY = ((minY - margenY) / 0.2).floor() * 0.2;
    maxY = ((maxY + margenY) / 0.2).ceil() * 0.2;

    // ---------------- Lienzo y helpers ----------------
    return Container(
      decoration: BoxDecoration(
        color: tema.fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ancho total del chart: 24h * 48px/h
          const double pxPorHora = 48.0;
          final double chartWidth = pxPorHora * 24;

          // Interpolar altura Y para etiquetas a partir de una X (hora)
          double interpolar(List<FlSpot> puntos, double x) {
            for (int i = 0; i < puntos.length - 1; i++) {
              final a = puntos[i];
              final b = puntos[i + 1];
              if (a.x <= x && x <= b.x) {
                final ratio = (x - a.x) / (b.x - a.x);
                return a.y + (b.y - a.y) * ratio;
              }
            }
            return puntos.last.y;
          }

          // Convertir altura a coordenada de pantalla
          double yOffset(double altura) {
            final height = constraints.maxHeight - 70.0;
            final ratio = (altura - minY) / (maxY - minY);
            return constraints.maxHeight - 70.0 - (height * ratio);
          }

          // Valores actuales para etiquetas de referencia
          final double alturaProm = interpolar(puntosProm, horaActualDouble);
          final double alturaMin = interpolar(puntosMin, horaActualDouble);
          final double alturaMax = interpolar(puntosMax, horaActualDouble);

          // Etiqueta flotante con posicionamiento relativo a la línea de hora
          Widget etiqueta(String texto, double top) {
            final xLinea = horaActualDouble * pxPorHora;
            final esIzquierda = xLinea > chartWidth - 60 * escala;
            return Positioned(
              top: top,
              left: esIzquierda ? null : xLinea,
              right: esIzquierda ? chartWidth - xLinea : null,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4 * escala, vertical: 2 * escala),
                decoration: BoxDecoration(
                  color: tema.fondo.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4 * escala),
                ),
                child: Text(
                  texto,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10 * escala,
                    fontWeight: FontWeight.bold,
                    color: tema.textoEtiqueta,
                  ),
                ),
              ),
            );
          }

          // ---------------- Estructura visual ----------------
          return Stack(
            children: [
              // Título con fecha
              Positioned(
                top: 8 * escala,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(widget.fecha ?? ahora),
                    style: TextStyle(
                      fontFamily: 'PressStart',
                      fontSize: 10 * escala,
                      fontWeight: FontWeight.w500,
                      color: tema.texto,
                    ),
                  ),
                ),
              ),

              // Eje Y a la izquierda (valores cada 0.2m)
              Positioned(
                top: 32 * escala,
                left: 6 * escala,
                bottom: 8 * escala,
                width: 45 * escala,
                child: CustomPaint(
                  painter: _YAxisPainter(minY: minY, maxY: maxY, theme: tema, escala: escala),
                ),
              ),

              // Área de gráfico con scroll horizontal
              Positioned.fill(
                top: 32 * escala,
                left: 50 * escala,
                right: 12 * escala,
                bottom: 6 * escala,
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: Stack(
                      children: [
                        // Chart principal
                        LineChart(
                          LineChartData(
                            backgroundColor: Colors.transparent,
                            minX: 0.0,
                            maxX: 24.0,
                            minY: minY,
                            maxY: maxY,
                            lineTouchData: const LineTouchData(enabled: false),

                            // Títulos y ejes
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 30 * escala,
                                  getTitlesWidget: (value, meta) {
                                    final hora = value.toInt();
                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 8 * escala,
                                      child: Text(
                                        "${hora.toString().padLeft(2, '0')}h",
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 10 * escala,
                                          fontWeight: FontWeight.w500,
                                          color: tema.texto,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Grilla y borde
                            gridData: FlGridData(
                              show: true,
                              horizontalInterval: 0.2,
                              verticalInterval: 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: tema.texto.withOpacity(0.5),
                                  strokeWidth: 1 * escala,
                                );
                              },
                              getDrawingVerticalLine: (value) {
                                return FlLine(
                                  color: tema.texto.withOpacity(0.2),
                                  strokeWidth: 0.5 * escala,
                                );
                              },
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: tema.texto),
                            ),

                            // Series: promedio, mínimo y máximo
                            lineBarsData: <LineChartBarData>[
                              LineChartBarData(
                                spots: puntosProm,
                                isCurved: true,
                                color: tema.linea,
                                barWidth: 3 * escala,
                                dotData: const FlDotData(show: false),
                              ),
                              LineChartBarData(
                                spots: puntosMin,
                                isCurved: false,
                                color: tema.linea.withOpacity(0.6),
                                barWidth: 1.5 * escala,
                                dashArray: <int>[(6 * escala).toInt(), (3 * escala).toInt()],
                                dotData: const FlDotData(show: false),
                              ),
                              LineChartBarData(
                                spots: puntosMax,
                                isCurved: false,
                                color: tema.linea.withOpacity(0.6),
                                barWidth: 1.5 * escala,
                                dashArray: <int>[(6 * escala).toInt(), (3 * escala).toInt()],
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),

                        // Línea vertical de “hora actual” (overlay para compatibilidad fl_chart)
                        Positioned(
                          left: horaActualDouble * pxPorHora - (1 * escala),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2 * escala,
                            color: tema.etiqueta,
                          ),
                        ),

                        // Etiquetas informativas
                        etiqueta("máx. ${alturaMax.toStringAsFixed(2)}m", yOffset(alturaMax)),
                        etiqueta("prom. ${alturaProm.toStringAsFixed(2)}m", yOffset(alturaProm)),
                        etiqueta("mín. ${alturaMin.toStringAsFixed(2)}m", yOffset(alturaMin)),
                        etiqueta(
                          "${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}h",
                          8 * escala,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Botón: centrar scroll en la hora actual
              Positioned(
                bottom: 16 * escala,
                right: 16 * escala,
                child: FloatingActionButton(
                  onPressed: () {
                    GestorAnuncios.manejarInteraccion(
                      context: context,
                      accion: () {
                        final posicion =
                            ((horaActualDouble - 2) * pxPorHora).clamp(0.0, double.infinity);
                        scrollController.animateTo(
                          posicion,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                        );
                      },
                      requiereInternet: true,
                    );
                  },
                  mini: true,
                  child: const Icon(Icons.access_time),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Pintor del eje Y con marcas cada 0.2m
// Renderiza textos alineados a la derecha dentro del área reservada.
// ------------------------------------------------------------
class _YAxisPainter extends CustomPainter {
  final double minY;
  final double maxY;
  final TemaVisual theme;
  final double escala;

  _YAxisPainter({
    required this.minY,
    required this.maxY,
    required this.theme,
    required this.escala,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: ui.TextDirection.ltr,
    );

    const double paddingTop = 0.0;
    const double paddingBottom = 30.0;
    const double step = 0.2;
    final int count = ((maxY - minY) / step).round();
    final double availableHeight = size.height - paddingTop - paddingBottom;

    for (int i = 0; i <= count; i++) {
      final yValue = maxY - i * step;
      final textStyle = TextStyle(
        fontFamily: 'Roboto',
        fontSize: 10 * escala,
        fontWeight: FontWeight.w500,
        color: theme.texto,
      );
      final textSpan = TextSpan(text: '${yValue.toStringAsFixed(1)}m', style: textStyle);
      textPainter.text = textSpan;
      textPainter.layout();

      final yOffset = (i / count) * availableHeight + paddingTop - textPainter.height / 2;
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 4 * escala, yOffset));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
