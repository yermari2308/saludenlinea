import 'package:flutter/material.dart';
import '../design_system.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'medical_record_screen.dart';
import 'hra_screen.dart';
import 'subscription_screen.dart';
import 'wearables_screen.dart';
import 'legal_screen.dart';

/// Perfil — Design System 2.0. Hero de tinta (sin AppBar tradicional),
/// bento de accesos consolidado en un único componente reutilizable.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Patient? _patient;
  bool _loading = true;
  int _expedientePct = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ApiService.getMyProfile();
      if (mounted) setState(() => _patient = p);
      ApiService.getMedicalRecord().then((rec) {
        if (mounted) setState(() => _expedientePct = rec['completitud_pct'] as int? ?? 0);
      }).catchError((_) {});
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _eliminarCuenta() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DSRadius.rMd),
        title: const Text('Eliminar cuenta', style: TextStyle(fontWeight: FontWeight.w800, color: DSColors.coral)),
        content: const Text(
          'Esta acción es permanente: tus datos personales serán anonimizados y '
          'no podrás volver a iniciar sesión.\n\n'
          'Tus registros clínicos se conservan de forma anónima por el plazo que '
          'exige la ley costarricense.\n\n¿Deseas continuar?',
          style: DSText.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: DSColors.coral, foregroundColor: Colors.white),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteMyAccount();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: DSColors.coral));
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DSRadius.rMd),
        title: const Text('Cerrar sesión', style: DSText.headline),
        content: const Text('¿Estás seguro de que deseas salir?', style: DSText.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: DSColors.coral, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DSColors.brand))
          : _patient == null
              ? _buildError()
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, 120),
                    children: [
                      _buildHero(),
                      const SizedBox(height: DS.s3),
                      const DSSectionHeader(title: 'Contacto'),
                      DSCard(
                        child: Column(children: [
                          _InfoRow(
                            icon: Icons.phone_rounded,
                            label: 'Teléfono',
                            value: _patient!.telefono.isEmpty ? 'No registrado' : _patient!.telefono,
                            empty: _patient!.telefono.isEmpty,
                          ),
                          const Divider(height: DS.s3, color: DSColors.line),
                          _InfoRow(icon: Icons.email_rounded, label: 'Correo electrónico', value: _patient!.email),
                        ]),
                      ),
                      const SizedBox(height: DS.s3),
                      const DSSectionHeader(title: 'Tu salud'),
                      _ProfileBanner(
                        icon: Icons.workspace_premium_rounded,
                        color: DSColors.brand,
                        titulo: 'Planes de suscripción',
                        subtitulo: 'Consultas ilimitadas desde \$9.99/mes',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                      ),
                      const SizedBox(height: DS.s1),
                      _ProfileBanner(
                        icon: Icons.watch_rounded,
                        color: const Color(0xFFF59E0B),
                        titulo: 'Actividad física',
                        subtitulo: 'Conectá tu reloj vía Health Connect',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WearablesScreen())),
                      ),
                      const SizedBox(height: DS.s1),
                      _ProfileBanner(
                        icon: Icons.monitor_heart_rounded,
                        color: DSColors.mint,
                        titulo: 'Evaluación de salud (HRA)',
                        subtitulo: 'Respondé 6 preguntas, recibí tu semáforo',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HraScreen())),
                      ),
                      const SizedBox(height: DS.s1),
                      _ProfileBanner(
                        icon: Icons.folder_shared_rounded,
                        color: _expedientePct >= 80 ? DSColors.mint : DSColors.brand,
                        titulo: 'Expediente clínico',
                        subtitulo: 'EXP-${_patient!.id.toString().padLeft(6, '0')} · $_expedientePct% completo',
                        progreso: _expedientePct / 100,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalRecordScreen()));
                          _load();
                        },
                      ),
                      if (_patient!.historial.isNotEmpty) ...[
                        const SizedBox(height: DS.s3),
                        const DSSectionHeader(title: 'Historial'),
                        DSCard(
                          child: Text(_patient!.historial,
                              style: const TextStyle(color: DSColors.textMid, fontSize: 14, height: 1.5)),
                        ),
                      ],
                      const SizedBox(height: DS.s3),
                      const DSSectionHeader(title: 'Legal'),
                      _LegalLink(label: 'Términos y Condiciones',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'terminos')))),
                      const SizedBox(height: 8),
                      _LegalLink(label: 'Política de Privacidad',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'privacidad')))),
                      const SizedBox(height: 8),
                      _LegalLink(label: 'Consentimiento informado',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'consentimiento')))),
                      const SizedBox(height: DS.s4),
                      DSButton(label: 'Cerrar sesión', icon: Icons.logout_rounded, color: DSColors.ink, onTap: _logout),
                      const SizedBox(height: DS.s1),
                      Center(
                        child: TextButton(
                          onPressed: _eliminarCuenta,
                          child: Text('Eliminar mi cuenta', style: TextStyle(color: DSColors.coral.withOpacity(0.75), fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHero() {
    final initials = (_patient?.nombre.length ?? 0) >= 2
        ? _patient!.nombre.substring(0, 2).toUpperCase()
        : (_patient?.nombre ?? 'U').toUpperCase();

    return DSInkCard(
      padding: const EdgeInsets.all(DS.s3),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [DSColors.brand, Color(0xFF7C74F2)]),
              shape: BoxShape.circle,
              boxShadow: DSElevation.glow(DSColors.brand),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: DS.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_patient!.nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(height: 3),
                Text(_patient!.email, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: DSColors.coral.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.person_off_rounded, size: 48, color: DSColors.coral),
            ),
            const SizedBox(height: DS.s2),
            const Text('No se pudo cargar el perfil', style: DSText.headline),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Cerrar sesión'),
              onPressed: () async {
                await ApiService.logout();
                if (!mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              style: OutlinedButton.styleFrom(foregroundColor: DSColors.coral, side: BorderSide(color: DSColors.coral.withOpacity(0.4))),
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool empty;

  const _InfoRow({required this.icon, required this.label, required this.value, this.empty = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: DSColors.brandSoft, shape: BoxShape.circle),
            child: Icon(icon, color: DSColors.brand, size: 17),
          ),
          const SizedBox(width: DS.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DSText.caption),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: empty ? DSColors.textFaint : DSColors.textStrong, fontSize: 14.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );
}

/// Banner de acceso a sección — consolida los 4 duplicados anteriores.
class _ProfileBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final String subtitulo;
  final double? progreso;
  final VoidCallback onTap;

  const _ProfileBanner({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    this.progreso,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => DSCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: DS.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: DSText.headline),
                  const SizedBox(height: 3),
                  Text(subtitulo, style: DSText.label),
                  if (progreso != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progreso, minHeight: 4,
                        backgroundColor: DSColors.line,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: DSColors.textFaint),
          ],
        ),
      );
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => DSCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: DS.s2, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 17, color: DSColors.textFaint),
            const SizedBox(width: DS.s2),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DSColors.textStrong))),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: DSColors.textFaint),
          ],
        ),
      );
}
