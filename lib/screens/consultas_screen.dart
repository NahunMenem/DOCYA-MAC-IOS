import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ConsultasScreen extends StatefulWidget {
  final String pacienteUuid;

  const ConsultasScreen({super.key, required this.pacienteUuid});

  @override
  State<ConsultasScreen> createState() => _ConsultasScreenState();
}

class _ConsultasScreenState extends State<ConsultasScreen> {
  List<dynamic> consultas = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistoriaClinica();
  }

  Future<void> _fetchHistoriaClinica() async {
    final url =
        "https://docya-railway-production.up.railway.app/pacientes/${widget.pacienteUuid}/historia_clinica";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          consultas = jsonDecode(response.body);
          loading = false;
        });
      } else {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error ${response.statusCode}: no se pudo cargar la historia clínica"),
          ),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error cargando historia clínica: $e")),
      );
    }
  }

  Color _estadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case "finalizada":
        return const Color(0xFF14B8A6);
      case "cancelada":
        return Colors.redAccent;
      case "aceptada":
        return Colors.blueAccent;
      default:
        return Colors.amber;
    }
  }

  IconData _estadoIcono(String estado) {
    switch (estado.toLowerCase()) {
      case "finalizada":
        return PhosphorIconsRegular.checkCircle;
      case "cancelada":
        return PhosphorIconsRegular.xCircle;
      case "aceptada":
        return PhosphorIconsRegular.handshake;
      default:
        return PhosphorIconsRegular.clock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]
        : [Colors.white, const Color(0xFFE8F8F6)];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Historia Clínica",
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF203A43),
          ),
        ),
        backgroundColor:
            isDark ? const Color(0xFF203A43) : const Color(0xFF14B8A6),
        elevation: 0,
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
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
                )
              : consultas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIconsRegular.note,
                            color: isDark ? Colors.white30 : Colors.black26,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No hay consultas registradas",
                            style: GoogleFonts.manrope(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: consultas.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final consulta = consultas[index];

                        // PROFESIONAL (ya viene formateado del backend)
                        String tituloProfesional =
                            consulta['medico']?.toString().trim() ??
                                "Profesional no asignado";

                        Map<String, dynamic>? historia;

                        if (consulta['historia_clinica'] != null) {
                          try {
                            historia = jsonDecode(consulta['historia_clinica']);
                          } catch (_) {}
                        }

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          _estadoColor(consulta['estado'] ?? ""),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _estadoIcono(consulta['estado'] ?? ""),
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  if (index != consultas.length - 1)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.black12,
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 20),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.white.withOpacity(0.9),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black12,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Consulta #${consulta['consulta_id']}",
                                                style: GoogleFonts.manrope(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                              Icon(
                                                PhosphorIconsRegular.arrowRight,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black45,
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 6),

                                          Row(
                                            children: [
                                              Icon(
                                                PhosphorIconsRegular.userCircle,
                                                size: 16,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                tituloProfesional,
                                                style: GoogleFonts.manrope(
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black54,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 4),

                                          Row(
                                            children: [
                                              Icon(
                                                PhosphorIconsRegular
                                                    .calendarBlank,
                                                size: 16,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black45,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                consulta['fecha_consulta'] ?? "-",
                                                style: GoogleFonts.manrope(
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black45,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const Divider(height: 20),

                                          Text(
                                            "Motivo de consulta:",
                                            style: GoogleFonts.manrope(
                                              color: const Color(0xFF14B8A6),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            consulta['motivo'] ?? "-",
                                            style: GoogleFonts.manrope(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                              height: 1.4,
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          if (historia != null) ...[
                                            Text(
                                              "Historia clínica",
                                              style: GoogleFonts.manrope(
                                                color: const Color(0xFF14B8A6),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // -----------------------------
                                            // SIGNOS VITALES
                                            // -----------------------------
                                            if (historia['signos_vitales'] != null)
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        "TA: ${historia['signos_vitales']['ta']}",
                                                        style: GoogleFonts.manrope(
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors.black54),
                                                      ),
                                                      Text(
                                                        "FC: ${historia['signos_vitales']['fc']}",
                                                        style: GoogleFonts.manrope(
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors.black54),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        "Temp: ${historia['signos_vitales']['temp']}°C",
                                                        style: GoogleFonts.manrope(
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors.black54),
                                                      ),
                                                      Text(
                                                        "SatO₂: ${historia['signos_vitales']['sat']}",
                                                        style: GoogleFonts.manrope(
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors.black54),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),

                                            // -----------------------------
                                            // ➕ NUEVO: RESPIRATORIO
                                            // -----------------------------
                                            if (historia['respiratorio'] != null) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                "Respiratorio:",
                                                style: GoogleFonts.manrope(
                                                  color: Color(0xFF14B8A6),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                historia['respiratorio'],
                                                style: GoogleFonts.manrope(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ],

                                            // -----------------------------
                                            // ➕ NUEVO: CARDIO
                                            // -----------------------------
                                            if (historia['cardio'] != null) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                "Cardiovascular:",
                                                style: GoogleFonts.manrope(
                                                  color: Color(0xFF14B8A6),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                historia['cardio'],
                                                style: GoogleFonts.manrope(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ],

                                            // -----------------------------
                                            // ➕ NUEVO: ABDOMEN
                                            // -----------------------------
                                            if (historia['abdomen'] != null) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                "Abdomen:",
                                                style: GoogleFonts.manrope(
                                                  color: Color(0xFF14B8A6),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                historia['abdomen'],
                                                style: GoogleFonts.manrope(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ],

                                            // -----------------------------
                                            // ➕ NUEVO: SNC
                                            // -----------------------------
                                            if (historia['snc'] != null) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                "Sistema Nervioso Central:",
                                                style: GoogleFonts.manrope(
                                                  color: Color(0xFF14B8A6),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                historia['snc'],
                                                style: GoogleFonts.manrope(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ],

                                            // -----------------------------
                                            // DIAGNOSTICO
                                            // -----------------------------
                                            if (historia['diagnostico'] != null) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                "Diagnóstico:",
                                                style: GoogleFonts.manrope(
                                                  color: const Color(0xFF14B8A6),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                historia['diagnostico'],
                                                style: GoogleFonts.manrope(
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ],

                                            // -----------------------------
                                            // OBSERVACIONES
                                            // -----------------------------
                                            if (historia['observacion'] != null &&
                                                historia['observacion']
                                                    .toString()
                                                    .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  "Observaciones: ${historia['observacion']}",
                                                  style: GoogleFonts.manrope(
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                ),
                                              ),

                                            // -----------------------------
                                            // ➕ NUEVO: FECHA DE NOTA
                                            // -----------------------------
                                            if (consulta['fecha_nota'] != null) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                "Fecha de registro de la nota:",
                                                style: GoogleFonts.manrope(
                                                  color: Color(0xFF14B8A6),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                consulta['fecha_nota'],
                                                style: GoogleFonts.manrope(
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}