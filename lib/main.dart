// ==========================================================
// DOCYA PACIENTE – MAIN FINAL 2025
// iOS + Android 100% Compatible
// Chat + Push + Sonido
// ==========================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';

// ==========================================================
// NAVIGATOR GLOBAL
// ==========================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ==========================================================
// LOCAL NOTIFICATIONS
// ==========================================================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();


// ==========================================================
// 🔥 BACKGROUND HANDLER (OBLIGATORIO iOS)
// ==========================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({
        "consulta_id": message.data["consulta_id"],
        "remitente_id": message.data["remitente_id"],
      }),
    );
  }
}


// ==========================================================
// TAP NOTIFICACIÓN LOCAL → ABRIR CHAT
// ==========================================================
void _handleLocalNotificationTap(String payload) {
  final data = jsonDecode(payload);

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        consultaId: int.parse(data["consulta_id"]),
        remitenteTipo: "paciente",
        remitenteId: data["remitente_id"].toString(),
      ),
    ),
  );
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

  // ANDROID CHANNEL
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

  // LOCAL NOTIFICATIONS INIT
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      if (resp.payload != null) {
        _handleLocalNotificationTap(resp.payload!);
      }
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

  @override
  void initState() {
    super.initState();
    _initEverything();
  }

  Future<void> _initEverything() async {
    await _pedirPermisosNotificaciones();
    _setupPushListeners();
    _cargarModo();
    _checkInitialPush(); // iOS app cerrada
  }

  // ==========================================================
  // iOS – APP CERRADA DESDE NOTIFICACIÓN
  // ==========================================================
  Future<void> _checkInitialPush() async {
    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg == null) return;

    if (msg.data["tipo"] == "nuevo_mensaje") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
  }

  // ==========================================================
  // PERMISOS
  // ==========================================================
  Future<void> _pedirPermisosNotificaciones() async {
    await Permission.notification.request();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ==========================================================
  // PUSH LISTENERS (IGUAL QUE PRO)
  // ==========================================================
  void _setupPushListeners() {
    // FOREGROUND
    FirebaseMessaging.onMessage.listen((msg) async {
      if (msg.data["tipo"] == "nuevo_mensaje") {
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
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode({
            "consulta_id": msg.data["consulta_id"],
            "remitente_id": msg.data["remitente_id"],
          }),
        );
      }
    });

    // BACKGROUND / TAP
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
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
    });
  }

  // ==========================================================
  // MODO OSCURO (ORIGINAL)
  // ==========================================================
  Future<void> _cargarModo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool("darkMode") ?? true;
    });
  }

  // ==========================================================
  // RUTAS (ORIGINALES – NO TOCADAS)
  // ==========================================================
  Route<dynamic>? _generarRuta(RouteSettings settings) {
    switch (settings.name) {
      case "/splash":
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case "/login":
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case "/home":
        return MaterialPageRoute(
          builder: (_) => FutureBuilder(
            future: SharedPreferences.getInstance(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final prefs = snap.data!;
              return HomeScreen(
                nombreUsuario:
                    prefs.getString("nombreUsuario") ?? "Usuario",
                userId: prefs.getString("userId") ?? "",
                onToggleTheme: () async {
                  setState(() => darkMode = !darkMode);
                  final p = await SharedPreferences.getInstance();
                  p.setBool("darkMode", darkMode);
                },
              );
            },
          ),
        );

      default:
        return null;
    }
  }

  // ==========================================================
  // UI FINAL
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(primary: Color(0xFF14B8A6)),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Color(0xFF14B8A6)),
      ),
      initialRoute: "/splash",
      onGenerateRoute: _generarRuta,
    );
  }
}
