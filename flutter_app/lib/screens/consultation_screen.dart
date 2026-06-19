import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ConsultationScreen extends StatefulWidget {
  final int appointmentId;
  const ConsultationScreen({super.key, required this.appointmentId});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  bool _loading = true;
  String? _jitsiUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final data = await ApiService.getConsultSession(widget.appointmentId);
      setState(() {
        _jitsiUrl = data['jitsi_url'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _abrirVideollamada() async {
    if (_jitsiUrl != null) {
      final uri = Uri.parse(_jitsiUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Videoconsulta'),
        backgroundColor: const Color(0xFF1a3a5c),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () { setState(() { _loading = true; _error = null; }); _loadSession(); },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icono principal
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a3a5c),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(Icons.videocam, size: 52, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Tu sala de videoconsulta está lista',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1a3a5c),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Al hacer clic en el botón se abrirá la videollamada en una nueva pestaña. '
                        'Asegúrate de permitir el acceso a tu cámara y micrófono.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Instrucciones paso a paso
                      _Paso(
                        numero: '1',
                        titulo: 'Haz clic en "Entrar a la consulta"',
                        descripcion: 'Se abrirá Jitsi Meet en una nueva pestaña.',
                        icono: Icons.touch_app,
                      ),
                      _Paso(
                        numero: '2',
                        titulo: 'Permite cámara y micrófono',
                        descripcion: 'El navegador te pedirá permiso. Acepta para que el médico pueda verte.',
                        icono: Icons.camera_alt,
                      ),
                      _Paso(
                        numero: '3',
                        titulo: 'Espera al médico',
                        descripcion: 'El médico entrará a la misma sala. La consulta comenzará automáticamente.',
                        icono: Icons.access_time,
                      ),
                      _Paso(
                        numero: '4',
                        titulo: 'Al terminar',
                        descripcion: 'Cierra la pestaña. Tu receta aparecerá en "Mis Citas" al finalizar.',
                        icono: Icons.check_circle_outline,
                      ),

                      const SizedBox(height: 32),

                      // Botón principal
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _abrirVideollamada,
                          icon: const Icon(Icons.video_call, size: 28),
                          label: const Text(
                            'Entrar a la consulta',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ecc71),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Volver a mis citas'),
                      ),

                      const SizedBox(height: 24),
                      // Info extra
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFd0e8f7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, color: Color(0xFF1a3a5c)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'La videollamada usa Jitsi Meet, una plataforma segura y gratuita. '
                                'No necesitas crear cuenta.',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF1a3a5c)),
                              ),
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

class _Paso extends StatelessWidget {
  final String numero;
  final String titulo;
  final String descripcion;
  final IconData icono;

  const _Paso({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1a3a5c),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                numero,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(descripcion,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Icon(icono, color: const Color(0xFF2ecc71), size: 22),
        ],
      ),
    );
  }
}
