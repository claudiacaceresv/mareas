// ================================================================
// Botón por fecha — qué hace y lógica
// - Muestra un encabezado con la fecha y permite expandir contenido.
// - Al expandir: renderiza gráfico compacto, gráfico expandido o tabla.
// - Sin estado interno: recibe flags y callbacks del padre.
// - Responsivo: paddings/tamaños según ancho/alto de pantalla.
// - Usa TemaProvider para colores de la paleta activa.
// Uso: crear uno por fecha y pasar onTap/onToggle… y datos.
// ================================================================

// frontend/mareas/lib/widgets/botones_fechas.dart


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'grafico_compacto.dart';
import 'grafico_expandido.dart';
import 'tabla.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';

class BotonFechaExpandable extends StatelessWidget {
  // ---------------- Props obligatorias ----------------
  final DateTime fecha;                   // fecha a mostrar y para filtrar datos
  final bool expandido;                   // estado visual expandido/colapsado
  final VoidCallback onTap;               // callback al tocar encabezado
  final List<dynamic> datos;              // dataset bruto del día correspondiente
  final bool mostrarGraficoExpandido;     // alternar entre gráfico compacto/expandido
  final bool mostrarTabla;                // alternar tabla vs gráfico
  final void Function() onToggleGrafico;  // acción para cambiar modo de gráfico
  final void Function() onToggleTabla;    // acción para cambiar a tabla
  final double alturaDisponible;          // altura máxima del contenedor interno
  final GlobalKey? contenedorKey;         // key para scroll/ensureVisible

  const BotonFechaExpandable({
    Key? key,
    required this.fecha,
    required this.expandido,
    required this.onTap,
    required this.datos,
    required this.mostrarGraficoExpandido,
    required this.mostrarTabla,
    required this.onToggleGrafico,
    required this.onToggleTabla,
    required this.alturaDisponible,
    this.contenedorKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ---------------- Contexto y medidas responsivas ----------------
    final tema = Provider.of<TemaProvider>(context).tema;
    final ancho = MediaQuery.of(context).size.width;
    final alto = MediaQuery.of(context).size.height;
    final padding = ancho * 0.04;
    final fontSize = ancho * 0.028;

    // ---------------- Estructura: encabezado + detalle expandible ----------------
    return Column(
      key: contenedorKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------- Encabezado clickeable ----------
        GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: alto * 0.014),
            decoration: BoxDecoration(
              color: tema.relleno,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: tema.borde,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: tema.sombra.withOpacity(0.3),
                  offset: const Offset(2, 2),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fecha formateada
                Text(
                  DateFormat('dd/MM/yyyy').format(fecha),
                  style: TextStyle(
                    fontFamily: 'PressStart',
                    fontSize: fontSize,
                    letterSpacing: 1.2,
                    color: tema.texto,
                  ),
                ),
                // Indicador expandir/colapsar
                Icon(
                  expandido ? Icons.expand_less : Icons.expand_more,
                  color: tema.texto,
                  size: fontSize + 6,
                ),
              ],
            ),
          ),
        ),

        // ---------- Contenido expandible ----------
        if (expandido)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tema.relleno.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tema.borde.withOpacity(0.2), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vista principal: gráfico compacto/expandido o tabla
                SizedBox(
                  height: alturaDisponible.clamp(300.0, MediaQuery.of(context).size.height * 0.65),
                  child: mostrarTabla
                      ? SingleChildScrollView(child: TablaMareaHoy(datos: datos, fecha: fecha))
                      : mostrarGraficoExpandido
                          ? GraficoExpandido(datos: datos, fecha: fecha)
                          : GraficoMareaCompacto(datos: datos, fecha: fecha),
                ),
                const SizedBox(height: 6),

                // Acciones: alternar modo gráfico/tabla
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        mostrarGraficoExpandido ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: tema.texto,
                      ),
                      iconSize: 25,
                      visualDensity: const VisualDensity(horizontal: 0.0, vertical: -4.0),
                      onPressed: onToggleGrafico,
                    ),
                    IconButton(
                      icon: Icon(
                        mostrarTabla ? Icons.show_chart : Icons.table_chart,
                        color: tema.texto,
                      ),
                      iconSize: 25,
                      visualDensity: const VisualDensity(horizontal: 0.0, vertical: -4.0),
                      onPressed: onToggleTabla,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
