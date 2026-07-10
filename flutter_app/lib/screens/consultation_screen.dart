import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

/// Sala de espera — Design System 2.0. Ink hero con pulso de "sala lista",
/// CTA flotante en vez de botón embebido en el scroll.
class ConsultationScreen extends StatefulWidget {
  final int appointmentId;
  const ConsultationScreen({super.key, required this.appointmentId});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _jitsiUrl;
  String? _error;
  bool _finalizada = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
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

  Future<void> _abrirChat() async {
    final info = await ApiService.getUserInfo();
    if (!mounted) return;
    final esDoctor = (info['role'] ?? '') == 'doctor';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          citaId: widget.appointmentId,
          remitente: esDoctor ? 'doctor' : 'paciente',
          remitenteId: info['id'] ?? 0,
          nombreOtro: esDoctor ? 'Paciente' : 'Médico',
        ),
      ),
    );
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo abrir: $e'),
            backgroundColor: DSColors.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: DSColors.brand))
            : _finalizada
                ? _buildFinalizada()
                : _error != null
                    ? _buildError()
                    : _buildReady(),
      ),
    );
  }

  Widget _buildFinalizada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 108, height: 108,
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 108, height: 108,
                    decoration: const BoxDecoration(color: DSColors.mintSoft, shape: BoxShape.circle)),
                const Icon(Icons.check_rounded, size: 48, color: DSColors.mint),
              ]),
            ),
            const SizedBox(height: DS.s3),
            const Text('Consulta finalizada', style: DSText.title),
            const SizedBox(height: 8),
            const Text('Esta consulta fue completada. Revisá "Mis citas" para ver tu receta.',
                textAlign: TextAlign.center, style: DSText.body),
            const SizedBox(height: DS.s4),
            DSButton(label: 'Volver a mis citas', color: DSColors.ink, onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: DSColors.coral.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 44, color: DSColors.coral),
            ),
            const SizedBox(height: DS.s2),
            Text(_error!, textAlign: TextAlign.center, style: DSText.body),
            const SizedBox(height: DS.s3),
            DSButton(label: 'Reintentar', expanded: false, onTap: _loadSession),
          ],
        ),
      ),
    );
  }

  Widget _buildReady() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, 140),
          children: [
            // ── Hero de tinta con pulso "sala lista" ─────────────────────
            DSInkCard(
              padding: const EdgeInsets.all(DS.s4),
              child: Column(
                children: [
                  SizedBox(
                    width: 96, height: 96,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Stack(alignment: Alignment.center, children: [
                        for (final delay in [0.0, 0.5])
                          Builder(builder: (_) {
                            final t = (_pulse.value + delay) % 1.0;
                            return Opacity(
                              opacity: (1 - t) * 0.5,
                              child: Container(
                                width: 60 + t * 60,
                                height: 60 + t * 60,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: DSColors.mint, width: 1.5)),
                              ),
                            );
                          }),
                        Container(
                          width: 60, height: 60,
                          decoration: const BoxDecoration(color: DSColors.mint, shape: BoxShape.circle),
                          child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 28),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: DS.s3),
                  const Text('Tu sala está lista',
                      style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  const SizedBox(height: 6),
                  Text('La videollamada se abre en otra app · cámara y micrófono',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
                      textAlign: TextAlign.center),
                  const SizedBox(height: DS.s2),
                  const DSChip(label: 'CIFRADO DE EXTREMO A EXTREMO', color: DSColors.mint, icon: Icons.lock_rounded),
                ],
              ),
            ),
            const SizedBox(height: DS.s3),
            const DSSectionHeader(title: 'Cómo funciona'),
            Row(
              children: [
                Expanded(child: _PasoChip(icon: Icons.touch_app_rounded, texto: 'Tocá Entrar')),
                const SizedBox(width: 8),
                Expanded(child: _PasoChip(icon: Icons.camera_alt_rounded, texto: 'Permití cámara')),
                const SizedBox(width: 8),
                Expanded(child: _PasoChip(icon: Icons.check_circle_outline_rounded, texto: 'Recetá al final')),
              ],
            ),
            const SizedBox(height: DS.s2),
            DSCard(
              onTap: _abrirChat,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: DSColors.brandSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.chat_bubble_rounded, color: DSColors.brand, size: 18),
                  ),
                  const SizedBox(width: DS.s2),
                  const Expanded(
                    child: Text('Chat de la consulta', style: DSText.headline),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: DSColors.textFaint),
                ],
              ),
            ),
          ],
        ),
        // ── CTA flotante ────────────────────────────────────────────────
        Positioned(
          left: DS.s2, right: DS.s2, bottom: DS.s2,
          child: DSButton(
            label: 'Entrar a la consulta',
            icon: Icons.video_call_rounded,
            color: DSColors.mint,
            onTap: _abrirVideollamada,
          ),
        ),
      ],
    );
  }
}

class _PasoChip extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _PasoChip({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: DS.s2, horizontal: 8),
        decoration: BoxDecoration(color: DSColors.surface, borderRadius: DSRadius.rSm, boxShadow: DSElevation.rest),
        child: Column(
          children: [
            Icon(icon, color: DSColors.brand, size: 22),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DSColors.textStrong)),
          ],
        ),
      );
}
