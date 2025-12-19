import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../widgets/docya_snackbar.dart';
import 'chat_screen.dart';
import 'consulta_en_curso_screen.dart';

class MedicoEnCaminoScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacionPaciente;
  final String motivo;
  final int medicoId;
  final String nombreMedico;
  final String matricula;
  final int? consultaId;
  final String pacienteUuid;
  final String tipo;

  const MedicoEnCaminoScreen({
    super.key,
    required this.direccion,
    required this.ubicacionPaciente,
    required this.motivo,
    required this.medicoId,
    required this.nombreMedico,
    required this.matricula,
    required this.pacienteUuid,
    this.consultaId,
    required this.tipo,
  });

  @override
  State<MedicoEnCaminoScreen> createState() => _MedicoEnCaminoScreenState();
}

class _MedicoEnCaminoScreenState extends State<MedicoEnCaminoScreen> {
  late GoogleMapController _mapController;
  Timer? _timer;

  int etaMinutos = 0;
  double progreso = 0.0;

  double distanciaInicial = 0.0;
  double distanciaActual = 0.0;
  double distanciaKm = 0.0;

  double? _ultimaDistanciaBackend;

  String mensaje = "Profesional en camino";

  final String mapStyle = '''
  [
    {"elementType":"geometry","stylers":[{"color":"#0F2027"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#ffffff"}]},
    {"elementType":"labels.text.stroke","stylers":[{"visibility":"off"}]},
    {"featureType":"road","stylers":[{"color":"#2C5364"}]},
    {"featureType":"road.highway","stylers":[{"color":"#14B8A6"}]},
    {"featureType":"water","stylers":[{"color":"#0C2F3A"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _cargarDatos();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _cargarDatos();
      _checkEstadoConsulta();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // =====================================================
  // 🔥 DATOS DESDE BACKEND (SIN GPS REMOTO)
  // =====================================================

  Future<void> _cargarDatos() async {
    if (widget.consultaId == null) return;

    final base = "https://docya-railway-production.up.railway.app";

    try {
      final resp =
          await http.get(Uri.parse("$base/consultas/${widget.consultaId}"));
      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body);

      final int eta = data["tiempo_estimado_min"] ?? 0;
      final double distanciaKmBackend =
          (data["distancia_km"] ?? 0).toDouble();

      double metros = distanciaKmBackend * 1000;

      // 🛡️ Anti-jitter: nunca permitir retroceso
      if (_ultimaDistanciaBackend != null &&
          metros > _ultimaDistanciaBackend! + 50) {
        metros = _ultimaDistanciaBackend!;
      }

      _ultimaDistanciaBackend = metros;

      setState(() {
        etaMinutos = eta;

        if (distanciaInicial == 0 && metros > 0) {
          distanciaInicial = metros;
        }

        distanciaActual = metros;
        distanciaKm = metros / 1000;

        if (distanciaInicial > 0) {
          progreso = 1 - (metros / distanciaInicial);
          progreso = progreso.clamp(0.0, 1.0);
        }

        if (metros > 1000) {
          mensaje = "El profesional está en camino";
        } else if (metros > 500) {
          mensaje = "El profesional está cerca";
        } else if (metros > 200) {
          mensaje = "Preparáte para recibirlo";
        } else {
          mensaje = "El profesional está llegando";
        }
      });
    } catch (e) {
      debugPrint("❌ Error cargando datos: $e");
    }
  }

  // ==========================
  // 🔍 Estado de consulta
  // ==========================

  Future<void> _checkEstadoConsulta() async {
    if (widget.consultaId == null) return;

    final url =
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}";

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body);

      if (data["estado"] == "en_domicilio" && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultaEnCursoScreen(
              consultaId: widget.consultaId!,
              profesionalId: widget.medicoId,
              pacienteUuid: widget.pacienteUuid,
              nombreProfesional: widget.nombreMedico,
              especialidad: data["especialidad"] ?? "Clínica médica",
              matricula: widget.matricula,
              motivo: widget.motivo,
              direccion: widget.direccion,
              horaInicio: DateFormat("HH:mm").format(DateTime.now()),
              tipo: widget.tipo,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  // =====================================================
  // 🎨 UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        DocYaSnackbar.show(
          context,
          title: "⛔ Acción no permitida",
          message: "No podés salir hasta que llegue el profesional.",
          type: SnackType.warning,
        );
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  _mapController.setMapStyle(mapStyle);
                },
                initialCameraPosition: CameraPosition(
                  target: widget.ubicacionPaciente,
                  zoom: 15.5,
                ),
                zoomControlsEnabled: false,
                markers: {
                  Marker(
                    markerId: const MarkerId("paciente"),
                    position: widget.ubicacionPaciente,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure),
                  ),
                },
              ),
              Positioned(top: 55, left: 18, right: 18, child: _buildTopCard()),
              Positioned(top: 230, left: 0, right: 0, child: _buildProgressBar(w)),
              Positioned(
                  bottom: 10, left: 18, right: 18, child: _buildBottomCard()),
            ],
          ),
        ),
      ),
    );
  }

  // =======================
  // 🌿 TOP CARD
  // =======================

  Widget _buildTopCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              if (distanciaKm > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.place,
                        color: Color(0xFF14B8A6), size: 20),
                    const SizedBox(width: 6),
                    Text(
                      "Distancia: ${distanciaKm.toStringAsFixed(2)} km",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  "Calculando distancia...",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =======================
  // 🌿 BARRA DE PROGRESO
  // =======================

  Widget _buildProgressBar(double w) {
    return SizedBox(
      height: 90,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 40,
            right: 40,
            top: 40,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
          Positioned(
            left: 40,
            top: 40,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              height: 14,
              width: (w - 80) * progreso,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF18D0C0)],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
            left: (w - 140) * progreso,
            top: 10,
            child: SizedBox(
              width: 100,
              height: 70,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Image.asset(
                      "assets/ambulancia.png",
                      height: 55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =======================
  // 🌿 BOTTOM CARD
  // =======================

  Widget _buildBottomCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withOpacity(0.7),
                    child: Icon(Icons.person,
                        size: 34, color: Colors.black.withOpacity(0.8)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.tipo == "enfermero" ? "Enfermero/a" : "Dr/a"} ${widget.nombreMedico}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Matrícula: ${widget.matricula}",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          consultaId: widget.consultaId,
                          remitenteTipo: "paciente",
                          remitenteId: widget.pacienteUuid,
                        ),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "Enviar mensaje",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

