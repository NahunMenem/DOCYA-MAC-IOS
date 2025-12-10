// 🔥🔥🔥 DOCYA – BuscandoMedicoScreen ARREGLADA Y SEGURA
// Solo corregí timeout + cancelada. NADA MÁS.

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:docya_app/widgets/docya_snackbar.dart';
import 'home_screen.dart';
import 'MedicoEnCaminoScreen.dart';

class BuscandoMedicoScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacion;
  final String motivo;
  final int? consultaId;
  final String pacienteUuid;
  final String? paymentId;

  const BuscandoMedicoScreen({
    super.key,
    required this.direccion,
    required this.ubicacion,
    required this.motivo,
    this.consultaId,
    required this.pacienteUuid,
    this.paymentId,
  });

  @override
  State<BuscandoMedicoScreen> createState() => _BuscandoMedicoScreenState();
}

class _BuscandoMedicoScreenState extends State<BuscandoMedicoScreen>
    with SingleTickerProviderStateMixin {
  late GoogleMapController _mapController;
  late AnimationController _animController;
  Timer? _timer;
  Timer? _timeoutTimer;

  String estadoConsulta = "pendiente";

  final String apiBase = "https://docya-railway-production.up.railway.app";

  // ===== UBER MAP STYLE =====
  final String uberMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#122932"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#E0F2F1"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0B1A22"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#155E63"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#18A999"}]},
    {"featureType": "water", "stylers": [{"color": "#0C2F3A"}]},
    {"featureType": "poi", "stylers": [{"visibility": "off"}]},
    {"featureType": "transit", "stylers": [{"visibility": "off"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();

    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    // Polling cada 5 segundos
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkEstadoConsulta();
    });

    // 🔥 Timeout FIJO de 60 segundos — SIEMPRE vuelve al home
    _timeoutTimer = Timer(const Duration(seconds: 60), () async {
      _stopPolling();

      // 🟣 CANCELAR BÚSQUEDA EN EL BACKEND
      if (widget.consultaId != null) {
        try {
          await http.post(
            Uri.parse("$apiBase/consultas/${widget.consultaId}/cancelar_busqueda"),
            headers: {"Content-Type": "application/json"},
          );
          print("🛑 Consulta cancelada por timeout del paciente");
        } catch (e) {
          print("⚠️ Error cancelando consulta por timeout: $e");
        }
      }

      // Mostrar aviso al usuario
      if (mounted) {
        DocYaSnackbar.show(
          context,
          title: "Sin profesionales disponibles",
          message: "No se pudo asignar un profesional en este momento.",
          type: SnackType.warning,
        );
      }

      _volverAlHome();
    });

  }

  // ===============================
  //   🛑 CANCELAR POLLING
  // ===============================
  void _stopPolling() {
    _timer?.cancel();
    _timeoutTimer?.cancel();
  }

  // ===============================
  //   🟣 VOLVER AL HOME
  // ===============================
  void _volverAlHome() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          onToggleTheme: () {},
        ),
      ),
      (route) => false,
    );
  }

  // ===============================
  //   🔥 CONSULTAR ESTADO REAL
  // ===============================
  Future<void> _checkEstadoConsulta() async {
    if (widget.consultaId == null) return;

    final url = "$apiBase/consultas/${widget.consultaId}";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final nuevoEstado = data["estado"];
        final mpStatus = data["mp_status"];

        if (!mounted) return;

        setState(() => estadoConsulta = nuevoEstado);

        // -----------------------------
        //  🟣 CANCELADA → AVISAR REFUND
        // -----------------------------
        if (nuevoEstado == "cancelada") {
          _stopPolling();

          DocYaSnackbar.show(
            context,
            title: "Pago devuelto",
            message:
                "Tu dinero fue reintegrado automáticamente por MercadoPago.",
            type: SnackType.success,
          );

          Future.delayed(const Duration(milliseconds: 900), _volverAlHome);
          return;
        }


        // -----------------------------
        //  🟢 MÉDICO ACEPTÓ
        // -----------------------------
        if (nuevoEstado == "aceptada") {
          _stopPolling();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MedicoEnCaminoScreen(
                direccion: widget.direccion,
                ubicacionPaciente: widget.ubicacion,
                motivo: widget.motivo,
                medicoId: data["medico_id"],
                nombreMedico: data["medico_nombre"] ?? "Médico asignado",
                matricula: data["medico_matricula"] ?? "N/A",
                consultaId: widget.consultaId!,
                pacienteUuid: widget.pacienteUuid,
                tipo: data["tipo"] ?? "medico",
              ),
            ),
          );
          return;
        }

        // -----------------------------
        //  🚫 MÉDICO RECHAZÓ
        // -----------------------------
        if (nuevoEstado == "rechazada") {
          _stopPolling();
          DocYaSnackbar.show(
            context,
            title: "Consulta rechazada",
            message: "Ningún profesional aceptó la consulta.",
            type: SnackType.warning,
          );
          _volverAlHome();
          return;
        }

        // -----------------------------
        //  ❌ SIN PROFESIONALES
        // -----------------------------
        if (nuevoEstado == "sin_profesionales" ||
            nuevoEstado == "sin_medicos") {
          _stopPolling();
          DocYaSnackbar.show(
            context,
            title: "Sin profesionales",
            message: "No encontramos profesionales disponibles.",
            type: SnackType.warning,
          );
          _volverAlHome();
          return;
        }

        // -----------------------------
        //  🟣 REFUND AUTOMÁTICO MP
        // -----------------------------
        if (nuevoEstado == "cancelada" && mpStatus == "refunded") {
          _stopPolling();

          DocYaSnackbar.show(
            context,
            title: "Pago devuelto",
            message:
                "No encontramos profesionales. MercadoPago realizó el reembolso automáticamente.",
            type: SnackType.success,
          );

          Future.delayed(const Duration(milliseconds: 900), _volverAlHome);
          return;
        }
      }
    } catch (e) {
      debugPrint("Error consultando estado: $e");
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // ===============================
  //   🚫 BLOQUEAR BOTÓN "ATRÁS"
  // ===============================
  Future<bool> _onWillPop() async => false;

  // ===============================
  //   UI PREMIUM DOCYA
  // ===============================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F2027),
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                _mapController.setMapStyle(uberMapStyle);
              },
              initialCameraPosition:
                  CameraPosition(target: widget.ubicacion, zoom: 15),
              markers: {
                Marker(
                  markerId: const MarkerId("user"),
                  position: widget.ubicacion,
                  icon: BitmapDescriptor.defaultMarkerWithHue(170),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),

            // Animación central
            Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  double size = 120 + (_animController.value * 220);
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF14B8A6)
                          .withOpacity(1 - _animController.value),
                    ),
                  );
                },
              ),
            ),

            // Logo
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset("assets/logoblanco.png", height: 65),
              ),
            ),

            // Card inferior
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Estamos buscando el profesional\nmás cercano a tu ubicación...",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Estado: $estadoConsulta",
                            style: TextStyle(
                              color: Colors.tealAccent.shade100,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            "Estamos notificando al profesional más cercano.\nEsto puede tardar unos segundos.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
