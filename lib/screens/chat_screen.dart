import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class ChatScreen extends StatefulWidget {
  final int? consultaId;
  final String remitenteTipo; // "paciente" o "profesional"
  final String remitenteId;

  const ChatScreen({
    super.key,
    this.consultaId,
    required this.remitenteTipo,
    required this.remitenteId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;
  final List<Map<String, dynamic>> _messages = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  bool _showNewMsgIndicator = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _connectWebSocket();
    _loadHistory();
  }

  /// 🔊 Inicializar player
  void _initAudioPlayer() {
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  /// 🔊 sonido mensaje interno
  Future<void> _playSound() async {
    try {
      await _audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 40));
      await _audioPlayer.play(
        AssetSource('sounds/alerta.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      debugPrint("⚠️ Error sonido: $e");
    }
  }

  /// 🔔 vibración
  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 180, amplitude: 180);
      }
    } catch (_) {}
  }

  /// 🍞 notificación interna (no es push)
  void _mostrarNotificacionVisual() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF14B8A6).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        content: const Text(
          "💬 Nuevo mensaje recibido",
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 🔌 WebSocket
  void _connectWebSocket() {
    final url =
        "wss://docya-railway-production.up.railway.app/ws/chat/${widget.consultaId}/${widget.remitenteTipo}/${widget.remitenteId}";
    debugPrint("🔌 Conectando WS: $url");

    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen(
      (event) {
        debugPrint("📩 WS: $event");
        try {
          final data = jsonDecode(event);
          if (data is Map<String, dynamic>) {
            setState(() => _messages.add(data));

            final esMio =
                data["remitente_tipo"] == widget.remitenteTipo &&
                data["remitente_id"].toString() == widget.remitenteId;


            // 🔔 Notificar SOLO si el mensaje es del otro (evita doble push)
            if (!esMio) {
              _vibrate();
              _playSound();
              _mostrarNotificacionVisual();
              // ❌ YA NO DISPARA mostrarNotificacionLocal()
              // porque FCM YA envía la notificación real
            }

            // autoscroll
            if (_scrollController.hasClients &&
                _scrollController.offset >=
                    _scrollController.position.maxScrollExtent - 100) {
              Future.delayed(const Duration(milliseconds: 250), () {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              });
            } else {
              setState(() => _showNewMsgIndicator = true);
            }
          }
        } catch (e) {
          debugPrint("⚠️ Error WS: $e");
        }
      },
      onDone: () {
        debugPrint("🔌 WS cerrado. Reintentando...");
        Future.delayed(const Duration(seconds: 2), _connectWebSocket);
      },
      onError: (err) {
        debugPrint("❌ Error WS: $err");
      },
    );
  }

  /// 📜 historial
  Future<void> _loadHistory() async {
    final url =
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/chat";

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      final List list = jsonDecode(resp.body);
      setState(() => _messages.addAll(
          list.map((e) => e as Map<String, dynamic>).toList()));

      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  /// ✉️ enviar
  void _sendMessage() {
    if (_controller.text.trim().isEmpty || _channel == null) return;

    final msg = {"mensaje": _controller.text.trim()};
    _channel!.sink.add(jsonEncode(msg));

    _controller.clear();
    _vibrate();
    _playSound();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Chat de Consulta",
              style: TextStyle(color: Colors.white)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMine =
                      msg["remitente_tipo"] == widget.remitenteTipo &&
                      msg["remitente_id"].toString() == widget.remitenteId;


                  return Align(
                    alignment:
                        isMine ? Alignment.centerRight : Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          constraints:
                              BoxConstraints(maxWidth: screenWidth * 0.75),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isMine
                                ? const Color(0xFF14B8A6).withOpacity(0.9)
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            msg["mensaje"] ?? "",
                            style: TextStyle(
                              color: isMine ? Colors.white : Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_showNewMsgIndicator)
              GestureDetector(
                onTap: () {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                  setState(() => _showNewMsgIndicator = false);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text("⬇️ Nuevo mensaje",
                      style: TextStyle(color: Colors.white)),
                ),
              ),

            const Divider(color: Colors.white24, height: 1),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          color: Colors.white.withOpacity(0.15),
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Escribe un mensaje...",
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF14B8A6)),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
