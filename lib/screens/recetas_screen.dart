import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class RecetasScreen extends StatefulWidget {
  final String pacienteUuid;
  final String token;

  const RecetasScreen({
    super.key,
    required this.pacienteUuid,
    required this.token,
  });

  @override
  State<RecetasScreen> createState() => _RecetasScreenState();
}

class _RecetasScreenState extends State<RecetasScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  List recetas = [];
  List certificados = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarArchivos();
  }

  Future<void> _cargarArchivos() async {
    try {
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/pacientes/${widget.pacienteUuid}/archivos");

      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer ${widget.token}"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          recetas = data
              .where((a) => a["tipo"].toString().contains("Receta"))
              .toList();
          certificados = data
              .where((a) => a["tipo"].toString().contains("Certificado"))
              .toList();
          loading = false;
        });
      } else {
        throw Exception("Error ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error cargando archivos: $e");
      setState(() => loading = false);
    }
  }

  Future<void> _abrirDocumento(String? url, String titulo) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Documento no disponible")),
      );
      return;
    }

    final uri = Uri.parse(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF14B8A6),
        content: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 16),
            Text("Abriendo documento...", style: TextStyle(color: Colors.white)),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception("No se pudo abrir el navegador");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al abrir el documento: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF14B8A6);

    final gradient = isDark
        ? const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]
        : [Colors.white, const Color(0xFFE8F8F6)];

    if (loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F2027) : Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Mis documentos",
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF203A43),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF203A43) : primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Recetas"),
            Tab(text: "Certificados"),
          ],
        ),
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
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildListView(recetas, isDark),
              _buildListView(certificados, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List archivos, bool isDark) {
    if (archivos.isEmpty) {
      return Center(
        child: Text(
          "No hay documentos disponibles.",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: archivos.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final archivo = archivos[index];
        final tipo = archivo["tipo"].toString();
        final esReceta = tipo.contains("Receta");

        final bgColor = isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.95);

        final textColor = isDark ? Colors.white : Colors.black87;
        final subColor = isDark ? Colors.white70 : Colors.black54;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Icon(
              esReceta
                  ? Icons.receipt_long_rounded
                  : Icons.assignment_rounded,
              color: const Color(0xFF14B8A6),
              size: 32,
            ),
            title: Text(
              tipo,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              "Dr. ${archivo["doctor"]}\n${archivo["fecha"]}",
              style: TextStyle(color: subColor, height: 1.4, fontSize: 13.5),
            ),
            trailing: IconButton(
              icon: Icon(Icons.open_in_new_rounded, color: textColor),
              onPressed: () => _abrirDocumento(archivo["url"], tipo),
            ),
          ),
        );
      },
    );
  }
}
