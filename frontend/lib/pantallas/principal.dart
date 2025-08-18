// ================================================================
// Pantalla principal de la app.
// Qué hace:
// - Muestra la marea de HOY (gráfico compacto/expandido o tabla).
// - Permite ver PRÓXIMOS DÍAS en bloques expandibles.
// - Carga primero desde CACHÉ y luego intenta refrescar desde el backend.
// - Soporta MODO OFFLINE (usa datos guardados si no hay internet).
// - En edición FREE muestra BANNER AdMob; en PRO no.
// - Controla alternancia de vistas y scroll a secciones clave.
// Datos:
// - Pide /marea/alturas/<estación>/ y guarda en SharedPreferences.
// - Actualiza solo si pasaron >30 min desde la última actualización.
// Interacción:
// - Encabezado para elegir estación y abrir menú de ajustes.
// - Botones para alternar gráfico/tabla y expandir días futuros.
// ================================================================


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_mareas/services/gestor_anuncios.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/anuncios_config.dart';
import '../widgets/encabezado.dart';
import '../widgets/grafico_compacto.dart';
import '../widgets/grafico_expandido.dart';
import '../widgets/tabla.dart';
import '../utils/momento_actual.dart';
import '../utils/fondos_por_momento.dart';
import '../theme/tema_visual.dart';
import '../widgets/indicador_cargando.dart';
import '../config/app_config.dart'; 
import '../config/backend_config.dart'; 
import '../widgets/botones_fechas.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';
import 'dart:async';
import 'dart:io';

class PantallaMarea extends StatefulWidget {
  const PantallaMarea({super.key});

  @override
  State<PantallaMarea> createState() => _PantallaMareaState();
}

class _PantallaMareaState extends State<PantallaMarea> with WidgetsBindingObserver {
  // ---------------- Estado y control de UI ----------------
  final ScrollController _scrollController = ScrollController();
  List<dynamic> datos = [];
  String ultimaActualizacion = '';
  String estacionSeleccionada = 'san_fernando';
  final GlobalKey encabezadoKey = GlobalKey();

  // Toggles de visualización principal
  bool mostrarGraficoFuturo = false;
  bool mostrarTabla = false;

  // Estado por fecha futura
  Map<DateTime, bool> diasExpandidos = {}; 
  Map<DateTime, bool> mostrarGraficoPorFecha = {};
  Map<DateTime, bool> mostrarTablaPorFecha = {};
  final Map<DateTime, GlobalKey> clavesPorFecha = {};

  // Anuncios (solo edición free)
  late final BannerAd _bannerAd;
  bool _bannerCargado = false;
  bool _anuncioMostrandose = false;

  // Conectividad y caché
  bool _offline = false;       // sin internet real
  bool _teniaCache = false;    // había datos guardados

  // ---------------- Datos: cache + red con timeout corto ----------------
  Future<void> obtenerDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final claveDatos = 'datos_$estacionSeleccionada';
      final claveHora  = 'ultima_actualizacion_$estacionSeleccionada';

      // 1) Pintar primero desde caché (si existe)
      final datosGuardados = prefs.getString(claveDatos);
      final ultimaHora     = prefs.getString(claveHora);

      if (datosGuardados != null && ultimaHora != null) {
        setState(() {
          datos = json.decode(datosGuardados);
          ultimaActualizacion = ultimaHora;
          _teniaCache = true;
        });
      } else {
        _teniaCache = false;
      }

