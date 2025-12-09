// lib/screens/login_screen.dart

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../globals.dart';
import '../services/auth_service.dart';
import '../widgets/docya_snackbar.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailOrDni = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  final _auth = AuthService();

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // SAVE LOCAL
  // ---------------------------------------------------------------

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token", token);
  }

  Future<void> _saveUser(String nombre, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("nombreUsuario", nombre);
    await prefs.setString("userId", id);
  }

  // ---------------------------------------------------------------
  // RECUPERAR CONTRASEÑA
  // ---------------------------------------------------------------

  Future<void> _recuperarContrasena() async {
    final identificadorController = TextEditingController();
    bool cargando = false;

    await showDialog(
      context: context,
      barrierDismissible: !cargando,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text(
              "🔑 Recuperar contraseña",
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: identificadorController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Ingresá tu email o DNI",
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF14B8A6))),
              ),
            ),
            actions: [
              TextButton(
                onPressed: cargando ? null : () => Navigator.pop(ctx),
                child: const Text("Cancelar",
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6)),
                onPressed: cargando
                    ? null
                    : () async {
                        setStateDialog(() => cargando = true);
                        try {
                          final res = await http.post(
                            Uri.parse(
                                "https://docya-railway-production.up.railway.app/auth/forgot_password_paciente"),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode({
                              "identificador":
                                  identificadorController.text.trim()
                            }),
                          );

                          Navigator.pop(ctx);

                          if (res.statusCode == 200) {
                            final data = jsonDecode(res.body);
                            DocYaSnackbar.show(
                              context,
                              title: "📩 Email enviado",
                              message: data["message"] ??
                                  "Te enviamos un correo con instrucciones.",
                              type: SnackType.success,
                            );
                          } else {
                            final data = jsonDecode(res.body);
                            DocYaSnackbar.show(
                              context,
                              title: "⚠️ Error",
                              message: data["detail"] ??
                                  "No se encontró ningún usuario con esos datos.",
                              type: SnackType.error,
                            );
                          }
                        } catch (e) {
                          Navigator.pop(ctx);
                          DocYaSnackbar.show(
                            context,
                            title: "⚠️ Error interno",
                            message:
                                "Hubo un problema al conectar con el servidor.",
                            type: SnackType.error,
                          );
                        }
                      },
                child: cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "Enviar",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------

  // ---------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
  
    setState(() => _loading = true);
  
    final loginData =
        await _auth.login(_emailOrDni.text.trim(), _password.text.trim());
  
    setState(() => _loading = false);
  
    if (loginData == null || loginData["ok"] != true) {
      DocYaSnackbar.show(
        context,
        title: "❌ Datos incorrectos",
        message: loginData?["detail"] ??
            "Email, DNI o contraseña incorrectos.",
        type: SnackType.error,
      );
      return;
    }
  
    final token = loginData["access_token"] ?? "";
    final id = loginData["user_id"]?.toString() ?? "";
    final nombre = loginData["full_name"] ?? "Usuario";
  
    try {
      // 🔥 FIX PARA iOS → ESPERAR APNS TOKEN
      String? apns = await FirebaseMessaging.instance.getAPNSToken();
  
      int retries = 0;
      while (apns == null && retries < 5) {
        await Future.delayed(const Duration(seconds: 1));
        apns = await FirebaseMessaging.instance.getAPNSToken();
        retries++;
      }
  
      print("🍏 APNS TOKEN: $apns");
  
      // 🔥 AHORA PEDIMOS EL TOKEN FCM (FUNCIONA EN iOS Y ANDROID)
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print("🔥 FCM TOKEN OBTENIDO: $fcmToken");
  
      // SOLO ENVIAR SI EXISTE
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await http.post(
          Uri.parse(
              "https://docya-railway-production.up.railway.app/users/$id/fcm_token"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"fcm_token": fcmToken}),
        );
      }
  
      // GUARDAR TOKEN LOCAL
      await _saveToken(token);
      await _saveUser(nombre, id);
  
      pacienteUuidGlobal = id;
      pacienteEmailGlobal = _emailOrDni.text.trim();
  
      DocYaSnackbar.show(
        context,
        title: "✅ Bienvenido",
        message: "Hola $nombre, ingresaste con éxito.",
        type: SnackType.success,
      );
  
      if (!mounted) return;
  
      Navigator.pushReplacementNamed(context, "/home");
  
    } catch (e) {
      print("❌ ERROR LOGIN iOS: $e");
      DocYaSnackbar.show(
        context,
        title: "⚠️ Error interno",
        message: "No se pudieron guardar los datos.",
        type: SnackType.error,
      );
    }
  }

  
  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF14B8A6);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final double logoSize = size.width * 0.25;
    final double paddingSide = size.width * 0.07;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF203A43),
                    Color(0xFF2C5364),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFFE8F5F3),
                    Color(0xFFD9EFED),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Column(
          children: [
            SizedBox(height: size.height * 0.18),

            // -------------------------------------
            // LOGO CLARO/OSCURO RESPONSIVE
            // -------------------------------------
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Image.network(
                  isDark
                      ? "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logoblanco_1_qdlnog.png"
                      : "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logo_1_svfdye.png",
                  height: logoSize,
                ),
              ),
            ),

            SizedBox(height: size.height * 0.05),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: paddingSide),
                child: Column(
                  children: [
                    _glassForm(kPrimary, isDark),

                    SizedBox(height: size.height * 0.04),

                    Text(
                      "DocYa © 2025 – Tu salud, a un toque",
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12),
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: () => launchUrl(
                        Uri.parse("https://wa.me/5491168700607"),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.support_agent,
                              size: 16,
                              color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            "Soporte WhatsApp: +54 9 11 6870 0607",
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // FORM GLASS
  // ---------------------------------------------------------------

  Widget _glassForm(Color kPrimary, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12, width: 1),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailOrDni,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: _inputStyle(
                      "Email o DNI", Icons.person_outline, isDark),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Ingresá tu email o DNI" : null,
                ),

                const SizedBox(height: 18),

                TextFormField(
                  controller: _password,
                  obscureText: true,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration:
                      _inputStyle("Contraseña", Icons.lock_outline, isDark),
                  validator: (v) =>
                      v == null || v.length < 6 ? "Mínimo 6 caracteres" : null,
                ),

                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _recuperarContrasena,
                    child: Text(
                      "¿Olvidaste tu contraseña?",
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Ingresar",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿No tenés cuenta?",
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        "Registrate",
                        style: TextStyle(color: Color(0xFF14B8A6)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // INPUT STYLE
  // ---------------------------------------------------------------

  InputDecoration _inputStyle(
      String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black45),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.black26),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF14B8A6), width: 1.5),
      ),
    );
  }
}
