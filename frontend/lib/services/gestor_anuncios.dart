// ================================================================
// Qué hace y cómo funciona
// - Muestra anuncios de AdMob sin trabar la app.
// - Usa dos formatos: bonificado (AB) e intersticial (AI).
// - Precarga anuncios en segundo plano para mostrarlos al instante
//   y que la app responda más rápido.
// Lógica básica
// 1) La UI llama a manejarInteraccion(context, accion).
// 2) Si pasó el descanso mínimo y hay internet:
//    - Alterna AB↔AI y muestra el anuncio disponible.
//    - Al cerrarlo, ejecuta la acción y vuelve a precargar.
// 3) Si no hay internet o no hay anuncio cargado, ejecuta la acción igual.
// 4) Guarda “último anuncio” y “próximo tipo” en SharedPreferences.
// 5) Observa la conectividad: al volver la conexión, limpia bloqueos y regresa a /principal.
// Configuración: IDs en anuncios_config.dart. Modo premium en app_config.dart.
// Punto de entrada: manejarInteraccion(context, accion).
// ================================================================

// frontend/mareas/lib/services/gestor_anuncios.dart

// ---------------- Variables y estado ----------------
import 'dart:async';
import 'dart:io'; // Para comprobar internet real (HttpClient)
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/anuncios_config.dart';
import '../config/app_config.dart';
import '../main.dart' show navigatorKey;

class GestorAnuncios {
  // Claves de persistencia
  static const _claveUltimoAnuncio = 'ultimo_anuncio_mostrado';
  static const _claveProximoTipo = 'ga_proximo_tipo'; // true=AB, false=AI

  // Ritmo de anuncios
  static const _minutosEntreAnuncios = 5;

  // Instancias precargadas
  static RewardedAd? _anuncioBonificado;       // AB
  static InterstitialAd? _anuncioIntersticial; // AI

  // Suscripción de conectividad
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool? _ultimoOnline; // null al inicio; se setea en inicializarAnuncios()

  // Flags de control
  static bool _sinInternetBloqueoActivo = false;
  static bool _proximoEsBonificado = true; // alterna AB -> AI -> AB ...