      // 2) Intentar refrescar online (con timeouts cortos)
      final url = Uri.parse('$backendBaseUrl/marea/alturas/$estacionSeleccionada/');
      final resp = await http.get(url).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final nuevosDatos = data['datos'] ?? [];
        if (nuevosDatos.isNotEmpty) {
          final ahora = DateTime.now().toIso8601String();
          setState(() {
            datos = nuevosDatos;
            ultimaActualizacion = ahora;
            _offline = false;
            _teniaCache = true;
          });
          await prefs.setString(claveDatos, json.encode(nuevosDatos));
          await prefs.setString(claveHora,  ahora);
        }
      } else {
        debugPrint('⚠️ Error HTTP: ${resp.statusCode}');
        setState(() => _offline = true);
      }
    } on TimeoutException {
      setState(() => _offline = true);
    } on SocketException {
      setState(() => _offline = true);
    } catch (e) {
      debugPrint('❌ Error al obtener datos: $e');
    }
  }

  // ---------------- Ciclo de vida: init, resume, dispose ----------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Inicializar banner solo en edición gratuita
    if (!esVersionPremium) {
      _bannerAd = BannerAd(
        adUnitId: bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _bannerCargado = true),
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint('❌ Error cargando banner: $error');
          },
        ),
      )..load();
    }

    // Cargar datos sin limpiar estado para mostrar caché al instante
    Future.delayed(const Duration(milliseconds: 100), () async {
      await obtenerDatos();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver al foreground, refrescar si pasaron >30 min
    if (state == AppLifecycleState.resumed) {
      final ahora = DateTime.now();
      final horaUltima = DateTime.tryParse(ultimaActualizacion);
      if (horaUltima == null || ahora.difference(horaUltima).inMinutes > 30) {
        obtenerDatos();
      }
    }
  }

  void scrollAlEncabezado() {
    if (encabezadoKey.currentContext != null) {
      Scrollable.ensureVisible(
        encabezadoKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!esVersionPremium) {
      _bannerAd.dispose();
    }
    super.dispose();
  }

  // ---------------- UI: composición principal ----------------
  @override
  Widget build(BuildContext context) {
    final temaProvider = Provider.of<TemaProvider>(context);
    final tema = temaProvider.tema;
    final momento = temaProvider.momentoActual;
    final hoy = DateTime.now();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(obtenerFondoPorMomento(momento)),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
        child: datos.isEmpty
            ? (_offline && !_teniaCache
                // Estado: sin conexión y sin cache previa
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Sin conexión y sin datos guardados.\nConéctate al menos una vez para cargar datos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'PressStart', fontSize: 10, color: Colors.white),
                      ),
                    ),
                  )
                // Estado: cargando datos (o mostrando cache previa)
                : const Center(child: IndicadorCargando()))
            : LayoutBuilder(

                  builder: (context, constraints) {
                    // Calcular alturas disponibles para el contenedor principal
                    final pantallaTotal = constraints.maxHeight;
                    final renderEncabezado = encabezadoKey.currentContext?.findRenderObject() as RenderBox?;
                    final alturaEncabezado = renderEncabezado?.size.height ?? 200;
                    final alturaBanner = (!esVersionPremium && _bannerCargado) ? _bannerAd.size.height.toDouble() : 0;
                    final alturaActualizacion = 30.0;
                    final alturaPieInferior = alturaBanner + alturaActualizacion + 20.0;
                    final alturaDisponible = pantallaTotal - alturaEncabezado - alturaPieInferior;

                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Encabezado: selección de estación y momento del día
                          EncabezadoPixelado(
                            key: encabezadoKey,
                            estacionSeleccionada: estacionSeleccionada,
                            onEstacionSeleccionada: (nueva) {
                              setState(() {
                                estacionSeleccionada = nueva;
                                datos = [];
                              });
                              obtenerDatos();
                            },
                            momento: obtenerMomentoDelDia(),
                          ),

                          const SizedBox(height: 10),

                          // Aviso: modo sin conexión mostrando caché
                          if (_offline)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Modo sin conexión: mostrando datos guardados',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontFamily: 'PressStart', fontSize: 8, color: Colors.white),
                                ),
                              ),
                            ),

                          // Contenedor principal: gráfico compacto / expandido o tabla
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  constraints: BoxConstraints(
                                    minHeight: alturaDisponible.clamp(300.0, pantallaTotal * 0.65),
                                    maxHeight: alturaDisponible.clamp(300.0, pantallaTotal * 0.65),
                                  ),
                                  width: double.infinity,
                                  
                                  child: mostrarTabla
                                      ? SingleChildScrollView(child: TablaMareaHoy(datos: datos, fecha: hoy))
                                      : mostrarGraficoFuturo
                                          ? GraficoExpandido(datos: datos, fecha: hoy)
                                          : GraficoMareaCompacto(datos: datos, fecha: hoy),
                                ),
                                const SizedBox(height: 6),

                          // Acciones: alternar gráfico expandido / tabla
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(
                                  mostrarGraficoFuturo ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: tema.texto,
                                ),
                                iconSize: 25,
                                visualDensity: const VisualDensity(horizontal: 0.0, vertical: -4.0),
                                onPressed: () {
                                  if (_anuncioMostrandose) return;
                                  _anuncioMostrandose = true;

                                  GestorAnuncios.manejarInteraccion(
                                    context: context,
                                    accion: () {
                                      setState(() {
                                        mostrarGraficoFuturo = !mostrarGraficoFuturo;
                                        mostrarTabla = false;
                                      });
                                      _anuncioMostrandose = false;
                                    },
                                    requiereInternet: true,
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  mostrarTabla ? Icons.show_chart : Icons.table_chart,
                                  color: tema.texto,
                                ),
                                iconSize: 25,
                                visualDensity: const VisualDensity(horizontal: 0.0, vertical: -4.0),
                                onPressed: () {
                                  if (_anuncioMostrandose) return;
                                  _anuncioMostrandose = true;

                                  GestorAnuncios.manejarInteraccion(
                                    context: context,
                                    accion: () {
                                      setState(() {
                                        mostrarTabla = !mostrarTabla;
                                      });
                                      _anuncioMostrandose = false;
                                    },
                                    requiereInternet: true,
                                  );
                                },
                              ),
                            ],
                          ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

