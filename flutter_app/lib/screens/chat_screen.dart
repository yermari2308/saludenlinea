import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

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
    _conectar();
  }

  Future<void> _conectar() async {
    if (!mounted) return;
    setState(() { _conectando = true; });

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
    final delay = Duration(seconds: _intentos * 2);
    _reconnectTimer = Timer(delay, _conectar);
  }

  void _scrollAbajo() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
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

  bool _esMio(Map<String, dynamic> msg) =>
      msg['remitente'] == widget.remitente;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            GradientAvatar(
              initials: widget.nombreOtro.substring(0, 1),
              radius: 18,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nombreOtro,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _conectado
                            ? AppColors.accent
                            : _conectando
                                ? Colors.orange
                                : Colors.red.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _conectado
                          ? 'En línea'
                          : _conectando
                              ? 'Conectando...'
                              : 'Desconectado',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner de reconexión
          if (!_conectado && !_conectando) ...[
            Material(
              color: AppColors.error.withOpacity(0.1),
              child: InkWell(
                onTap: () { _intentos = 0; _conectar(); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Sin conexión — toca para reintentar',
                            style: TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                      const Icon(Icons.refresh_rounded, color: AppColors.error, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // Lista de mensajes
          Expanded(
            child: _mensajes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: AppColors.primaryLight),
                        ),
                        const SizedBox(height: 14),
                        const Text('Inicia la conversación',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        const Text('Los mensajes son privados y seguros',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    itemCount: _mensajes.length,
                    itemBuilder: (_, i) => _BurbujaMensaje(
                      msg: _mensajes[i],
                      esMio: _esMio(_mensajes[i]),
                    ),
                  ),
          ),
          // Barra de envío
          Container(
            padding: EdgeInsets.fromLTRB(
                12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.cardBorder)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.cardBorder)),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _enviar(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _conectado ? _enviar : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _conectado
                            ? const LinearGradient(
                                colors: [AppColors.primaryLight, AppColors.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _conectado ? null : AppColors.textHint,
                        shape: BoxShape.circle,
                        boxShadow: _conectado
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryLight.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
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
}

class _BurbujaMensaje extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool esMio;

  const _BurbujaMensaje({required this.msg, required this.esMio});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: Container(
            decoration: BoxDecoration(
              gradient: esMio
                  ? const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: esMio ? null : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(esMio ? 18 : 4),
                bottomRight: Radius.circular(esMio ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: (esMio ? AppColors.primaryLight : Colors.black)
                      .withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment:
                  esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  msg['mensaje'] as String,
                  style: TextStyle(
                    color: esMio ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hora(msg['enviado_en'] as String),
                  style: TextStyle(
                    fontSize: 10,
                    color: esMio
                        ? Colors.white.withOpacity(0.6)
                        : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hora(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