  // ===========================
  // Inicialización y reconexión
  // ===========================
  static Future<void> inicializarAnuncios() async {
    if (esVersionPremium) return;

    await _cargarProximoTipo();
    _ultimoOnline = await _hayConexion(); // guardar estado real al arrancar
    await _precargarBonificado();
    await _precargarIntersticial();

    // Observar cambios de conectividad y reaccionar sin bloquear UI
  _subscription = Connectivity().onConnectivityChanged.listen((results) async {
    debugPrint('📡 Cambio de conexión (raw): $results');

    final conectado = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
    final onlineReal = conectado && await _hayInternetReal();

    // Solo “restablecida” si veníamos offline y ahora hay internet real
    final seRestablecio = (_ultimoOnline == false) && onlineReal;
    _ultimoOnline = onlineReal; // actualizar memoria

    // Siempre precargar en background si hay internet (sin UI ruidosa)
    if (onlineReal) {
      _precargarBonificado();
      _precargarIntersticial();
    }

    if (!seRestablecio) return; // ⬅️ no hacer nada visual en arranque o en online→online

    // ⬇️ Solo cuando vuelve la conectividad real (offline→online)
    _sinInternetBloqueoActivo = false;

    final ctx = navigatorKey.currentState?.overlay?.context;
    if (ctx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(ctx).clearSnackBars();
        Navigator.of(ctx, rootNavigator: true)
            .pushNamedAndRemoveUntil('/principal', (route) => false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('✅ Conexión restablecida')),
        );
      });
    }
  });

  }

  // Liberar recursos de conectividad
  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  // =====================
  // Manejar interacción GA
  // =====================
  /// Punto de entrada de la UI para acciones que pueden disparar un anuncio.
  /// Política: respetar cooldown, alternar AB/AI y permitir uso si no hay ads.
  static Future<void> manejarInteraccion({
    required BuildContext context,
    required VoidCallback accion,
    bool requiereInternet = true, // reservado para casos futuros
  }) async {
    if (esVersionPremium) {
      accion();
      return;
    }

    // Si ya está bloqueado → solo avisar
    if (_sinInternetBloqueoActivo) {
      _mostrarSnackBar(context, '🙀 Sin conexión. Reintenta más tarde.');
      return;
    }

    // Estado actual
    final online = await _hayConexion();             // INTERNET real
    final cooldownActivo = await _debeEsperarOtroAnuncio();
    final hayAB = _anuncioBonificado != null;
    final hayAI = _anuncioIntersticial != null;
    final sinAnuncios = !hayAB && !hayAI;

    // Cooldown se respeta SIEMPRE
    if (cooldownActivo) {
      accion();
      return;
    }

    // ----------------------
    // OFFLINE (sin internet)
    // Orden requerido:
    // 1) AB → 2) cooldown → 3) AI → 4) cooldown → 5) bloqueo
    // ----------------------
    if (!online) {
      if (_proximoEsBonificado && hayAB) {
        await _mostrarRewarded(context, accion);
        return;
      }
      if (!_proximoEsBonificado && hayAI) {
        await _mostrarInterstitial(context, accion);
        return;
      }
      if (hayAB) {
        await _mostrarRewarded(context, accion);
        return;
      }
      if (hayAI) {
        await _mostrarInterstitial(context, accion);
        return;
      }

      // Sin internet + sin precargados → bloquear inmediatamente
      _activarBloqueo(context);
      return;
    }

    // -------------------
    // ONLINE (con internet)
    // Alternar con fallback al disponible
    // -------------------
    if (_proximoEsBonificado && hayAB) {
      await _mostrarRewarded(context, accion);
      return;
    }
    if (!_proximoEsBonificado && hayAI) {
      await _mostrarInterstitial(context, accion);
      return;
    }
    if (hayAB) {
      await _mostrarRewarded(context, accion);
      return;
    }
    if (hayAI) {
      await _mostrarInterstitial(context, accion);
      return;
    }

    // Sin anuncios cargados → permitir uso
    accion();
  }

  // ===========================================
  // Mostrar anuncios (registrar cooldown + alternar)
  // ===========================================
  static Future<void> _mostrarRewarded(
    BuildContext context,
    VoidCallback accion,
  ) async {
    final ad = _anuncioBonificado!;
    _anuncioBonificado = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        await _registrarAnuncioMostrado();      // activa cooldown
        await _guardarProximoTipo(false);       // siguiente = AI
        accion();
        await _precargarBonificado();           // recargar en background
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        ad.dispose();
        // No alternar ni registrar cooldown si no se mostró
        accion();
        await _precargarBonificado();
      },
    );

    ad.show(onUserEarnedReward: (_, __) {});
  }

  static Future<void> _mostrarInterstitial(
    BuildContext context,
    VoidCallback accion,
  ) async {
    final ad = _anuncioIntersticial!;
    _anuncioIntersticial = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        await _registrarAnuncioMostrado();      // activa cooldown
        await _guardarProximoTipo(true);        // siguiente = AB
        accion();
        await _precargarIntersticial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        ad.dispose();
        // No alternar ni registrar cooldown si no se mostró
        accion();
        await _precargarIntersticial();
      },
    );

    ad.show();
  }

  // ====================
  // Bloqueo sin conexión
  // ====================
  /// Activar bloqueo temporal por falta de internet y guiar a la pantalla principal.
  static void _activarBloqueo(BuildContext context) {
    _sinInternetBloqueoActivo = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _volverPantallaPrincipal(context);
      Future.delayed(const Duration(milliseconds: 150), () {
        _mostrarSnackBar(context, '🙀 Ups! Se necesita conexión a internet');
      });
    });
  }

  // ===================
  // Precarga de anuncios
  // ===================
  static Future<void> _precargarBonificado() async {
    if (!await _hayInternetReal()) return;
    RewardedAd.load(
      adUnitId: anuncioBonificadoId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _anuncioBonificado = ad;
          debugPrint('✅ AB precargado');
        },
        onAdFailedToLoad: (error) {
          _anuncioBonificado = null;
          debugPrint('❌ Falló precarga AB: $error');
        },
      ),
    );
  }

  static Future<void> _precargarIntersticial() async {
    if (!await _hayInternetReal()) return;
    InterstitialAd.load(
      adUnitId: anuncioIntersticialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _anuncioIntersticial = ad;
          debugPrint('✅ AI precargado');
        },
        onAdFailedToLoad: (error) {
          _anuncioIntersticial = null;
          debugPrint('❌ Falló precarga AI: $error');
        },
      ),
    );
  }

  // =====================
  // Utilidades y cooldown
  // =====================

  // Comprobar internet REAL (no solo adaptador conectado)
  static Future<bool> _hayInternetReal() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final req = await client
          .getUrl(Uri.parse('https://clients3.google.com/generate_204'))
          .timeout(const Duration(seconds: 2));
      final resp = await req.close().timeout(const Duration(seconds: 2));
      return resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // Conectividad efectiva: red disponible + salida real a internet
  static Future<bool> _hayConexion() async {
    try {
      final raw = await Connectivity().checkConnectivity();
      if (raw == ConnectivityResult.none) return false;
      // Confirmar salida a internet con un endpoint liviano
      return await _hayInternetReal();
    } catch (_) {
      return false;
    }
  }

  // UI helpers
  static void _mostrarSnackBar(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontFamily: 'PressStart', fontSize: 10),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Registrar timestamp del último anuncio mostrado
  static Future<void> _registrarAnuncioMostrado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_claveUltimoAnuncio, DateTime.now().millisecondsSinceEpoch);
  }

  // Verificar cooldown de anuncios
  static Future<bool> _debeEsperarOtroAnuncio() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimo = prefs.getInt(_claveUltimoAnuncio);
    if (ultimo == null) return false;
    final minutos = (DateTime.now().millisecondsSinceEpoch - ultimo) / 1000 / 60;
    return minutos < _minutosEntreAnuncios;
  }

  // Alternancia AB/AI persistente
  static Future<void> _cargarProximoTipo() async {
    final prefs = await SharedPreferences.getInstance();
    _proximoEsBonificado = prefs.getBool(_claveProximoTipo) ?? true;
  }

  static Future<void> _guardarProximoTipo(bool esBonificado) async {
    _proximoEsBonificado = esBonificado;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveProximoTipo, esBonificado);
  }

  // Redirigir a la pantalla inicial real (home: PantallaMarea)
  static void _volverPantallaPrincipal(BuildContext context) {
    // Limpiar pila de navegación y dejar la principal al tope
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/principal', (route) => false);
  }
}
