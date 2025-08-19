// ================================================================
// Encabezado de la app — qué hace y lógica
// - Muestra estación actual, badge de notificaciones y menú de ajustes.
// - Carga estaciones desde el backend al iniciar y permite cambiar estación.
// - Usa TemaVisual para colores e ícono según momento del día.
//   <REEMPLAZAR: BACKEND_BASE_URL>
// ================================================================

// frontend/mareas/lib/widgets/encabezado.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_mareas/theme/tema_visual.dart';
import 'package:app_mareas/utils/momento_actual.dart';
import 'package:app_mareas/config/estaciones_config.dart';
import 'menu.dart';
import 'package:app_mareas/services/gestor_anuncios.dart';
import 'package:provider/provider.dart';
import '../providers/notificaciones_provider.dart';

class EncabezadoPixelado extends StatefulWidget {
  // Props de control: estación actual, callback y momento del día.
  final String estacionSeleccionada;
  final Function(String) onEstacionSeleccionada;
  final MomentoDelDia momento;

  const EncabezadoPixelado({
    super.key,
    required this.estacionSeleccionada,
    required this.onEstacionSeleccionada,
    required this.momento,
  });

  @override
  State<EncabezadoPixelado> createState() => _EncabezadoPixeladoState();
}

class _EncabezadoPixeladoState extends State<EncabezadoPixelado> {
  // Estado local: catálogo de estaciones y visibilidad del desplegable.
  List<Map<String, dynamic>> estaciones = [];
  bool _mostrarLista = false;

  // Inicializar: cargar estaciones desde API.
  @override
  void initState() {
    super.initState();
    _cargarEstaciones();
  }

  // Obtener listado de estaciones desde backend y poblar estado.
  Future<void> _cargarEstaciones() async {
    try {
      final url = Uri.parse('<REEMPLAZAR: BACKEND_BASE_URL>/marea/estaciones/');
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          setState(() {
            estaciones = List<Map<String, dynamic>>.from(data);
          });
        }
      } else {
        debugPrint("❌ Error al cargar estaciones: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error de conexión al obtener estaciones: $e");
    }
  }

  // Construir encabezado: icono, nombre de estación, toggle de lista y engranaje con badge.
  @override
  Widget build(BuildContext context) {
    final tema = obtenerTemaVisual(context);
    final anchoPantalla = MediaQuery.of(context).size.width;

    // Estado del badge de notificaciones desde Provider.
    final notiProvider = Provider.of<NotificacionesProvider>(context);
    final hayNotificacionMenu = notiProvider.hayNotificacionMenu;

    return Column(
      children: [
        // ---------- Barra superior ----------
        AnimatedContainer(
          duration: const Duration(milliseconds: 1000),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: tema.relleno,
            border: Border.all(color: tema.borde),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: tema.sombra.withOpacity(0.4),
                offset: const Offset(2, 2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icono según momento del día.
              Image.asset(tema.icono, height: anchoPantalla * 0.08),
              const SizedBox(width: 10),

              // Nombre de la estación actual o “Cargando...”.
              Expanded(
                child: estaciones.isEmpty
                    ? Text(
                        'Cargando...',
                        style: TextStyle(
                          fontFamily: 'PressStart',
                          fontSize: anchoPantalla * 0.025,
                          color: Colors.white,
                        ),
                      )
                    : GestureDetector(
                        onTap: () {
                          setState(() => _mostrarLista = !_mostrarLista);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              _nombreEstacion(widget.estacionSeleccionada),
                              style: TextStyle(
                                fontFamily: 'PressStart',
                                fontSize: anchoPantalla * 0.03,
                                color: tema.texto,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _mostrarLista ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              color: tema.texto,
                              size: anchoPantalla * 0.06,
                            ),
                          ],
                        ),
                      ),
              ),

              // Engranaje + badge de notificaciones.
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.settings, color: tema.texto),
                    iconSize: anchoPantalla * 0.065,
                    onPressed: () async {
                      // Refrescar provider antes de abrir el menú.
                      await Provider.of<NotificacionesProvider>(context, listen: false).cargarDesdePreferencias();

                      // Pasar por gestor de anuncios y abrir menú.
                      GestorAnuncios.manejarInteraccion(
                        context: context,
                        accion: () {
                          showDialog(
                            context: context,
                            builder: (context) => const MenuAjustes(),
                          );
                        },
                        requiereInternet: true, 
                      );
                    },
                  ),
                  if (hayNotificacionMenu)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ---------- Lista desplegable de estaciones ----------
        if (_mostrarLista)
          Container(
            decoration: BoxDecoration(
              color: tema.relleno,
              border: Border.all(color: tema.borde),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: tema.sombra.withOpacity(0.3),
                  offset: const Offset(2, 2),
                  blurRadius: 2,
                ),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 4),
            child: Column(
              children: estaciones.map((e) {
                final id = e['id'];
                final nombre = e['nombre'];
                final habilitada = estacionesHabilitadas.contains(id);

                return GestureDetector(
                  onTap: habilitada
                      ? () {
                          GestorAnuncios.manejarInteraccion(
                            context: context,
                            accion: () {
                              widget.onEstacionSeleccionada(id);
                              setState(() => _mostrarLista = false);
                            },
                            requiereInternet: true, 
                          );
                        }
                      : null,
                  child: Container(
                    height: anchoPantalla * 0.1,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: habilitada ? Colors.transparent : Colors.grey.withOpacity(0.2),
                    child: Text(
                      nombre,
                      style: TextStyle(
                        fontFamily: 'PressStart',
                        fontSize: anchoPantalla * 0.025,
                        color: habilitada ? tema.texto : Colors.grey,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // Resolver nombre amigable de estación a partir del id.
  String _nombreEstacion(String id) {
    final match = estaciones.firstWhere(
      (e) => e['id'] == id,
      orElse: () => {'nombre': id},
    );
    return match['nombre'];
  }
}
