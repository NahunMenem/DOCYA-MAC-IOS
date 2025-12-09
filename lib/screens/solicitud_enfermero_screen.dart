// ============================================================
//  SOLICITUD ENFERMERO – DOCYA (FLUJO COMPLETO TIPO MÉDICO)
//  Previa → Preautorización → Deep Link → Verificación backend
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;

import '../globals.dart';
import '../widgets/docya_snackbar.dart';
import 'buscando_medico_screen.dart';

class SolicitudEnfermeroScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacion;

  const SolicitudEnfermeroScreen({
    super.key,
    required this.direccion,
    required this.ubicacion,
  });

  @override
  State<SolicitudEnfermeroScreen> createState() =>
      _SolicitudEnfermeroScreenState();
}

class _SolicitudEnfermeroScreenState extends State<SolicitudEnfermeroScreen>
    with WidgetsBindingObserver {
  
  final motivoCtrl = TextEditingController();

  bool aceptaConsentimiento = false;
  bool pagando = false;
  String metodoPago = "tarjeta";

  int? consultaPreviaId;              // NEW igual que médico
  String pagoPreautorizadoGlobal = "";  // NEW igual que médico
  bool pagoConfirmadoUnaVez = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();

    Future.delayed(const Duration(milliseconds: 600), _verificarPagoBackend);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================================
  // 🔥 BACKEND – verificar estado pago
  // ============================================================
  Future<void> _verificarPagoBackend() async {
    if (consultaPreviaId == null) return;

    try {
      final res = await http.get(
        Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/$consultaPreviaId/estado"
        ),
      );

      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final preaut = data["mp_preautorizado"] == true;

      if (preaut) {
        setState(() {
          pagoPreautorizadoGlobal = "preautorizado";
        });
      } else {
        setState(() {
          pagoPreautorizadoGlobal = "";
        });
      }



    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarPagoBackend();
    }
  }

  // ============================================================
  // 🔗 Deep Links
  // ============================================================
  void _initDeepLinks() async {
    final appLinks = AppLinks();

    appLinks.uriLinkStream.listen((uri) {
      if (uri == null) return;

      if (uri.toString().startsWith("docya://pago_exitoso")) {
        if (!pagoConfirmadoUnaVez) {
          pagoConfirmadoUnaVez = true;
          _confirmarPago();
        }
      }
    });

    final initial = await appLinks.getInitialLink();
    if (initial != null &&
        initial.toString().startsWith("docya://pago_exitoso")) {
      if (!pagoConfirmadoUnaVez) {
        pagoConfirmadoUnaVez = true;
        _confirmarPago();
      }
    }
  }


  // ============================================================
  // 🔥 PRECIO ENFERMERO DINÁMICO
  // ============================================================
  int _calcularPrecio() {
    final ahora = DateTime.now().toUtc().add(const Duration(hours: -3));
    final h = ahora.hour;

    return (h >= 22 || h < 6) ? 3 : 2;
    //return (h >= 22 || h < 6) ? 30000 : 20000;
  }

  String _mensajePrecio(int p) {
    return p == 30000
        ? "Tarifa nocturna (22:00–06:00). Incluye atención profesional de enfermería."
        : "Incluye atención profesional de enfermería a domicilio.";
  }

  // ============================================================
  // 💳 1. CREAR PREVIA + PREAUTORIZAR
  // ============================================================
  Future<void> _pagar() async {
    final precio = _calcularPrecio();
    setState(() => pagando = true);

    try {
      // ---- Crear consulta previa ----
      final previa = await http.post(
        Uri.parse("https://docya-railway-production.up.railway.app/consultas/crear_previa"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "paciente_uuid": pacienteUuidGlobal,
          "motivo": motivoCtrl.text.trim(),
          "direccion": widget.direccion,
          "lat": widget.ubicacion.latitude,
          "lng": widget.ubicacion.longitude,
          "tipo": "enfermero"
        }),
      );

      if (previa.statusCode != 200) {
        _toast("Error creando consulta");
        setState(() => pagando = false);
        return;
      }

      final previaData = jsonDecode(previa.body);
      consultaPreviaId = previaData["consulta_id"];

      // ---- Preautorizar pago ----
      final res = await http.post(
        Uri.parse("https://docya-railway-production.up.railway.app/pagos/preautorizar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "consulta_id": consultaPreviaId,
          "email": pacienteEmailGlobal,
          "monto": precio,
        }),
      );

      if (res.statusCode != 200) {
        _toast("Error iniciando pago");
        setState(() => pagando = false);
        return;
      }

      final data = jsonDecode(res.body);

      await launchUrl(
        Uri.parse(data["init_point"]),
        mode: LaunchMode.externalApplication,
      );

    } catch (_) {
      _toast("Error iniciando pago");
    }

    setState(() => pagando = false);
  }

  // ============================================================
  // 💳 2. CONFIRMAR PAGO DESDE DEEP LINK
  // ============================================================
  Future<void> _confirmarPago() async {
    if (consultaPreviaId == null) return;

    try {
      await http.post(
        Uri.parse("https://docya-railway-production.up.railway.app/consultas/confirmar_pago"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "consulta_id": consultaPreviaId,
          "payment_id": "pending"
        }),
      );
    } catch (_) {}

    // Siempre verificamos en backend
    await _verificarPagoBackend();
  }


  // ============================================================
  // 🟦 3. CREAR CONSULTA FINAL
  // ============================================================
  Future<void> _solicitar() async {
    if (motivoCtrl.text.trim().isEmpty) {
      _toast("Escribí el motivo de la consulta");
      return;
    }

    if (!aceptaConsentimiento) {
      _toast("Debes aceptar la declaración jurada");
      return;
    }

    if (metodoPago == "tarjeta" && pagoPreautorizadoGlobal != "preautorizado") {
      _toast("Debes completar el pago primero");
      return;
    }



    final body = jsonEncode({
      "consulta_id": consultaPreviaId,
      "paciente_uuid": pacienteUuidGlobal,
      "motivo": motivoCtrl.text.trim(),
      "direccion": widget.direccion,
      "lat": widget.ubicacion.latitude,
      "lng": widget.ubicacion.longitude,
      "metodo_pago": metodoPago,
      "payment_id": "pending",
      "tipo": "enfermero",
    });

    try {
      final res = await http.post(
        Uri.parse("https://docya-railway-production.up.railway.app/consultas/solicitar"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (res.statusCode != 200) {
        _toast("No se pudo solicitar enfermero");
        return;
      }

      final data = jsonDecode(res.body);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuscandoMedicoScreen(
            direccion: widget.direccion,
            ubicacion: widget.ubicacion,
            motivo: motivoCtrl.text.trim(),
            consultaId: data["consulta_id"],
            pacienteUuid: pacienteUuidGlobal,
            paymentId: "pending",
          ),
        ),
      );

    } catch (_) {
      _toast("Error de conexión");
    }
  }

  // ============================================================
  // SNACKBAR UNIVERSAL
  // ============================================================
  void _toast(String m) {
    DocYaSnackbar.show(
      context,
      title: "Aviso",
      message: m,
      type: SnackType.warning,
    );
  }

  // ============================================================
  // =========================== UI =============================
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final precio = _calcularPrecio();

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Image.asset(
          isDark ? "assets/logoblanco.png" : "assets/logonegro.png",
          height: 42,
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isDark ? null : Colors.white,
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            child: Column(
              children: [
                _glassCard(_header(isDark)),
                _glassCard(_cardMotivo(isDark)),
                _glassCard(_cardPago(precio, isDark)),
                const SizedBox(height: 20),

                if (metodoPago == "tarjeta") _botonMP(),

                if (metodoPago == "tarjeta")
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Al confirmar el pago en Mercado Pago, volverás automáticamente a DocYa.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),

                _warningMP(isDark),

                const SizedBox(height: 20),
                _botonSolicitar(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= UI BLOCKS =================

  Widget _header(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.health_and_safety_rounded,
              size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Atención de enfermería",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          )
        ]),
        const SizedBox(height: 12),
        Text(
          "Aplicación de inyectables, curaciones, controles y asistencia profesional en tu domicilio.",
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _glassCard(Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12, width: 1),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black54 : Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _cardMotivo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title("Motivo de la consulta", isDark),
        const SizedBox(height: 12),

        TextField(
          controller: motivoCtrl,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "Describí tus síntomas o necesidad...",
            hintStyle:
                TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            filled: true,
            fillColor: isDark ? Colors.white12 : Colors.black12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: isDark ? Colors.white30 : Colors.black26),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Checkbox(
              value: aceptaConsentimiento,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => setState(() => aceptaConsentimiento = v!),
            ),
            Expanded(
              child: Text(
                "Declaro haber respondido honestamente el triage previo.",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _cardPago(int precio, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title("Método de pago", isDark),
        const SizedBox(height: 16),

        _precioCard(precio, isDark),
        const SizedBox(height: 14),

        _paymentOption(
          value: "tarjeta",
          icon: Icons.credit_card_rounded,
          title: "Tarjeta de Crédito / Débito",
          subtitle: "Pago seguro con Mercado Pago",
          color: const Color(0xFF009ee3),
        ),

        const SizedBox(height: 12),

        _paymentOption(
          value: "efectivo",
          icon: Icons.attach_money_rounded,
          title: "Efectivo",
          subtitle: "Pago directo al enfermero",
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _precioCard(int precio, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.black12,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? Colors.white30 : Colors.black12, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_heart_rounded,
              size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "\$$precio",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _mensajePrecio(precio),
                  style: TextStyle(
                    height: 1.3,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = metodoPago == value;

    return GestureDetector(
      onTap: () => setState(() => metodoPago = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.14)
              : (isDark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : (isDark ? Colors.white24 : Colors.black26),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? color : Colors.white38, width: 2),
              ),
              child: selected
                  ? Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    )
                  : null,
            )
          ],
        ),
      ),
    );
  }

  Widget _botonMP() {
    return GestureDetector(
      onTap: pagando ? null : _pagar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF009ee3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF009ee3).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Center(
          child: pagando
              ? const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)
              : Image.asset("assets/mp_logo_blanco.png",
                  height: 40, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _warningMP(bool isDark) {
    if (metodoPago != "tarjeta") return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white12 : Colors.black12,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black26,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Este pago es una preautorización. "
                "El cargo solo se realiza cuando un profesional acepta tu consulta. "
                "Si no se asigna ningún enfermero, no se realizará ningún débito.",
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonSolicitar(bool isDark) {
    final ready =
        metodoPago == "efectivo" || pagoPreautorizadoGlobal == "preautorizado";

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: ready ? 1 : 0.6,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: ready ? _solicitar : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            "Solicitar enfermero",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String t, bool isDark) {
    return Text(
      t,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}