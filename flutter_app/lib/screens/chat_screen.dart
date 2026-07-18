import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Chat de consulta — Design System 2.0. Encabezado de tinta con presencia
/// en vivo, burbujas índigo/superficie y compositor flotante.
class ChatScreen extends StatefulWidget {
  final int citaId;
  final String remitente;
  final int remitenteId;
  final String nombreOtro;

  const ChatScreen({
    super.key,
    required this.citaId,
    required this.remitente,
    required this.remitenteId,
    required this.nombreOtro,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  WebSocketChannel? _channel;
  final List<Map<String, dynamic>> _mensajes = [];
  bool _conectado = false;
  bool _conectando = true;
  Timer? _reconnectTimer;
  int _intentos = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _conectar();
  }

  Future<void> _conectar() async {
    if (!mounted) return;
    setState(() => _conectando = true);

    _channel?.sink.close();

    final wsBase = ApiService.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse(
      '$wsBase/api/chat/ws/${widget.citaId}/${widget.remitente}/${widget.remitenteId}',
    );

    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;

      if (!mounted) {
        channel.sink.close();
        return;
      }

      _channel = channel;
      _intentos = 0;
      setState(() { _conectado = true; _conectando = false; });

      channel.stream.listen(
        (data) {
          if (!mounted) return;
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          setState(() => _mensajes.add(msg));
          Future.delayed(const Duration(milliseconds: 100), _scrollAbajo);
        },
        onDone: () {
          if (!mounted) return;
          setState(() { _conectado = false; _conectando = false; });
          _programarReconexion();
        },
        onError: (_) {
          if (!mounted) return;
          setState(() { _conectado = false; _conectando = false; });
          _programarReconexion();
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() { _conectado = false; _conectando = false; });
      _programarReconexion();
    }
  }

  void _programarReconexion() {
    _reconnectTimer?.cancel();
    if (_intentos >= 5) return;
    _intentos++;
    _reconnectTimer = Timer(Duration(seconds: _intentos * 2), _conectar);
  }

  void _scrollAbajo() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _enviar() {
    final texto = _controller.text.trim();
    if (texto.isEmpty || !_conectado) return;
    _channel?.sink.add(jsonEncode({'mensaje': texto}));
    _controller.clear();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _esMio(Map<String, dynamic> msg) => msg['remitente'] == widget.remitente;

  (Color, String) get _presencia => _conectado
      ? (DSColors.mint, 'En línea')
      : _conectando
          ? (const Color(0xFFF59E0B), 'Conectando…')
          : (DSColors.coral, 'Sin conexión');

  @override
  Widget build(BuildContext context) {
    final (colorPresencia, textoPresencia) = _presencia;
    final iniciales = widget.nombreOtro.isNotEmpty
        ? widget.nombreOtro.substring(0, 1).toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: DSColors.ink,
      body: Column(
        children: [
          // ── Encabezado de tinta con presencia ───────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [DSColors.ink, DSColors.inkSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DS.s2, DS.s1, DS.s2, DS.s2),
                child: Row(
                  children: [
                    DSPressable(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: DS.s1 + 4),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [DSColors.mint, Color(0xFF059669)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(iniciales,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: DS.s1 + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.nombreOtro,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15.5,
                                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(color: colorPresencia, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(textoPresencia,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.6))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, size: 11, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('Privado',
                              style: TextStyle(
                                  fontSize: 10.5, fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.75))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Cuerpo ──────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: DSColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
              ),
              child: Column(
                children: [
                  if (!_conectado && !_conectando) _bannerReconexion(),
                  Expanded(
                    child: _mensajes.isEmpty
                        ? const DSEmpty(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Iniciá la conversación',
                            message: 'Tus mensajes son privados y quedan '
                                'guardados en el expediente de esta consulta.',
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(DS.s2, DS.s3, DS.s2, DS.s2),
                            itemCount: _mensajes.length,
                            itemBuilder: (_, i) => _Burbuja(
                              msg: _mensajes[i],
                              esMio: _esMio(_mensajes[i]),
                            ),
                          ),
                  ),
                  _compositor(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerReconexion() => DSPressable(
        onTap: () { _intentos = 0; _conectar(); },
        child: Container(
          margin: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, 0),
          padding: const EdgeInsets.symmetric(horizontal: DS.s2, vertical: 12),
          decoration: BoxDecoration(
            color: DSColors.coral.withOpacity(0.10),
            borderRadius: DSRadius.rSm,
          ),
          child: Row(
            children: const [
              Icon(Icons.wifi_off_rounded, color: DSColors.coral, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text('Sin conexión — tocá para reintentar',
                    style: TextStyle(
                        color: DSColors.coral, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.refresh_rounded, color: DSColors.coral, size: 18),
            ],
          ),
        ),
      );

  Widget _compositor() {
    final puedeEnviar = _conectado && _controller.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(
          DS.s2, DS.s1 + 2, DS.s2, MediaQuery.of(context).viewInsets.bottom + DS.s1 + 2),
      decoration: const BoxDecoration(
        color: DSColors.surface,
        border: Border(top: BorderSide(color: DSColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: DSColors.canvas,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: DSColors.line, width: 1.2),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  style: const TextStyle(
                      fontSize: 14.5, color: DSColors.textStrong, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Escribí un mensaje…',
                    hintStyle: TextStyle(color: DSColors.textFaint, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: DS.s2, vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviar(),
                ),
              ),
            ),
            const SizedBox(width: DS.s1),
            DSPressable(
              onTap: puedeEnviar ? _enviar : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: puedeEnviar ? DSColors.brand : DSColors.line,
                  shape: BoxShape.circle,
                  boxShadow: puedeEnviar ? DSElevation.glow(DSColors.brand) : null,
                ),
                child: Icon(Icons.arrow_upward_rounded,
                    color: puedeEnviar ? Colors.white : DSColors.textFaint, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Burbuja de mensaje: índigo para propios, superficie para el otro.
class _Burbuja extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool esMio;

  const _Burbuja({required this.msg, required this.esMio});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: DS.s1),
        child: Align(
          alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: esMio ? DSColors.brand : DSColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(esMio ? 20 : 6),
                  bottomRight: Radius.circular(esMio ? 6 : 20),
                ),
                boxShadow: DSElevation.rest,
              ),
              child: Column(
                crossAxisAlignment:
                    esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg['mensaje'] as String? ?? '',
                    style: TextStyle(
                      color: esMio ? Colors.white : DSColors.textStrong,
                      fontSize: 14.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _hora(msg['enviado_en'] as String? ?? ''),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: esMio ? Colors.white.withOpacity(0.65) : DSColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  String _hora(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
