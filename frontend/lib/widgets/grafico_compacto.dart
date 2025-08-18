// ================================================================
// Gráfico de marea compacto — resumen
// Qué hace:
// - Dibuja la curva diaria con mínimos, promedio y máximos por hora.
// - Muestra línea de “hora actual” y etiquetas dinámicas.
// - Usa paleta desde TemaProvider y se adapta al tamaño disponible.
// Cómo funciona:
// 1) Filtra datos por fecha.
// 2) Construye series (min/prom/max) como FlSpot[].
// 3) Calcula dominio Y y configura ejes y grilla.
// 4) Renderiza con fl_chart y agrega la línea vertical actual.
// Uso: GraficoMareaCompacto(datos: ..., fecha: ...).
// ================================================================

// frontend/mareas/lib/widgets/grafico_compacto.dart

import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_mareas/theme/tema_visual.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';

class GraficoMareaCompacto extends StatelessWidget {
  // ---------------- Props ----------------
  final List<dynamic> datos;       // dataset bruto con {fecha, hora, altura_*}
  final DateTime? fecha;           // fecha a visualizar
  final bool esMini;               // modo compacto para embebidos
  final double minX;               // inicio del eje X (hora)
  final double maxX;               // fin del eje X (hora)
  final bool forzarLineasGruesas;  // reservado; no altera la lógica actual

  const GraficoMareaCompacto({
    super.key,
    required this.datos,
    this.fecha,
    this.esMini = false,
    this.minX = 0.0,
    this.maxX = 24.0,
    this.forzarLineasGruesas = false,
  });

  @override
  Widget build(BuildContext context) {
    // ---------------- 1) Filtrar datos por fecha ----------------
    final fechaSeleccionada = DateFormat('yyyy-MM-dd').format(fecha!);

    final datosFiltrados = datos.where((item) {
      final itemFecha = item['fecha'].toString().split('T').first;
      return itemFecha == fechaSeleccionada;
    }).toList();

    print('⏳ Datos filtrados: ${datosFiltrados.length}');
    print('⏳ Primer item: ${datosFiltrados.isNotEmpty ? datosFiltrados.first : 'Ninguno'}');

    // Si no hay datos del INA para el día, mostrar mensaje adaptativo
    if (datosFiltrados.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Escalar tamaño de tipografía según ancho disponible
          double fontSize = constraints.maxWidth * 0.15;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No hay datos de hoy publicados por el INA (Instituto Nacional del Agua)',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: fontSize.clamp(16, 40), // mínimo 16, máximo 40
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      );
    }

    // ---------------- 2) Construir series min/prom/max ----------------
    List<FlSpot> puntosPromedio = [];
    List<FlSpot> puntosMinimo = [];
    List<FlSpot> puntosMaximo = [];

    final ahora = DateTime.now();
    final horaActualDouble = ahora.hour + ahora.minute / 60;

    for (var item in datosFiltrados) {
      final horaStr = item['hora'].toString().substring(0, 5);
      final partes = horaStr.split(':');
      final horaDouble = int.parse(partes[0]) + int.parse(partes[1]) / 60;

      puntosPromedio.add(FlSpot(horaDouble, (item['altura_promedio'] as num).toDouble()));
      puntosMinimo.add(FlSpot(horaDouble, (item['altura_minima'] as num).toDouble()));
      puntosMaximo.add(FlSpot(horaDouble, (item['altura_maxima'] as num).toDouble()));
    }

    print('📊 puntosPromedio: $puntosPromedio');
    print('📊 puntosMinimo: $puntosMinimo');
    print('📊 puntosMaximo: $puntosMaximo');

    // ---------------- 3) Dominios y escalas ----------------
    double redondearAbajo(double valor, double paso) => (valor / paso).floor() * paso;
    double redondearArriba(double valor, double paso) => (valor / paso).ceil() * paso;

    final alturaMinima = puntosMinimo.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final alturaMaxima = puntosMaximo.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    final margenY = 0.1;
    final minY = redondearAbajo(alturaMinima - margenY, 0.2);
    final maxY = redondearArriba(alturaMaxima + margenY, 0.2);

    // Paleta desde el tema actual
    final tema = Provider.of<TemaProvider>(context).tema;

