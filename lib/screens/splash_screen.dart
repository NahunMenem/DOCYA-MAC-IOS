import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/force_update_dialog.dart';
import '../globals.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  // ======================================================
  // 🔎 CHECK UPDATE (NO SE ROMPE)
  // ======================================================
  Future<void> _checkUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      String version = info.version.trim();

      // Normalizar "1.0" → "1.0.0"
      final parts = version.split('.');
      if (parts.length == 2) {
        version = "${parts[0]}.${parts[1]}.0";
      }

      final url = "$API_URL/app/check_update?version=$version";
      final r = await http.get(Uri.parse(url));

      if (r.statusCode != 200) {
        await _goNext();
        return;
      }

      final data = jsonDecode(r.body);

      if (data["force_update"] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ForceUpdateDialog(
            mensaje: data["mensaje"],
            urlAndroid: data["url_android"],
            urlIos: data["url_ios"],
          ),
        );
      } else {
        await _goNext();
      }
    } catch (e) {
      debugPrint("❌ Error check_update: $e");
      await _goNext();
    }
  }

  // ======================================================
  // 🚀 RESTAURAR CONSULTA O LOGIN
  // ======================================================
  Future<void> _goNext() async {
    final prefs = await SharedPreferences.getInstance();
    final consultaIdStr = prefs.getString("consulta_activa_id");

    if (consultaIdStr != null) {
      try {
        final consultaId = int.parse(consultaIdStr);

        final r = await http.get(
          Uri.parse("$API_URL/consultas/$consultaId"),
        );

        if (r.statusCode == 200) {
          final data = jsonDecode(r.body);
          final estado = data["estado"];

          // 🔁 Redirección según estado real
          if (estado == "pendiente") {
            Navigator.pushReplacementNamed(context, "/esperando");
            return;
          }

          if (estado == "aceptada" || estado == "en_camino") {
            Navigator.pushReplacementNamed(
              context,
              "/medico_en_camino",
              arguments: data,
            );
            return;
          }

          if (estado == "en_domicilio" || estado == "en_curso") {
            Navigator.pushReplacementNamed(
              context,
              "/consulta_en_curso",
              arguments: data,
            );
            return;
          }
        }

        // 🧹 Consulta no válida o finalizada
        await prefs.remove("consulta_activa_id");
      } catch (e) {
        await prefs.remove("consulta_activa_id");
      }
    }

    // 👉 Flujo normal
    Future.delayed(const Duration(milliseconds: 400), () {
      Navigator.pushReplacementNamed(context, "/login");
    });
  }

  // ======================================================
  // 🎨 UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

