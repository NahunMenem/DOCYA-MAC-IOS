import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../widgets/docya_snackbar.dart';
import 'terminos_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  final _name = TextEditingController();
  final _dni = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _pais;
  String? _provincia;
  String? _localidad;
  DateTime? _fechaNacimiento;
  String? _sexo;    
  bool _aceptaCondiciones = false;
  bool _loading = false;
  String? _error;

  //--------------------------------------------------------------------
  // PROVINCIAS — NO TOQUÉ NADA
  //--------------------------------------------------------------------
  final List<String> _provincias = [
    "Buenos Aires",
    "Ciudad Autónoma de Buenos Aires",
    "Catamarca",
    "Chaco",
    "Chubut",
    "Córdoba",
    "Corrientes",
    "Entre Ríos",
    "Formosa",
    "Jujuy",
    "La Pampa",
    "La Rioja",
    "Mendoza",
    "Misiones",
    "Neuquén",
    "Río Negro",
    "Salta",
    "San Juan",
    "San Luis",
    "Santa Cruz",
    "Santa Fe",
    "Santiago del Estero",
    "Tierra del Fuego",
    "Tucumán"
  ];

  List<String> _localidades = [];

  //--------------------------------------------------------------------
  // CARGA LOCALIDADES — NO TOQUÉ LÓGICA
  //--------------------------------------------------------------------
  Future<void> _cargarLocalidades(String provincia) async {
    if (provincia == "Ciudad Autónoma de Buenos Aires") {
      setState(() {
        _localidades = [
          "Comuna 1",
          "Comuna 2",
          "Comuna 3",
          "Comuna 4",
          "Comuna 5",
          "Comuna 6",
          "Comuna 7",
          "Comuna 8",
          "Comuna 9",
          "Comuna 10",
          "Comuna 11",
          "Comuna 12",
          "Comuna 13",
          "Comuna 14",
          "Comuna 15",
        ];
        _localidad = null;
      });
      return;
    }

    try {
      final encoded = Uri.encodeComponent(provincia);
      final url =
          "https://docya-railway-production.up.railway.app/localidades/$encoded";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _localidades = List<String>.from(data["localidades"]);
          _localidad = null;
        });
      } else {
        setState(() => _localidades = []);
      }
    } catch (e) {
      setState(() => _localidades = []);
    }
  }

  //--------------------------------------------------------------------
  // SUBMIT — NO TOQUÉ LÓGICA
  //--------------------------------------------------------------------
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pais == null) {
      setState(() => _error = "Selecciona tu país");
      return;
    }

    if (_pais == "Argentina" && (_provincia == null || _localidad == null)) {
      setState(() => _error = "Seleccioná provincia y localidad");
      return;
    }

    if (_fechaNacimiento == null) {
      setState(() => _error = "Selecciona tu fecha de nacimiento");
      return;
    }

    if (_sexo == null) {
      setState(() => _error = "Selecciona tu sexo");
      return;
    }


    if (!_aceptaCondiciones) {
      setState(() => _error = "Debes aceptar los Términos y Condiciones");
      return;
    }

    if (_password.text.trim() != _confirm.text.trim()) {
      setState(() => _error = "Las contraseñas no coinciden");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _auth.register(
      _name.text.trim(),
      _email.text.trim(),
      _password.text.trim(),
      dni: _dni.text.trim(),
      telefono: _phone.text.trim(),
      pais: _pais!,
      provincia: _pais == "Argentina" ? _provincia : null,
      localidad: _pais == "Argentina" ? _localidad : null,
      fechaNacimiento: _fechaNacimiento!.toIso8601String(),
      sexo: _sexo!,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result["ok"] == true) {
      Navigator.pop(context);
      DocYaSnackbar.show(
        context,
        title: "🎉 Registro exitoso",
        message: "Revisa tu correo para activar tu cuenta.",
        type: SnackType.success,
      );
    } else {
      DocYaSnackbar.show(
        context,
        title: "⚠️ Error",
        message: result["detail"] ?? "No se pudo registrar.",
        type: SnackType.error,
      );
    }
  }

  //--------------------------------------------------------------------
  // INPUTS — ahora con modo claro/oscuro
  //--------------------------------------------------------------------
  InputDecoration _input(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon,
          color: isDark ? Colors.white70 : const Color(0xFF14B8A6)),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04),
      labelStyle:
          TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.black26),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFF14B8A6), width: 2),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      bool isDark,
      {bool obs = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        obscureText: obs,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: _input(label, icon, isDark),
        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
      ),
    );
  }

  //--------------------------------------------------------------------
  // BUILD — RESPONSIVE + MODO OSCURO/CLARO
  //--------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final double paddingSide = size.width * 0.06;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: paddingSide, vertical: 20),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF203A43),
                    Color(0xFF2C5364)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : const LinearGradient(
                  colors: [
                    Color(0xFFE8F5F3),
                    Color(0xFFD9EFED),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ------------------------------
                // LOGO MODO CLARO / OSCURO
                // ------------------------------
                Image.network(
                  isDark
                      ? "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logoblanco_1_qdlnog.png"
                      : "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logo_1_svfdye.png",
                  height: 85,
                ),

                const SizedBox(height: 18),

                Text(
                  "Crear cuenta en DocYa",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                // ------------------------------
                // CARD GLASS
                // ------------------------------
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _field(_name, "Nombre y apellido", Icons.person,
                                isDark),
                            _field(_dni, "DNI / Pasaporte", Icons.badge, isDark),
                            _field(
                                _phone, "Teléfono", Icons.phone, isDark),
                            _field(_email, "Correo electrónico", Icons.email,
                                isDark),
                            _field(_password, "Contraseña", Icons.lock, isDark,
                                obs: true),
                            _field(
                                _confirm,
                                "Confirmar contraseña",
                                Icons.check,
                                isDark,
                                obs: true),

                            // ------------------------------------------------------
                            // FECHA DE NACIMIENTO
                            // ------------------------------------------------------
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime(now.year - 25),
                                    firstDate: DateTime(1900),
                                    lastDate: now,
                                    builder: (context, child) {
                                      return Theme(
                                        data: ThemeData(
                                          colorScheme: ColorScheme.light(
                                            primary: const Color(0xFF14B8A6),
                                            onPrimary: Colors.white,
                                            surface: Colors.white,
                                            onSurface: Colors.black87,
                                          ),
                                          dialogBackgroundColor: Colors.white,
                                        ),
                                        child: child!,
                                      );
                                    },

                                  );
                                  if (picked != null) {
                                    setState(() => _fechaNacimiento = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: _input("Fecha de nacimiento", Icons.cake, isDark),
                                  child: Text(
                                    _fechaNacimiento == null
                                        ? "Seleccionar fecha"
                                        : "${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}",
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ------------------------------------------------------
                            // SEXO
                            // ------------------------------------------------------
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: DropdownButtonFormField<String>(
                                value: _sexo,
                                decoration: _input("Sexo", Icons.people, isDark),
                                dropdownColor: isDark ? const Color(0xFF203A43) : Colors.white,
                                items: const [
                                  DropdownMenuItem(value: "Masculino", child: Text("Masculino")),
                                  DropdownMenuItem(value: "Femenino", child: Text("Femenino")),
                                  DropdownMenuItem(value: "Otro", child: Text("Otro / Prefiero no decir")),
                                ],
                                onChanged: (v) => setState(() => _sexo = v),
                                validator: (v) => v == null ? "Requerido" : null,
                              ),
                            ),
    

                            // ------------------------------
                            // PAÍS
                            // ------------------------------
                            DropdownButtonFormField<String>(
                              decoration:
                                  _input("País", Icons.public, isDark),
                              dropdownColor:
                                  isDark ? const Color(0xFF203A43) : Colors.white,
                              isExpanded: true,
                              value: _pais,
                              items: const [
                                DropdownMenuItem(
                                  value: "Argentina",
                                  child: Text("Argentina"),
                                ),
                                DropdownMenuItem(
                                  value: "Extranjero",
                                  child: Text("Extranjero / Turista"),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _pais = v;
                                  _provincia = null;
                                  _localidad = null;
                                  _localidades = [];
                                });
                              },
                            ),

                            const SizedBox(height: 16),

                            if (_pais == "Argentina") ...[
                              DropdownButtonFormField<String>(
                                decoration:
                                    _input("Provincia", Icons.map, isDark),
                                dropdownColor: isDark
                                    ? const Color(0xFF203A43)
                                    : Colors.white,
                                value: _provincia,
                                items: _provincias
                                    .map((p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(p),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _provincia = v;
                                    _localidad = null;
                                    _localidades = [];
                                  });
                                  if (v != null) _cargarLocalidades(v);
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                decoration: _input(
                                    "Localidad", Icons.location_city, isDark),
                                dropdownColor: isDark
                                    ? const Color(0xFF203A43)
                                    : Colors.white,
                                value: _localidad,
                                items: _localidades
                                    .map((l) => DropdownMenuItem(
                                          value: l,
                                          child: Text(l),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _localidad = v),
                              ),
                            ],

                            if (_pais == "Extranjero") ...[
                              const SizedBox(height: 12),
                              Text(
                                "🌎 Si sos turista, solo completá tus datos.\nEn la consulta elegís tu ubicación exacta.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 13),
                              ),
                            ],

                            const SizedBox(height: 14),

                            CheckboxListTile(
                              value: _aceptaCondiciones,
                              activeColor: const Color(0xFF14B8A6),
                              checkColor: Colors.white,
                              title: Text(
                                "Acepto los Términos y Condiciones",
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54),
                              ),
                              secondary: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const TerminosScreen()),
                                ),
                                child: const Text(
                                  "Ver",
                                  style: TextStyle(
                                      color: Color(0xFF14B8A6),
                                      decoration: TextDecoration.underline),
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _aceptaCondiciones = v!),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            ),

                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14B8A6),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                                child: _loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        "Crear cuenta",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),

                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "¿Ya tenés cuenta? Iniciar sesión",
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
