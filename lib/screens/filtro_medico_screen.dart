import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'solicitud_medico_screen.dart';

class FiltroMedicoScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacion;

  const FiltroMedicoScreen({
    super.key,
    required this.direccion,
    required this.ubicacion,
  });

  @override
  State<FiltroMedicoScreen> createState() => _FiltroMedicoScreenState();
}

class _FiltroMedicoScreenState extends State<FiltroMedicoScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, bool?> respuestas = {};
  final List<String> preguntas = [
    "¿Tiene dificultad grave para respirar?",
    "¿Tiene dolor intenso en el pecho?",
    "¿Tiene pérdida de conocimiento o convulsiones?",
    "¿Tiene sangrado abundante o que no se detiene?",
    "¿Tiene fiebre muy alta (más de 39.5 °C) con mal estado general?",
    "¿Se trata de un niño menor de 12 años con fiebre persistente o decaimiento?",
    "¿Tiene un accidente grave, fractura expuesta o quemadura extensa?",
  ];

  void _respuesta(String pregunta, bool valor) {
    setState(() => respuestas[pregunta] = valor);
    if (valor == true) _mostrarAlertaUrgencia();
  }

  void _mostrarAlertaUrgencia() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("⚠️ Urgencia detectada",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "Esto puede ser una urgencia.\n"
          "👉 Llame al 911 o diríjase al hospital más cercano.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendido",
                style: TextStyle(color: Color(0xFF14B8A6))),
          )
        ],
      ),
    );
  }

  bool _todasNo() {
    if (respuestas.length < preguntas.length) return false;
    return respuestas.values.every((v) => v == false);
  }

  // 🔹 Reutilizable: card efecto glass adaptado al tema
  Widget glassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isDark
                ? Border.all(color: Colors.white.withOpacity(0.15))
                : Border.all(color: Colors.black12),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final continuarHabilitado = _todasNo();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Scaffold(
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : const BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.health_and_safety, color: textColor, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Antes de continuar",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Por favor responde estas preguntas para descartar una urgencia.",
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de preguntas
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: preguntas.length,
                  itemBuilder: (_, i) {
                    final pregunta = preguntas[i];
                    return glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.help_outline,
                                  color: Color(0xFF14B8A6)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pregunta,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        respuestas[pregunta] == true
                                            ? Colors.red
                                            : (isDark
                                                ? Colors.white.withOpacity(0.15)
                                                : Colors.black12),
                                    foregroundColor: respuestas[pregunta] == true
                                        ? Colors.white
                                        : textColor,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _respuesta(pregunta, true),
                                  child: const Text("Sí",
                                      style: TextStyle(fontSize: 15)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        respuestas[pregunta] == false
                                            ? const Color(0xFF14B8A6)
                                            : (isDark
                                                ? Colors.white.withOpacity(0.15)
                                                : Colors.black12),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _respuesta(pregunta, false),
                                  child: const Text("No",
                                      style: TextStyle(fontSize: 15)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Botón continuar
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: continuarHabilitado
                    ? SafeArea(
                        key: const ValueKey("continuar"),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF14B8A6),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SolicitudMedicoScreen(
                                    direccion: widget.direccion,
                                    ubicacion: widget.ubicacion,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "Continuar solicitud",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
