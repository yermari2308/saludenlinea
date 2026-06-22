import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../services/doh_client.dart';

class ChatScreen extends StatefulWidget {
  final int citaId;
  final String remitente; // "paciente" o "doctor"
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

  @override
  void initState() {
    super.initState();
    _conectar();
  }

  Future<void> _conectar() async {
    final wsBase = ApiService.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    var uri = Uri.parse(
      '$wsBase/api/chat/ws/${widget.citaId}/${widget.remitente}/${widget.remitenteId}',
    );
    uri = await DohClient.resolveWsUri(uri);
    _channel = WebSocketChannel.connect(uri);
    setState(() => _conectado = true);

    _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        setState(() => _mensajes.add(msg));
        Future.delayed(const Duration(milliseconds: 100), _scrollAbajo);
      },
      onDone: () => setState(() => _conectado = false),
      onError: (_) => setState(() => _conectado = false),
    );
  }

  void _scrollAbajo() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
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
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 18,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nombreOtro,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(
                  _conectado ? 'En línea' : 'Desconectado',
                  style: TextStyle(
                      fontSize: 11,
                      color: _conectado ? Colors.greenAccent : Colors.white54),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (!_conectado)
            Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Sin conexión. Reconectando...',
                          style: TextStyle(color: Colors.red, fontSize: 12))),
                  TextButton(
                    onPressed: _conectar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _mensajes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Inicia la conversación',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _mensajes.length,
                    itemBuilder: (_, i) => _BurbujaMensaje(
                      msg: _mensajes[i],
                      esMio: _esMio(_mensajes[i]),
                    ),
                  ),
          ),
          _BarraEnvio(
            controller: _controller,
            onEnviar: _enviar,
            habilitado: _conectado,
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
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: esMio ? const Color(0xFF1976D2) : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment:
              esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg['mensaje'] as String,
              style: TextStyle(
                  color: esMio ? Colors.white : Colors.black87, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              _hora(msg['enviado_en'] as String),
              style: TextStyle(
                  fontSize: 10,
                  color: esMio ? Colors.white60 : Colors.grey),
            ),
          ],
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

class _BarraEnvio extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEnviar;
  final bool habilitado;

  const _BarraEnvio({
    required this.controller,
    required this.onEnviar,
    required this.habilitado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onEnviar(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor:
                habilitado ? const Color(0xFF1976D2) : Colors.grey,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: habilitado ? onEnviar : null,
            ),
          ),
        ],
      ),
    );
  }
}
