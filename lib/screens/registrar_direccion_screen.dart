// ============================================================
//  REGISTRAR DIRECCIÓN – DOCYA (Glass Premium + Light/Dark + FIX PLACES API)
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../widgets/docya_snackbar.dart';
// apple = AIzaSyDDxc609CsgE8Yt_IR-K-YO5U8aXqXe1NU
//android = AIzaSyC8Y8FEaW0tTRjySibAbNSVQ8DJRhzIIYI
// back AIzaSyDVv_barlVwHJTgLF66dP4ESUffCBuS3uA acca se usa la del back
const kGoogleApiKey = "AIzaSyDVv_barlVwHJTgLF66dP4ESUffCBuS3uA";

class RegistrarDireccionScreen extends StatefulWidget {
  final String? nombreUsuario;
  final String? userId;
  final void Function(Map<String, dynamic> datos)? onSaved;

  const RegistrarDireccionScreen({
    super.key,
    this.nombreUsuario,
    this.userId,
    this.onSaved,
  });

  @override
  State<RegistrarDireccionScreen> createState() =>
      _RegistrarDireccionScreenState();
}

class _RegistrarDireccionScreenState extends State<RegistrarDireccionScreen> {
  LatLng? selectedLocation;
  GoogleMapController? mapController;

  bool cargando = false;

  final TextEditingController direccionCtrl = TextEditingController();
  final TextEditingController pisoCtrl = TextEditingController();
  final TextEditingController deptoCtrl = TextEditingController();
  final TextEditingController indicacionesCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();

