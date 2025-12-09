import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'solicitud_enfermero_screen.dart';
import 'filtro_medico_screen.dart';
import '../widgets/bottom_nav.dart';
import 'perfil_screen.dart';
import 'consultas_screen.dart';
import 'recetas_screen.dart';
import 'registrar_direccion_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/noticias_carousel.dart';

class HomeScreen extends StatefulWidget {
  final String? nombreUsuario;
  final String? userId;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    this.nombreUsuario,
    this.userId,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String? _nombreUsuario;
  String? _userId;
  String? _userToken;
  bool cargando = true;
  bool tieneDireccion = false;
  LatLng? selectedLocation;
  GoogleMapController? mapController;
  int _selectedIndex = 0;

  final TextEditingController direccionCtrl = TextEditingController();
  final TextEditingController pisoCtrl = TextEditingController();
  final TextEditingController deptoCtrl = TextEditingController();
  final TextEditingController indicacionesCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // 🎨 Estilo de mapa DocYa
  // 🎨 Estilo de mapa DocYa (mejor visibilidad)
  final String docyaMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#122932"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#E0F2F1"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#0B1A22"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#155E63"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#0F3E45"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [{"color": "#18A999"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#0D2D32"}]
    },
    {
      "featureType": "water",
      "stylers": [{"color": "#0C2F3A"}]
    },
    {
      "featureType": "poi",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "transit",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#134E4A"}]
    }
  ]
  ''';


  @override
  void initState() {
    super.initState();
    _cargarSesion();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _scaleAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  }
  

  Future<void> _cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreUsuario = widget.nombreUsuario ?? prefs.getString("nombreUsuario");
      _userId = widget.userId ?? prefs.getString("userId");
      _userToken = prefs.getString("auth_token");
    });

    if (_userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, "/login");
      });
    } else {
      _cargarDireccionGuardada();
    }
  }

  Future<void> _cargarDireccionGuardada() async {
    final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/direccion/mia/${_userId}");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        selectedLocation = LatLng(data["lat"], data["lng"]);
        direccionCtrl.text = data["direccion"] ?? "";
        pisoCtrl.text = data["piso"] ?? "";
        deptoCtrl.text = data["depto"] ?? "";
        indicacionesCtrl.text = data["indicaciones"] ?? "";
        telefonoCtrl.text = data["telefono_contacto"] ?? "";
        tieneDireccion = true;
        cargando = false;
      });

      // 📍 centramos cámara
      if (mapController != null && selectedLocation != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(selectedLocation!, 16),
        );
      }
    } else {
      setState(() {
        tieneDireccion = false;
        cargando = false;
      });
    }
  }

  void _mostrarSnackBar(BuildContext context, String mensaje,
      {bool exito = true}) {
    final color = exito ? const Color(0xFF14B8A6) : Colors.redAccent;
    final icono =
        exito ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warningCircle;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icono, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget glassCard({required Widget child, EdgeInsets? padding}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isDark ? Border.all(color: Colors.white24) : null,
          ),
          child: child,
        ),
      ),
    );
  }

  // 🔹 Botones de servicio
  Widget _serviceButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Gradient? gradient,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _animationController.reverse(),
      onTapUp: (_) {
        _animationController.forward();
        onTap();
      },
      onTapCancel: () => _animationController.forward(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 100,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  colors: [
                    color.withOpacity(0.95),
                    color.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 22,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefitTile(IconData icon, String title) {
    final color =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    return glassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  Widget _vistaHomePrincipal() {
    return _fondoGradiente(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIconsFill.handWaving,
                      color: Color(0xFF14B8A6), size: 24),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                        children: [
                          const TextSpan(
                            text: "Hola, ",
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: "${_nombreUsuario ?? "Usuario"}",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14B8A6),
                            ),
                          ),
                          const TextSpan(
                            text: "\n¿Qué necesitás hoy?",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 🔹 Botón principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                  ),
                  onPressed: () {
                    if (selectedLocation != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FiltroMedicoScreen(
                            direccion: direccionCtrl.text,
                            ubicacion: selectedLocation!,
                          ),
                        ),
                      );
                    } else {
                      _mostrarSnackBar(context,
                          "Seleccioná una ubicación primero",
                          exito: false);
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(PhosphorIconsFill.firstAid,
                          color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        "Solicitar médico ahora",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Dirección guardada
              glassCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF14B8A6),
                        shape: BoxShape.circle,
                      ),
                  
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(direccionCtrl.text,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text("Piso: ${pisoCtrl.text} - Depto: ${deptoCtrl.text}",
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegistrarDireccionScreen(
                              nombreUsuario: _nombreUsuario,
                              userId: _userId,
                            ),
                          ),
                        );

                        // ✅ al volver, recargamos desde el backend y actualizamos el mapa
                        if (mounted) {
                          await _cargarDireccionGuardada();

                          if (selectedLocation != null && mapController != null) {
                            mapController!.animateCamera(
                              CameraUpdate.newLatLngZoom(selectedLocation!, 16),
                            );
                          }

                          _mostrarSnackBar(context, "Dirección actualizada correctamente");
                        }
                      },

                      child: const Text(
                        "Cambiar",
                        style: TextStyle(
                          color: Color(0xFF14B8A6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 🗺️ Mapa DocYa con radar
              // 🗺️ Mapa DocYa con radar en la ubicación
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      GoogleMap(
                        onMapCreated: (controller) {
                          mapController = controller;
                          controller.setMapStyle(docyaMapStyle);
                          if (selectedLocation != null) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(selectedLocation!, 16),
                            );
                          }
                        },
                        initialCameraPosition: CameraPosition(
                          target: selectedLocation ?? const LatLng(-34.6037, -58.3816),
                          zoom: 14,
                        ),
                        markers: selectedLocation != null
                            ? {
                                Marker(
                                  markerId: const MarkerId("docya_pin"),
                                  position: selectedLocation!,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueAzure,
                                  ),
                                ),
                              }
                            : {},
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                      ),

                      // 🌊 Ondas radar sobre la ubicación
                      if (selectedLocation != null)
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            Tween(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Curves.easeInOut,
                              ),
                            )
                          ]),
                          builder: (context, _) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(seconds: 2),
                              curve: Curves.easeOut,
                              onEnd: () => setState(() {}),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    0,
                                    0,
                                  ),
                                  child: Container(
                                    width: 60 + (value * 70),
                                    height: 60 + (value * 70),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF14B8A6).withOpacity(1 - value),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),


              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _serviceButton(
                      context,
                      icon: PhosphorIconsFill.syringe,
                      label: "Enfermero",
                      color: const Color(0xFF14B8A6),
                      onTap: () {
                        if (selectedLocation != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SolicitudEnfermeroScreen(
                                direccion: direccionCtrl.text,
                                ubicacion: selectedLocation!,
                              ),
                            ),
                          );
                        } else {
                          _mostrarSnackBar(context,
                              "Seleccioná una ubicación primero",
                              exito: false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _serviceButton(
                      context,
                      icon: PhosphorIconsFill.warningCircle,
                      label: "Emergencia",
                      color: Colors.redAccent,
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.red],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () async {
                        final Uri callUri = Uri(scheme: 'tel', path: '911');
                        if (await canLaunchUrl(callUri)) {
                          await launchUrl(callUri);
                        } else {
                          _mostrarSnackBar(context,
                              "No se pudo iniciar la llamada",
                              exito: false);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Beneficios
              Row(
                children: [
                  Expanded(
                      child: _benefitTile(
                          PhosphorIconsFill.lightning, "Atención rápida")),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _benefitTile(
                          PhosphorIconsFill.shieldCheck, "Pago seguro")),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _benefitTile(
                          PhosphorIconsFill.star, "Médicos calificados")),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                "Noticias de salud",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 14),
              glassCard(
                padding: EdgeInsets.zero,
                child: const NoticiasCarousel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fondoGradiente({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? null : const Color(0xFFF5F5F5),
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: child,
    );
  }


  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        title: Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? "assets/logoblanco.png"
              : "assets/logonegro.png",
          height: 36,
        ),

        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? PhosphorIconsFill.sunDim
                  : PhosphorIconsFill.moonStars,
            ),

            // 🔥 ESTE ES EL CAMBIO REAL Y ÚNICO NECESARIO
            onPressed: () {
              widget.onToggleTheme();  // Notifica al main
              setState(() {});         // Obliga a HomeScreen a redibujar
            },
          ),
        ],
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _vistaHomePrincipal(),
          RecetasScreen(
            pacienteUuid: _userId ?? "",
            token: _userToken ?? "",
          ),
          ConsultasScreen(
            pacienteUuid: _userId ?? "",
          ),
          PerfilScreen(
            userId: _userId ?? "",
          ),
        ],
      ),
      bottomNavigationBar: DocYaBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
