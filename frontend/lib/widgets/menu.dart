// ================================================================
// Menú de ajustes — resumen
// Qué hace:
// - Dialog con ajustes de tema, banners de notificaciones y sección Pro.
// - Lee y persiste preferencias en SharedPreferences.
// - Integra TemaProvider y NotificacionesProvider.
// - Pasa acciones por GestorAnuncios; abre enlaces externos.
// Uso: showDialog(context: ..., builder: (_) => const MenuAjustes()).
// Seguridad: sin llaves ni credenciales; URLs provienen del backend/app.
// ================================================================

// frontend/mareas/lib/widgets/menu.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_mareas/theme/tema_visual.dart';
import 'package:app_mareas/utils/momento_actual.dart';
import '../providers/tema_provider.dart';
import 'package:app_mareas/services/gestor_anuncios.dart';
import 'package:app_mareas/config/app_config.dart';
import 'notificacion.dart';
import '../providers/notificaciones_provider.dart';

class MenuAjustes extends StatefulWidget {
  const MenuAjustes({super.key});

  @override
  State<MenuAjustes> createState() => _MenuAjustesState();
}

class _MenuAjustesState extends State<MenuAjustes> {
  // ---------------- Estado UI ----------------
  bool modoAutomatico = true;
  MomentoDelDia temaManual = MomentoDelDia.dia;
  bool cargando = true;
  bool _interaccionEnCurso = false;

  // ---------------- Ciclo de vida ----------------
  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final auto = prefs.getBool('modoAutomatico') ?? true;
    final temaString = prefs.getString('temaManual') ?? 'dia';

    final manual = esVersionPremium
        ? MomentoDelDia.values.firstWhere(
            (e) => e.name == temaString,
            orElse: () => MomentoDelDia.dia,
          )
        : MomentoDelDia.dia;

    final provider = Provider.of<TemaProvider>(context, listen: false);
    provider.toggleAutomatico(auto);
    provider.cambiarMomento(manual);

    setState(() {
      modoAutomatico = auto;
      temaManual = manual;
      cargando = false;
    });
  }

  void _marcarNotificacionComoLeida(String clave) {
    final notiProvider = Provider.of<NotificacionesProvider>(context, listen: false);
    notiProvider.marcarComoLeida(clave);
  }

  // ---------------- Render ----------------
  @override
  Widget build(BuildContext context) {
    final temaProvider = Provider.of<TemaProvider>(context);
    final notiProvider = Provider.of<NotificacionesProvider>(context);
    final tema = temaProvider.tema;
    final ancho = MediaQuery.of(context).size.width;
    final notificaciones = context.watch<NotificacionesProvider>().notificaciones;

    if (cargando) {
      return Dialog(
        backgroundColor: tema.relleno,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Dialog(
      backgroundColor: tema.relleno,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tema.borde, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------- Banners de notificaciones ----------------
              ...notificaciones.map((noti) => MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('hayNotificacionMenu', false);

                        final url = noti['url'];
                        if (url != null && url.isNotEmpty) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      child: NotificacionBanner(
                        titulo: noti['titulo']!,
                        cuerpo: noti['cuerpo']!,
                        onCerrar: () => _marcarNotificacionComoLeida(noti['clave']!),
                      ),
                    ),
                  )),

              const SizedBox(height: 20),

              // ---------------- Título y separación ----------------
              Text(
                'MENÚ',
                style: TextStyle(
                  fontFamily: 'PressStart',
                  fontSize: ancho * 0.035,
                  color: tema.texto,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Divider(color: tema.borde.withOpacity(0.4), thickness: 1),
              const SizedBox(height: 16),

              // ---------------- Ajustes visuales ----------------
              Text(
                'AJUSTES VISUALES',
                style: TextStyle(
                  fontFamily: 'PressStart',
                  fontSize: ancho * 0.025,
                  color: tema.texto.withOpacity(0.9),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Cambio automático',
                  style: TextStyle(
                    fontFamily: 'PressStart',
                    fontSize: ancho * 0.025,
                    color: tema.texto,
                  ),
                ),
                value: modoAutomatico,
                activeColor: tema.texto,
                onChanged: (val) async {
                  if (_interaccionEnCurso) return;
                  _interaccionEnCurso = true;

                  await GestorAnuncios.manejarInteraccion(
                    context: context,
                    accion: () {
                      setState(() {
                        modoAutomatico = val;
                        if (modoAutomatico) temaManual = MomentoDelDia.dia;
                      });
                      temaProvider.toggleAutomatico(val);
                      temaProvider.cambiarMomento(temaManual);
                      _guardarPreferencias();
                    },
                    requiereInternet: true,
                  );

                  _interaccionEnCurso = false;
                },
              ),

              if (!modoAutomatico) ...[
                const SizedBox(height: 12),
                if (esVersionPremium)
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: MomentoDelDia.values.map((momento) {
                      final seleccionado = temaManual == momento;
                      return ChoiceChip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        label: Text(
                          momento.name.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'PressStart',
                            fontSize: ancho * 0.018,
                            color: seleccionado ? tema.relleno : tema.texto,
                          ),
                        ),
                        selected: seleccionado,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selectedColor: tema.texto,
                        backgroundColor: tema.borde.withOpacity(0.2),
                        onSelected: (_) {
                          setState(() {
                            temaManual = momento;
                          });
                          temaProvider.cambiarMomento(momento);
                          _guardarPreferencias();
                        },
                      );
                    }).toList(),
                  )
                else
                  Center(
                    child: Text(
                      "Tema: DÍA",
                      style: TextStyle(
                        fontFamily: 'PressStart',
                        fontSize: ancho * 0.022,
                        color: tema.texto.withOpacity(0.8),
                      ),
                    ),
                  ),
              ],

              // ---------------- Sección Mareas Pro (solo Free) ----------------
              if (!esVersionPremium) ...[
                const SizedBox(height: 30),
                Divider(color: tema.borde.withOpacity(0.4), thickness: 1),
                const SizedBox(height: 16),
                Text(
                  'MAREAS PRO',
                  style: TextStyle(
                    fontFamily: 'PressStart',
                    fontSize: ancho * 0.025,
                    color: tema.texto.withOpacity(0.9),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: tema.borde.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(10),
                    color: tema.borde.withOpacity(0.1),
                  ),
                  child: Text(
                    'Próximamente: sin anuncios, temas personalizados, alertas premium y más 🎉',
                    style: TextStyle(
                      fontFamily: 'PressStart',
                      fontSize: ancho * 0.022,
                      color: tema.texto,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    final notiProvider = Provider.of<NotificacionesProvider>(context, listen: false);
    notiProvider.marcarComoLeida('notificacion_actualizacion');
    super.dispose();
  }

  Future<void> _guardarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modoAutomatico', modoAutomatico);
    await prefs.setString('temaManual', temaManual.name);
  }
}