  // ✔ Tema oscuro DocYa (lo usaremos en ambos modos)
  final String mapStyleDark = '''
  [
    {"elementType": "geometry","stylers":[{"color":"#122932"}]},
    {"elementType": "labels.text.fill","stylers":[{"color":"#E0F2F1"}]},
    {"elementType": "labels.text.stroke","stylers":[{"color":"#0B1A22"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#155E63"}]},
    {"featureType":"water","stylers":[{"color":"#0C2F3A"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _cargarDireccionGuardada();
  }

  void _onMapCreated(GoogleMapController c) {
    mapController = c;

    // 🔥 Nuevo → usar SIEMPRE tu mapa oscuro
    mapController!.setMapStyle(mapStyleDark);
  }

  // ============================================================
  // Cargar datos previos
  // ============================================================
  Future<void> _cargarDireccionGuardada() async {
    if (widget.userId == null) return;

    setState(() => cargando = true);

    final url = Uri.parse(
      "https://docya-railway-production.up.railway.app/direccion/mia/${widget.userId}",
    );

    final res = await http.get(url);
    setState(() => cargando = false);

    if (res.statusCode == 200) {
      final d = jsonDecode(utf8.decode(res.bodyBytes));

      selectedLocation = LatLng(d["lat"], d["lng"]);
      direccionCtrl.text = d["direccion"] ?? "";
      pisoCtrl.text = d["piso"] ?? "";
      deptoCtrl.text = d["depto"] ?? "";
      indicacionesCtrl.text = d["indicaciones"] ?? "";
      telefonoCtrl.text = d["telefono_contacto"] ?? "";

      setState(() {});
    }
  }

  // ============================================================
  // Obtener ubicación actual
  // ============================================================
  Future<void> _obtenerMiUbicacion() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        DocYaSnackbar.show(
          context,
          title: "GPS desactivado",
          message: "Activá el GPS para continuar",
          type: SnackType.warning,
        );
        return;
      }

      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
        if (p == LocationPermission.denied) return;
      }

      if (p == LocationPermission.deniedForever) {
        DocYaSnackbar.show(
          context,
          title: "Permiso bloqueado",
          message: "Habilitá el permiso desde Ajustes",
          type: SnackType.error,
        );
        return;
      }

      setState(() => cargando = true);

      Position pos = await Geolocator.getCurrentPosition();
      selectedLocation = LatLng(pos.latitude, pos.longitude);

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(selectedLocation!, 17),
      );

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
        localeIdentifier: "es_AR",
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        direccionCtrl.text =
            "${p.street ?? ''} ${p.subThoroughfare ?? ''}, ${p.locality ?? ''}";
      }

      DocYaSnackbar.show(
        context,
        title: "Ubicación lista",
        message: "Ubicación actual cargada",
        type: SnackType.success,
      );
    } catch (e) {
      DocYaSnackbar.show(
        context,
        title: "Error",
        message: "$e",
        type: SnackType.error,
      );
    } finally {
      setState(() => cargando = false);
    }
  }

  // ============================================================
  // buscador Places (FIX REAL)
  // ============================================================
  Future<void> _buscarDetalleLugar(Prediction p) async {
    if (p.placeId == null) return;

    try {
      final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=${p.placeId}&key=$kGoogleApiKey",
      );

      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data["status"] == "OK") {
        final loc = data["result"]["geometry"]["location"];
        selectedLocation = LatLng(loc["lat"], loc["lng"]);

        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(selectedLocation!, 17),
        );
      }
    } catch (e) {
      DocYaSnackbar.show(
        context,
        title: "Error",
        message: "$e",
        type: SnackType.error,
      );
    }
  }
  // ============================================================
  //  GUARDAR DIRECCIÓN – FUNCIONAL COMPLETO
  // ============================================================
  Future<void> _guardarDireccion() async {
    if (selectedLocation == null || widget.userId == null) {
      DocYaSnackbar.show(
        context,
        title: "Faltan datos",
        message: "Seleccioná una ubicación antes de guardar",
        type: SnackType.warning,
      );
      return;
    }

    setState(() => cargando = true);

    final res = await http.post(
      Uri.parse(
        "https://docya-railway-production.up.railway.app/direccion/guardar",
      ),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": widget.userId,
        "lat": selectedLocation!.latitude,
        "lng": selectedLocation!.longitude,
        "direccion": direccionCtrl.text,
        "piso": pisoCtrl.text,
        "depto": deptoCtrl.text,
        "indicaciones": indicacionesCtrl.text,
        "telefono_contacto": telefonoCtrl.text,
      }),
    );

    setState(() => cargando = false);

    if (res.statusCode == 200) {
      final datos = {
        "direccion": direccionCtrl.text,
        "piso": pisoCtrl.text,
        "depto": deptoCtrl.text,
        "indicaciones": indicacionesCtrl.text,
        "telefono": telefonoCtrl.text,
        "lat": selectedLocation!.latitude,
        "lng": selectedLocation!.longitude,
      };

      DocYaSnackbar.show(
        context,
        title: "Dirección guardada",
        message: "Se guardó tu dirección con éxito",
        type: SnackType.success,
      );

      if (widget.onSaved != null) {
        widget.onSaved!(datos);
      } else {
        Navigator.pop(context, datos);
      }
    } else {
      DocYaSnackbar.show(
        context,
        title: "Error",
        message: "No se pudo guardar la dirección",
        type: SnackType.error,
      );
    }
  }

  // ============================================================
  // GLASS CARD
  // ============================================================
  Widget glassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cargando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "Registrar dirección",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hola ${widget.nombreUsuario ?? "usuario"}",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),
                Text(
                  "Ingresá tu dirección para poder enviarte un profesional.",
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),

                const SizedBox(height: 20),

                // ---------------------------------------
                // BOTÓN UBICACIÓN ACTUAL
                // ---------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _obtenerMiUbicacion,
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    label: const Text(
                      "Usar mi ubicación actual",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

       
// ---------------------------------------
// AUTOCOMPLETE (FIX COMPLETO)
// ---------------------------------------
                glassCard(
                  child: GooglePlaceAutoCompleteTextField(
                    textEditingController: direccionCtrl,
                    googleAPIKey: kGoogleApiKey,

                    debounceTime: 600,
                    countries: ["ar"],

                    // FIX ✔✔
                    isLatLngRequired: true,
                    getPlaceDetailWithLatLng: (Prediction p) async {
                      if (p.placeId != null) {
                        await _buscarDetalleLugar(p);
                      }
                    },

                    inputDecoration: InputDecoration(
                      hintText: "Buscar dirección...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      border: InputBorder.none,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF14B8A6),
                      ),
                    ),

                    itemClick: (Prediction p) async {
                      direccionCtrl.text = p.description ?? "";
                      direccionCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: direccionCtrl.text.length),
                      );

                      if (p.placeId != null) {
                        await _buscarDetalleLugar(p);
                      }
                    },
                  ),
                ),


                const SizedBox(height: 16),

                // ---------------------------------------
                // GOOGLE MAP
                // ---------------------------------------
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: selectedLocation ??
                            const LatLng(-34.6037, -58.3816),
                        zoom: selectedLocation != null ? 16 : 13,
                      ),
                      markers: selectedLocation != null
                          ? {
                              Marker(
                                markerId: const MarkerId("sel"),
                                position: selectedLocation!,
                              )
                            }
                          : {},
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                glassCard(child: _campo("Piso", pisoCtrl)),
                glassCard(child: _campo("Depto", deptoCtrl)),
                glassCard(child: _campo("Indicaciones", indicacionesCtrl)),
                glassCard(child: _campo("Teléfono", telefonoCtrl)),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _guardarDireccion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "Confirmar dirección",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: ctrl,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        border: InputBorder.none,
      ),
    );
  }
}