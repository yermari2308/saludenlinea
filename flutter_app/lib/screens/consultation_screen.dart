import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
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
  bool _finalizada = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getConsultSession(widget.appointmentId);
      setState(() {
        _jitsiUrl = data['jitsi_url'] as String?;
        _loading = false;
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('finalizada')) {
        setState(() { _finalizada = true; _loading = false; });
      } else {
        setState(() { _error = msg; _loading = false; });
      }
    }
  }

  Future<void> _abrirVideollamada() async {
    if (_jitsiUrl == null) return;
    final uri = Uri.parse(_jitsiUrl!);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo abrir: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Videoconsulta'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight))
          : _finalizada
              ? _buildFinalizada()
              : _error != null
                  ? _buildError()
                  : _buildReady(),
    );
  }

  Widget _buildFinalizada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.accentDark.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 54, color: AppColors.accentDark),
            ),
            const SizedBox(height: 24),
            const Text(
              'Consulta Finalizada',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta consulta fue completada. Revisa "Mis Citas" para ver tu receta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Volver a mis citas',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadSession,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReady() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        children: [
          // Hero icon
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.videocam_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tu sala está lista',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'La videollamada se abrirá en otra app. Permite acceso a cámara y micrófono.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Pasos
          _buildPasos(),
          const SizedBox(height: 32),
          // Botón principal
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _abrirVideollamada,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_call_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Entrar a la consulta',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver a mis citas',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 20),
          // Nota Jitsi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: AppColors.primaryLight, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Videollamada cifrada con Jitsi Meet. No necesitas crear cuenta.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasos() {
    final pasos = [
      (Icons.touch_app_rounded, 'Toca "Entrar a la consulta"',
          'Se abrirá Jitsi Meet automáticamente.'),
      (Icons.camera_alt_rounded, 'Permite cámara y micrófono',
          'Acepta los permisos para que el médico pueda verte.'),
      (Icons.access_time_rounded, 'Espera al médico',
          'Permanece en la sala, el médico entrará en breve.'),
      (Icons.check_circle_outline_rounded, 'Al terminar',
          'Cierra la pestaña. Tu receta aparecerá en Mis Citas.'),
    ];

    return Column(
      children: pasos
          .asMap()
          .entries
          .map((e) => _PasoTile(
                numero: (e.key + 1).toString(),
                icon: e.value.$1,
                titulo: e.value.$2,
                descripcion: e.value.$3,
                isLast: e.key == pasos.length - 1,
              ))
          .toList(),
    );
  }
}

class _PasoTile extends StatelessWidget {
  final String numero;
  final IconData icon;
  final String titulo;
  final String descripcion;
  final bool isLast;

  const _PasoTile({
    required this.numero,
    required this.icon,
    required this.titulo,
    required this.descripcion,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    numero,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: AppColors.cardBorder,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(titulo,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 3),
                        Text(descripcion,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(icon, color: AppColors.accent, size: 20),
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