// ⬇️ Aca va el banner
if (!esVersionPremium && _bannerCargado)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Container(
      alignment: Alignment.center,
      width: _bannerAd.size.width.toDouble(),
      height: _bannerAd.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd),
    ),
  ),

    // Próximos dos días: bloques expandibles con gráfico/tabla
    ...List.generate(2, (i) {
  final fecha = DateTime(hoy.year, hoy.month, hoy.day + i + 1);
  final expandido = diasExpandidos[fecha] ?? false;
  final mostrarGrafico = mostrarGraficoPorFecha[fecha] ?? false;
  final mostrarTabla = mostrarTablaPorFecha[fecha] ?? false;

  clavesPorFecha.putIfAbsent(fecha, () => GlobalKey());

  return BotonFechaExpandable(
    fecha: fecha,
    expandido: expandido,
    datos: datos,
    mostrarGraficoExpandido: mostrarGrafico,
    mostrarTabla: mostrarTabla,
    alturaDisponible: alturaDisponible,
    contenedorKey: clavesPorFecha[fecha],

    onTap: () {
      if (_anuncioMostrandose) return;
      _anuncioMostrandose = true;

      GestorAnuncios.manejarInteraccion(
        context: context,
        accion: () {
          setState(() {
            diasExpandidos[fecha] = !expandido;
          });

          Future.delayed(const Duration(milliseconds: 250), () {
            final contextDestino = expandido
                ? encabezadoKey.currentContext
                : clavesPorFecha[fecha]?.currentContext;

            if (contextDestino != null) {
              Scrollable.ensureVisible(
                contextDestino,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                alignment: expandido ? 0 : 0.2,
              );
            }

            _anuncioMostrandose = false;
          });
        },
        requiereInternet: true,
      );
    },

    onToggleGrafico: () {
      if (_anuncioMostrandose) return;
      _anuncioMostrandose = true;

      GestorAnuncios.manejarInteraccion(
        context: context,
        accion: () {
          setState(() {
            mostrarGraficoPorFecha[fecha] = !mostrarGrafico;
            mostrarTablaPorFecha[fecha] = false;
          });
          _anuncioMostrandose = false;
        },
        requiereInternet: true,
      );
    },

    onToggleTabla: () {
      if (_anuncioMostrandose) return;
      _anuncioMostrandose = true;

      GestorAnuncios.manejarInteraccion(
        context: context,
        accion: () {
          setState(() {
            mostrarTablaPorFecha[fecha] = !mostrarTabla;
          });
          _anuncioMostrandose = false;
        },
        requiereInternet: true,
      );
    },
  );
}),


                          const SizedBox(height: 12),

                          // Leyenda de fuente y última actualización mostrada
                          Text(
                            "Datos extraídos del INA ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(ultimaActualizacion) ?? DateTime.now())}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PressStart',
                              fontSize: 8,
                              color: tema.texto,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
