// ================================================================
// App raíz — resumen
// Qué hace: inicializa MaterialApp, observa el ciclo de vida y rehidrata
//           notificaciones al volver a primer plano.
// Cómo funciona: implementa WidgetsBindingObserver, recarga
// NotificacionesProvider en estado resumed, expone navigatorKey global,
// define rutas y muestra banner de flavor en builds no release.
// Uso: runApp(const App()).
// ================================================================

// frontend/mareas/lib/app.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'flavors.dart';
import 'main.dart';
import 'pantallas/principal.dart';
import 'notificaciones/manejador_notificaciones.dart';
import 'providers/notificaciones_provider.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  // ----------------------------------------------------------
  // Ciclo de vida: registrar y remover observer
  // ----------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // observar cambios de estado
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ----------------------------------------------------------
  // Reacción a cambios de estado de la app
  // - Al reanudar, recargar notificaciones persistidas para el menú
  // ----------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      print('📲 App reanudada, recargando notificaciones desde SharedPreferences');
      final context = navigatorKey.currentState?.overlay?.context;
      if (context != null) {
        // dar tiempo a montar widgets antes de notificar
        await Future.delayed(const Duration(milliseconds: 500));
        await Provider.of<NotificacionesProvider>(context, listen: false).cargarDesdePreferencias();
      }
    }
  }

  // ----------------------------------------------------------
  // MaterialApp: navegación, tema básico, home y rutas
  // - builder agrega banner de flavor en modo no release
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Mareas',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PantallaMarea(),
      routes: {
        '/principal': (_) => const PantallaMarea(),
      },
      builder: (context, child) {
        return _flavorBanner(
          child: child!,
          show: !kReleaseMode,
        );
      },
    );
  }

  // ----------------------------------------------------------
  // Banner de “flavor” para entornos de desarrollo
  // - Mostrar nombre del flavor en un Banner superior
  // ----------------------------------------------------------
  Widget _flavorBanner({required Widget child, bool show = true}) => show
      ? Banner(
          location: BannerLocation.topStart,
          message: F.name,
          color: Colors.green.withAlpha(150),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.0,
            letterSpacing: 1.0,
          ),
          textDirection: TextDirection.ltr,
          child: child,
        )
      : child;
}
