// ==========================================================
// DOCYA PACIENTE – MAIN FINAL 2025 (CORREGIDO)
// iOS + Android 100% Compatible
// ==========================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';

// Navegación global
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Android local notifications ONLY
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ==========================================================
// 🔥 BACKGROUND HANDLER (NO UI, NO LOCAL iOS)
// ==========================================================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint("📩 BACKGROUND PUSH: ${message.data}");

  // ⚠️ iOS: el sistema ya muestra la notificación
  if (!Platform.isAndroid) return;

  if (message.data["tipo"] == "nuevo_mensaje") {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "Nuevo mensaje",
      message.data["mensaje"] ?? "",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel_id',
          'Notificaciones DocYa',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alerta'),
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

// ==========================================================
// MAIN
// ==========================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  // Canal SOLO Android
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        'default_channel_id',
        'Notificaciones DocYa',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alerta'),
      ),
    );
  }

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      if (resp.payload == null) return;
      final data = jsonDecode(resp.payload!);

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            consultaId: int.parse(data["consulta_id"]),
            remitenteTipo: "paciente",
            remitenteId: data["remitente_id"],
          ),
        ),
      );
    },
  );

  runApp(const DocYaApp());
}

// ==========================================================
// APP
// ==========================================================
class DocYaApp extends StatefulWidget {
  const DocYaApp({super.key});

  @override
  State<DocYaApp> createState() => _DocYaAppState();
}

class _DocYaAppState extends State<DocYaApp> {
  bool darkMode = true;
  bool _handledInitialPush = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _pedirPermisos();
    _setupPush();
    _cargarModo();
    _checkInitialPush();
  }

  // ==========================================================
  // iOS: evitar doble apertura
  // ==========================================================
  Future<void> _checkInitialPush() async {
    if (_handledInitialPush) return;

    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg == null) return;

    _handledInitialPush = true;

    if (msg.data["tipo"] == "nuevo_mensaje") {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            consultaId: int.parse(msg.data["consulta_id"]),
            remitenteTipo: "paciente",
            remitenteId: msg.data["remitente_id"],
          ),
        ),
      );
    }
  }

  // ==========================================================
  // PERMISOS
  // ==========================================================
  Future<void> _pedirPermisos() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ==========================================================
  // PUSH LISTENERS
  // ==========================================================
  void _setupPush() {
    // Foreground
    FirebaseMessaging.onMessage.listen((msg) async {
      debugPrint("📥 FOREGROUND: ${msg.data}");

      // Android: mostrar local
      if (Platform.isAndroid &&
          msg.data["tipo"] == "nuevo_mensaje") {
        await flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          "Nuevo mensaje",
          msg.data["mensaje"] ?? "",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel_id',
              'Notificaciones DocYa',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('alerta'),
            ),
          ),
          payload: jsonEncode(msg.data),
        );
      }
    });

    // Tap en notificación
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (msg.data["tipo"] != "nuevo_mensaje") return;

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            consultaId: int.parse(msg.data["consulta_id"]),
            remitenteTipo: "paciente",
            remitenteId: msg.data["remitente_id"],
          ),
        ),
      );
    });
  }

  // ==========================================================
  // MODO OSCURO
  // ==========================================================
  Future<void> _cargarModo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool("darkMode") ?? true;
    });
  }

  // ==========================================================
  // RUTAS
  // ==========================================================
  Route<dynamic>? _generarRuta(RouteSettings settings) {
    switch (settings.name) {
      case "/splash":
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case "/login":
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case "/home":
        return MaterialPageRoute(
          builder: (_) => HomeScreen(
            nombreUsuario: "Usuario",
            userId: "",
            onToggleTheme: () async {
              setState(() => darkMode = !darkMode);
              final p = await SharedPreferences.getInstance();
              p.setBool("darkMode", darkMode);
            },
          ),
        );
      default:
        return null;
    }
  }

  // ==========================================================
  // UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      initialRoute: "/splash",
      onGenerateRoute: _generarRuta,
    );
  }
}
