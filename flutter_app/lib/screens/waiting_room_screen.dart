import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import 'consultation_screen.dart';

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
  String? _jitsiUrl;
  int? _appointmentId;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _posicion = widget.posicion;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

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
            setState(() {
              _estado = 'asignada';
              _doctorNombre = data['doctor_nombre'] as String?;
              _jitsiUrl = data['jitsi_url'] as String?;
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
        _jitsiUrl = status['jitsi_url'] as String?;
        _appointmentId = status['appointment_id'] as int?;
      });
      if (_estado == 'asignada' || _estado == 'en_curso') {
        _irAConsulta();
      }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Salir de la cola?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Perderás tu lugar en la fila.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quedarme',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Salir'),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelar();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                      onPressed: _cancelar,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'En espera',
                            style: TextStyle(
                              color: AppColors.accentDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Animación de pulso
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final scale = 1.0 + _pulseCtrl.value * 0.08;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE53E3E).withOpacity(0.1 +
                              _pulseCtrl.value * 0.05),
                          border: Border.all(
                            color: const Color(0xFFE53E3E).withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFF4444),
                                  Color(0xFFCC0000),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.medical_services_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),

                // Título
                const Text(
                  'Conectando con un médico',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _posicion <= 1
                      ? 'Eres el siguiente en la fila'
                      : 'Hay $_posicion personas antes que tú',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Card de posición
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [AppTheme.cardShadow],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCell(
                        label: 'Posición',
                        value: '#$_posicion',
                        icon: Icons.queue_rounded,
                        color: AppColors.primaryLight,
                      ),
                      Container(
                          width: 1, height: 40, color: AppColors.cardBorder),
                      _StatCell(
                        label: 'Espera aprox.',
                        value: '~${(_posicion * 8)} min',
                        icon: Icons.access_time_rounded,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Mensaje de estado
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _doctorNombre != null
                              ? 'Te asignamos al Dr. $_doctorNombre'
                              : 'Buscando el médico disponible más cercano...',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Botón cancelar
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancelar y salir'),
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

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textHint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
