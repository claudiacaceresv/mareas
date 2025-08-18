// ================================================================
// Main — resumen
// Qué hace: punto de entrada. Fija flavor (free|pro), inicializa Firebase,
// permisos y canales de notificación, maneja FCM en todos los estados,
// bloquea orientación, arranca Providers e inicializa anuncios en background.
// Cómo funciona: lee --dart-define=FLAVOR, configura listeners de FCM
// (foreground/background/initial), crea canal local Android y usa navigatorKey.
// Uso: flutter run --dart-define=FLAVOR=free|pro
// ================================================================

// frontend/mareas/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';

import 'app.dart';
import 'flavors.dart';
import 'providers/tema_provider.dart';
import 'notificaciones/manejador_notificaciones.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'providers/notificaciones_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'services/gestor_anuncios.dart';

// ------------------------------------------------------------
// Navegación global
// - Usar para obtener context fuera del árbol de widgets.
// ------------------------------------------------------------
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ----------------------------------------------------------
  // Flavor
  // - Leer --dart-define=FLAVOR al compilar: "free" | "pro".
  // ----------------------------------------------------------
  const flavor = String.fromEnvironment('FLAVOR');
  F.appFlavor = Flavor.values.firstWhere(
    (f) => f.name == flavor,
    orElse: () => Flavor.free,
  );

  // ----------------------------------------------------------
  // Firebase
  // - Inicializar core y pedir permisos de notificaciones.
  // ----------------------------------------------------------
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission();

  // ----------------------------------------------------------
  // FCM: token y suscripción a topic del flavor
  // - Usar timeouts cortos para no bloquear sin red.
  // ----------------------------------------------------------
  try {
    final token = await FirebaseMessaging.instance
        .getToken()
        .timeout(const Duration(seconds: 2));
    print('🔑 Token FCM: $token');
  } catch (_) {
    print('🔑 Token FCM: sin red (se intentará luego)');
  }

  try {
    await FirebaseMessaging.instance
        .subscribeToTopic(F.appFlavor.name)
        .timeout(const Duration(seconds: 2));
    print('📌 Suscripto al topic: ${F.appFlavor.name}');
  } catch (_) {
    print('📌 Suscripción diferida: sin red (reintentaré luego)');
  }

  // ----------------------------------------------------------
  // Canal de notificaciones locales (Android)
  // - Definir importancia, sonido y badge.
  // ----------------------------------------------------------
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_channel_id',
    'Canal por defecto',
    description: 'Este canal se usa para notificaciones generales',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('chipap'),
    showBadge: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ----------------------------------------------------------
  // Inicializar plugin local y manejar taps en notificaciones locales
  // - Si es flavor free y tipo=actualizacion, abrir URL externa.
  // ----------------------------------------------------------
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payloadStr = response.payload ?? '';
      try {
        final payload = jsonDecode(payloadStr);
        final tipo = payload['tipo'];
        final url = payload['url'];

        print('🎯 Notificación clickeada. Tipo: $tipo | URL: $url');

        if (F.appFlavor == Flavor.free && tipo == 'actualizacion' && url != null) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } catch (e) {
        print('❌ Error al procesar payload: $e');
      }
    },
  );

  // Crear canal en Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // ----------------------------------------------------------
  // FCM Foreground
  // - Mostrar notificación local y delegar en ManejadorNotificaciones.
  // ----------------------------------------------------------
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('📩 [Foreground] Notificación recibida: ${message.messageId}');
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_notification',                 // sin extensión
            sound: RawResourceAndroidNotificationSound('chipap'), // sin extensión
          ),
        ),
        payload: jsonEncode({
          'tipo': message.data['tipo'],
          'url': message.data['url'],
        }),
      );
    }

    await ManejadorNotificaciones.manejar(message);
  });

  // ----------------------------------------------------------
  // FCM: notificación que abrió la app cerrada
  // - Procesar payload, rehidratar provider y manejar tap.
  // ----------------------------------------------------------
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('🚀 Notificación abierta desde app cerrada');
    await ManejadorNotificaciones.manejar(initialMessage);

    final context = navigatorKey.currentState?.overlay?.context;
    if (context != null) {
      // esperar montaje de widgets antes de notificar
      await Future.delayed(const Duration(milliseconds: 500));
      await Provider.of<NotificacionesProvider>(context, listen: false)
          .cargarDesdePreferencias();
    }

    await _handleNotificationTap(initialMessage);
  }

  // ----------------------------------------------------------
  // FCM Background
  // - Registrar handler para mensajes en segundo plano.
  // ----------------------------------------------------------
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // ----------------------------------------------------------
  // UI: orientación
  // - Restringir a portrait up/down.
  // ----------------------------------------------------------
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ----------------------------------------------------------
  // FCM: app traída al frente por una notificación
  // - Delegar en manejador y refrescar provider tras montar UI.
  // ----------------------------------------------------------
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    print('📨 onMessageOpenedApp: ${message.data}');
    await ManejadorNotificaciones.manejar(message);

    final context = navigatorKey.currentState?.context;
    if (context != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      await Provider.of<NotificacionesProvider>(context, listen: false)
          .cargarDesdePreferencias();
    }
  });

  // ----------------------------------------------------------
  // Anuncios
  // - Inicializar en background; no bloquear arranque.
  // ----------------------------------------------------------
  GestorAnuncios.inicializarAnuncios(); // sin await

  // ----------------------------------------------------------
  // Árbol de Providers y arranque de la app
  // - TemaProvider: persistir y aplicar tema.
  // - NotificacionesProvider: hidratar badges y banners.
  // ----------------------------------------------------------
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TemaProvider()..cargarDesdePreferencias(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificacionesProvider()..cargarDesdePreferencias(),
        ),
      ],
      child: const App(),
    ),
  );
}

// ------------------------------------------------------------
// Handler background FCM
// - Inicializar Firebase y delegar en manejador.
// ------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 [Background] Notificación: ${message.messageId}');
  await ManejadorNotificaciones.manejar(message);
}

// ------------------------------------------------------------
// Manejar tap según tipo (caso free + actualizacion abre URL)
// ------------------------------------------------------------
Future<void> _handleNotificationTap(RemoteMessage message) async {
  final tipo = message.data['tipo'];
  final url = message.data['url'];

  if (F.appFlavor == Flavor.free && tipo == 'actualizacion' && url != null) {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
