import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'soporte_screen.dart';
import 'consultas_screen.dart';
import 'recetas_screen.dart';

class PerfilScreen extends StatefulWidget {
  final String userId;

  const PerfilScreen({super.key, required this.userId});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const Color kPrimary = Color(0xFF14B8A6);
  static const List<Color> kGradient = [
    Color(0xFF0F2027),
    Color(0xFF203A43),
    Color(0xFF2C5364),
  ];

  bool cargando = true;
  String nombre = "";
  String email = "";
  String? _userToken;
  int totalConsultas = 0;
  int mesesEnDocYa = 0;

  double w(BuildContext c) => MediaQuery.of(c).size.width;
  double h(BuildContext c) => MediaQuery.of(c).size.height;

  @override
  void initState() {
    super.initState();
    _cargarTokenYPerfil();
  }

  Future<void> _cargarTokenYPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    _userToken = prefs.getString("auth_token") ?? prefs.getString("token");
    await _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/users/${widget.userId}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          nombre = (data['full_name'] ?? "").toString();
          email = (data['email'] ?? "").toString();
          totalConsultas = data['consultas_count'] ?? 0;
          mesesEnDocYa = data['meses_en_docya'] ?? 0;
          cargando = false;
        });
      } else {
        cargando = false;
      }
    } catch (_) {
      cargando = false;
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/login");
  }

  // 🔥 CONFIRMACIÓN PARA ELIMINAR CUENTA
  void _confirmarEliminacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark
              ? Colors.black.withOpacity(0.85)
              : Colors.white.withOpacity(0.90),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            "Eliminar cuenta",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Esta acción eliminará tu cuenta y todos tus datos de forma permanente. No podrás recuperarla.",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                "Cancelar",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text(
                "Eliminar",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _eliminarCuenta();
              },
            ),
          ],
        );
      },
    );
  }


  // 🔥 LLAMADO AL BACKEND PARA ELIMINAR CUENTA
  Future<void> _eliminarCuenta() async {
    try {
      final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/usuarios/${widget.userId}/delete",
      );

      final response = await http.delete(url);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cuenta eliminada correctamente"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al eliminar cuenta: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error inesperado: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _glass({
    required Widget child,
    double radius = 22,
    EdgeInsets? padding,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _glass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Icon(icon, color: kPrimary, size: 24),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: w(context) < 380 ? 14 : 16,
                        fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: w(context) < 380 ? 11 : 13),
                    ),
                ],
              ),
            ),

            Icon(Icons.chevron_right,
                color: isDark ? Colors.white54 : Colors.black45),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    double ancho = w(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: kGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              h(context) * 0.03,
              20,
              h(context) * 0.03,
            ),
            child: Column(
              children: [
                // HEADER RESPONSIVE
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_circle,
                        size: ancho < 380 ? 80 : 100,
                        color: kPrimary,
                      ),
                      const SizedBox(height: 16),

                      Text(
                        nombre.isEmpty ? "Usuario" : nombre,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: ancho < 380 ? 20 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        email,
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: ancho < 380 ? 12 : 14),
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: ancho < 380 ? 12 : 18,
                          ),
                        ),
                        onPressed: _cerrarSesion,
                        icon: const Icon(Icons.logout),
                        label: Text(
                          "Cerrar sesión",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: ancho < 380 ? 13 : 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: h(context) * 0.04),

                // STATS RESPONSIVE
                Row(
                  children: [
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _statCard(
                          "Consultas médicas",
                          totalConsultas.toString(),
                          Icons.medical_services_outlined,
                          isDark),
                    )),
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _statCard(
                          "Meses en DocYa",
                          mesesEnDocYa.toString(),
                          Icons.calendar_month_outlined,
                          isDark),
                    )),
                  ],
                ),

                SizedBox(height: h(context) * 0.04),

                // ITEMS RESPONSIVE
                _tile(
                  icon: Icons.history,
                  title: "Historial de consultas",
                  subtitle: "Ver mis visitas y diagnósticos",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ConsultasScreen(pacienteUuid: widget.userId),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _tile(
                  icon: Icons.receipt_long,
                  title: "Recetas y certificados",
                  subtitle: "Ver documentos emitidos",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecetasScreen(
                        pacienteUuid: widget.userId,
                        token: _userToken ?? "",
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _tile(
                  icon: Icons.help_outline,
                  title: "Soporte",
                  subtitle: "Centro de ayuda y contacto",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SoporteScreen()),
                  ),
                ),
                

                const SizedBox(height: 12),

                // 🔥 TILE DE ELIMINAR CUENTA
                _tile(
                  icon: Icons.delete_forever,
                  title: "Eliminar cuenta",
                  subtitle: "Borrar mi cuenta y todos mis datos",
                  onTap: () => _confirmarEliminacion(context),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, bool isDark) {
    return _glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, color: kPrimary, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }
}
