import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'consultation_screen.dart';

/// Sala de espera de urgencias — Design System 2.0. Inmersión total en tinta
/// con ondas de urgencia expansivas y métricas tabulares en vivo.
class WaitingRoomScreen extends StatefulWidget {
  final int queueId;
  final int posicion;
  final int pacienteId;

  const WaitingRoomScreen({
    super.key,
    required this.queueId,
    required this.posicion,
    required this.pacienteId,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Timer _pollTimer;
  WebSocketChannel? _wsChannel;

  int _posicion = 1;
  String _estado = 'esperando';
  String? _doctorNombre;
  int? _appointmentId;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _posicion = widget.posicion;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _conectarWs();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  void _conectarWs() {
    try {
      final wsBase = ApiService.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$wsBase/api/urgent/ws/${widget.pacienteId}');
      _wsChannel = WebSocketChannel.connect(uri);
      _wsChannel!.stream.listen(
        (raw) {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['event'] == 'asignada') {
            if (!mounted) return;
            setState(() {
              _estado = 'asignada';
              _doctorNombre = data['doctor_nombre'] as String?;
              _appointmentId = data['appointment_id'] as int?;
            });
            _irAConsulta();
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _poll() async {
    if (_navigated || !mounted) return;
    try {
      final status = await ApiService.getUrgentStatus();
      if (!mounted) return;
      setState(() {
        _estado = status['estado'] as String? ?? _estado;
        _posicion = status['posicion'] as int? ?? _posicion;
        _doctorNombre = status['doctor_nombre'] as String?;
        _appointmentId = status['appointment_id'] as int?;
      });
      if (_estado == 'asignada' || _estado == 'en_curso') _irAConsulta();
    } catch (_) {}
  }

  void _irAConsulta() {
    if (_navigated || _appointmentId == null) return;
    _navigated = true;
    _pollTimer.cancel();
    _wsChannel?.sink.close();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConsultationScreen(appointmentId: _appointmentId!),
        ),
      );
    }
  }

  Future<void> _cancelar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: DSColors.surface,
        shape: RoundedRectangleBorder(borderRadius: DSRadius.rMd),
        title: const Text('¿Salir de la cola?', style: DSText.headline),
        content: Text('Vas a perder tu lugar en la fila y tendrías que empezar de nuevo.',
            style: DSText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quedarme',
                style: TextStyle(color: DSColors.textMid, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir',
                style: TextStyle(color: DSColors.coral, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.cancelUrgentQueue();
      } catch (_) {}
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pollTimer.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asignado = _doctorNombre != null;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _cancelar();
      },
      child: Scaffold(
        backgroundColor: DSColors.ink,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [DSColors.ink, DSColors.inkSoft],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.s3, DS.s2, DS.s3, DS.s3),
              child: Column(
                children: [
                  // ── Barra superior ────────────────────────────────────
                  Row(
                    children: [
                      DSPressable(
                        onTap: _cancelar,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: DSColors.coral.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(
                                  color: DSColors.coral, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            const Text('ATENCIÓN URGENTE',
                                style: TextStyle(
                                    color: DSColors.coral, fontSize: 10,
                                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // ── Ondas de urgencia ─────────────────────────────────
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          _onda(0),
                          _onda(0.33),
                          _onda(0.66),
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [DSColors.coral, DSColors.coralDeep],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: DSElevation.glow(DSColors.coral),
                            ),
                            child: Icon(
                              asignado ? Icons.check_rounded : Icons.medical_services_rounded,
                              color: Colors.white, size: 44,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DS.s5),

                  Text(
                    asignado ? '¡Médico encontrado!' : 'Conectando con un médico',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24,
                        fontWeight: FontWeight.w800, letterSpacing: -0.6),
                  ),
                  const SizedBox(height: DS.s1),
                  Text(
                    asignado
                        ? 'Te estamos llevando a la consulta…'
                        : _posicion <= 1
                            ? 'Sos el siguiente en la fila'
                            : 'Hay $_posicion personas antes que vos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14.5),
                  ),
                  const SizedBox(height: DS.s4),

                  // ── Métricas ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: DS.s3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: DSRadius.rMd,
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Metrica(
                            icon: Icons.tag_rounded,
                            valor: '$_posicion',
                            etiqueta: 'Tu posición',
                            color: DSColors.brand,
                          ),
                        ),
                        Container(width: 1, height: 44, color: Colors.white.withOpacity(0.10)),
                        Expanded(
                          child: _Metrica(
                            icon: Icons.schedule_rounded,
                            valor: '~${_posicion * 8}',
                            etiqueta: 'Minutos aprox.',
                            color: DSColors.mint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DS.s3),

                  // ── Estado en vivo ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(DS.s2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: DSRadius.rSm,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 17, height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: asignado ? DSColors.mint : DSColors.brand,
                          ),
                        ),
                        const SizedBox(width: DS.s2),
                        Expanded(
                          child: Text(
                            asignado
                                ? 'Asignado al Dr. $_doctorNombre'
                                : 'Buscando el médico disponible más cercano…',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  DSPressable(
                    onTap: _cancelar,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.4),
                      ),
                      child: Center(
                        child: Text('Cancelar y salir',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Onda expansiva desfasada que se desvanece al crecer.
  Widget _onda(double offset) {
    final t = (_pulseCtrl.value + offset) % 1.0;
    return Container(
      width: 104 + (116 * t),
      height: 104 + (116 * t),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: DSColors.coral.withOpacity((1 - t) * 0.45),
          width: 2,
        ),
      ),
    );
  }
}

/// Métrica de la sala de espera con número tabular.
class _Metrica extends StatelessWidget {
  final IconData icon;
  final String valor;
  final String etiqueta;
  final Color color;

  const _Metrica({
    required this.icon,
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 7),
          Text(valor,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(etiqueta,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      );
}
