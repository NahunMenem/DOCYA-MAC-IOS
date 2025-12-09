import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ⬇️ IMPORTA TU MENÚ REAL
import '../widgets/bottom_nav.dart';

class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

  final String _whatsappUrl =
      "https://wa.me/5491168700607?text=Hola%20necesito%20ayuda%20con%20DocYa";


  Future<void> _abrirWhatsApp() async {
    final url = Uri.parse(_whatsappUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception("No se pudo abrir WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gradient = isDark
        ? const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]
        : [
            Colors.white,
            Color(0xFFE9FBF8),
          ];

    final textColor = isDark ? Colors.white : const Color(0xFF203A43);
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Colors.transparent,

      // ✅ AQUÍ VA TU MENÚ REAL
      bottomNavigationBar: DocYaBottomNav(
        selectedIndex: 3,
        onItemTapped: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/recetas');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/consultas');
              break;
            case 3:
              break; // ya estás en soporte/perfil
          }
        },
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            isDark ? "assets/logoblanco.png" : "assets/logo.png",
                            height: 45,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Centro de Ayuda",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Encontrá respuestas rápidas o hablá con nuestro equipo",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    _faqItem(
                      context,
                      icono: FontAwesomeIcons.userDoctor,
                      pregunta: "¿Cómo solicito un médico?",
                      respuesta:
                          "Ingresá tu dirección, respondé el filtro clínico y confirmá el pedido. Asignamos automáticamente al profesional más cercano.",
                    ),
                    _faqItem(
                      context,
                      icono: FontAwesomeIcons.creditCard,
                      pregunta: "¿Cómo pago la consulta?",
                      respuesta:
                          "Podés pagar con tarjeta, transferencia o Mercado Pago desde la app.",
                    ),
                    _faqItem(
                      context,
                      icono: FontAwesomeIcons.triangleExclamation,
                      pregunta: "¿Qué pasa si el médico no llega?",
                      respuesta:
                          "Si el profesional no llega, podés cancelar. El reembolso es automático.",
                    ),
                    _faqItem(
                      context,
                      icono: FontAwesomeIcons.userNurse,
                      pregunta: "¿Puedo pedir un enfermero?",
                      respuesta:
                          "Sí. Si el médico lo considera necesario, solicita un enfermero a tu domicilio.",
                    ),
                    _faqItem(
                      context,
                      icono: FontAwesomeIcons.receipt,
                      pregunta: "¿Dónde veo mis recetas o certificados?",
                      respuesta:
                          "En tu Perfil → Historial tenés todas las consultas, recetas y certificados firmados digitalmente.",
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),

              Positioned(
                bottom: 95,
                right: 22,
                child: GestureDetector(
                  onTap: _abrirWhatsApp,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      FontAwesomeIcons.whatsapp,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqItem(
    BuildContext context, {
    required IconData icono,
    required String pregunta,
    required String respuesta,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.95);

    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 1,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: ExpansionTile(
            iconColor: const Color(0xFF14B8A6),
            collapsedIconColor: const Color(0xFF14B8A6),
            leading: Icon(icono, color: const Color(0xFF14B8A6), size: 22),
            title: Text(
              pregunta,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Text(
                  respuesta,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
