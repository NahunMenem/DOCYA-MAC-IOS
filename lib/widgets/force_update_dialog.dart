import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String mensaje;
  final String urlAndroid;
  final String urlIos;

  const ForceUpdateDialog({
    super.key,
    required this.mensaje,
    required this.urlAndroid,
    required this.urlIos,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update, color: Colors.white, size: 60),
            const SizedBox(height: 20),

            Text(
              "Actualización requerida",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(
              mensaje,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: () {
                final url = Theme.of(context).platform == TargetPlatform.android
                    ? urlAndroid
                    : urlIos;
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF14B8A6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              ),
              child: const Text(
                "Actualizar ahora",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