    // ---------------- 4) Interpolación para etiquetas dinámicas ----------------
    double interpolarAltura(List<FlSpot> puntos, double x) {
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

    final alturaProm = interpolarAltura(puntosPromedio, horaActualDouble);
    final alturaMin = interpolarAltura(puntosMinimo, horaActualDouble);
    final alturaMax = interpolarAltura(puntosMaximo, horaActualDouble);

    // ---------------- 5) Render del gráfico ----------------
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxHeight - 40;

        // Factor de escala responsiva (ajustar si se necesita)
        double escala = constraints.maxWidth / 300;

        double yOffset(double altura) {
          return ((maxY - altura) / (maxY - minY)) * chartHeight;
        }

        // Etiquetas flotantes con posicionamiento inteligente
        Widget etiqueta(String texto, double top) {
          final textStyle = TextStyle(
            fontSize: 12 * escala,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            color: tema.textoEtiqueta,
          );

          final textPainter = TextPainter(
            text: TextSpan(text: texto, style: textStyle),
            maxLines: 1,
            textDirection: ui.TextDirection.ltr,
          )..layout();

          final double anchoTexto = textPainter.width + 8 * escala;
          final double xLinea = (horaActualDouble / 24) * constraints.maxWidth;
          final double margen = 6.0 * escala;

          final bool entraDerecha = xLinea + anchoTexto + margen < constraints.maxWidth;
          final bool entraIzquierda = xLinea - anchoTexto - margen > 0;

          final double left = entraDerecha
              ? xLinea + margen
              : (entraIzquierda ? xLinea - anchoTexto - margen : margen);

          return Positioned(
            top: top,
            left: left,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4 * escala, vertical: 2 * escala),
              decoration: BoxDecoration(
                color: tema.fondo.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4 * escala),
              ),
              child: Text(texto, style: textStyle),
            ),
          );
        }

        // Stack: lienzo + etiquetas de máx/prom/mín y hora actual
        return Stack(
          children: [
            Container(
              color: tema.fondo,
              padding: EdgeInsets.only(
                left: 6 * escala,
                right: 12 * escala,
                top: 12 * escala,
                bottom: 6 * escala,
              ),
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: Column(
                children: [
                  // Título con fecha del gráfico
                  if (!esMini)
                    Text(
                      DateFormat('dd/MM/yyyy').format(fecha ?? DateTime.now()),
                      style: TextStyle(
                        fontFamily: 'PressStart',
                        fontSize: 10 * escala,
                        fontWeight: FontWeight.w500,
                        color: tema.texto,
                      ),
                    ),
                  if (!esMini) SizedBox(height: 8 * escala),

                  // Área de chart
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                        lineTouchData: LineTouchData(enabled: false),

                        // ---- Ejes y títulos ----
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45 * escala,
                              interval: 0.1,
                              getTitlesWidget: (value, meta) {
                                final esMultiploDe02 = ((value * 10).round() % 2 == 0);
                                if (!esMultiploDe02) return Container();
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 8 * escala,
                                  child: Text(
                                    "${value.toStringAsFixed(1)}m",
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 11 * escala,
                                      fontWeight: FontWeight.w500,
                                      color: tema.texto,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 2,
                              reservedSize: 30 * escala,
                              getTitlesWidget: (value, meta) {
                                final hora = value.toInt();
                                final esMultiploDe4 = hora % 4 == 0;
                                if (!esMultiploDe4) return Container();
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 10 * escala,
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
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),

                        // ---- Grid y bordes ----
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: 0.1,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            final esMultiploDe02 = ((value * 10).round() % 2 == 0);
                            return FlLine(
                              color: tema.texto.withOpacity(esMultiploDe02 ? 0.5 : 0.2),
                              strokeWidth: esMultiploDe02 ? 1.5 * escala : 0.5 * escala,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            final hora = value.toInt();
                            return FlLine(
                              color: tema.texto.withOpacity(hora % 4 == 0 ? 0.5 : 0.20),
                              strokeWidth: hora % 4 == 0 ? 1.5 * escala : 0.5 * escala,
                            );
                          },
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: tema.texto),
                        ),

                        // ---- Series: promedio, mínimo y máximo ----
                        lineBarsData: [
                          LineChartBarData(
                            spots: puntosPromedio,
                            isCurved: true,
                            color: tema.linea,
                            barWidth: 4 * escala,
                            dotData: FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: puntosMinimo,
                            isCurved: false,
                            color: tema.linea.withOpacity(0.6),
                            barWidth: 1.5 * escala,
                            // Dash responsivo
                            dashArray: [(6 * escala).toInt(), (3 * escala).toInt() ],
                            dotData: FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: puntosMaximo,
                            isCurved: false,
                            color: tema.linea.withOpacity(0.6),
                            barWidth: 1.5 * escala,
                            // Dash responsivo
                            dashArray: [(6 * escala).toInt(), (3 * escala).toInt() ],
                            dotData: FlDotData(show: false),
                          ),
                        ],

                        // ---- Línea vertical de “hora actual” ----
                        extraLinesData: ExtraLinesData(
                          verticalLines: [
                            VerticalLine(
                              x: horaActualDouble,
                              color: tema.etiqueta,
                              strokeWidth: 2 * escala,
                              dashArray: [(2 * escala).toInt(), (2 * escala).toInt()],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- Etiquetas informativas: máx/prom/mín y hora actual ----
            etiqueta("máx. ${alturaMax.toStringAsFixed(2)}m", yOffset(alturaMax)),
            etiqueta("prom. ${alturaProm.toStringAsFixed(2)}m", yOffset(alturaProm)),
            etiqueta("mín. ${alturaMin.toStringAsFixed(2)}m", yOffset(alturaMin)),
            etiqueta("${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}h", 40 * escala),
          ],
        );
      },
    );
  }
}
