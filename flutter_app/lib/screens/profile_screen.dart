import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'medical_record_screen.dart';
import 'hra_screen.dart';

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
      // Cargar % expediente en paralelo, sin bloquear
      ApiService.getMedicalRecord().then((rec) {
        if (mounted) setState(() => _expedientePct = rec['completitud_pct'] as int? ?? 0);
      }).catchError((_) {});
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar sesión',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: const Text('¿Estás seguro de que deseas salir?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : _patient == null
              ? _buildError()
              : CustomScrollView(
                  slivers: [
                    _buildHeader(),
                    SliverToBoxAdapter(child: _buildBody()),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    final initials = (_patient?.nombre.length ?? 0) >= 2
        ? _patient!.nombre.substring(0, 2).toUpperCase()
        : (_patient?.nombre ?? 'U').toUpperCase();

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: _logout,
          tooltip: 'Cerrar sesión',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: AppTheme.gradientBox,
          child: Stack(
            children: [
              Positioned(
                right: -40,
                bottom: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GradientAvatar(initials: initials, radius: 44),
                      const SizedBox(height: 12),
                      Text(
                        _patient!.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _patient!.email,
                        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SectionLabel(label: 'Información de contacto'),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.phone_rounded,
            label: 'Teléfono',
            value: _patient!.telefono.isEmpty ? 'No registrado' : _patient!.telefono,
            empty: _patient!.telefono.isEmpty,
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.email_rounded,
            label: 'Correo electrónico',
            value: _patient!.email,
          ),
          const SizedBox(height: 20),
          // ── Banner HRA ────────────────────────────────────────────────
          _HraBanner(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HraScreen()),
            ),
          ),
          const SizedBox(height: 12),
          // ── Banner Expediente Clínico ──────────────────────────────────
          _ExpedienteBanner(
            pct: _expedientePct,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicalRecordScreen()),
              );
              _load();
            },
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: 'Historial médico'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: const Border(left: BorderSide(color: AppColors.accent, width: 3)),
              boxShadow: [AppTheme.cardShadow],
            ),
            child: _patient!.historial.isEmpty
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.textHint.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.medical_information_outlined,
                            color: AppColors.textHint, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Sin historial registrado',
                          style: TextStyle(color: AppColors.textHint, fontSize: 14)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.medical_information_outlined,
                                color: AppColors.accentDark, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text('Historial',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _patient!.historial,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Cerrar sesión'),
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_rounded,
                  size: 48, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            const Text('No se pudo cargar el perfil',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool empty;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.empty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryLight, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: empty ? AppColors.textHint : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner HRA ────────────────────────────────────────────────────────────────

class _HraBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _HraBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: AppColors.accentDark, width: 3)),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentDark.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assessment_rounded,
                  color: AppColors.accentDark, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evaluación de salud (HRA)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Responde 6 preguntas y recibe tu semáforo de salud',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ── Banner Expediente Clínico ─────────────────────────────────────────────────

class _ExpedienteBanner extends StatelessWidget {
  final int pct;
  final VoidCallback onTap;

  const _ExpedienteBanner({required this.pct, required this.onTap});

  Color get _barColor {
    if (pct >= 80) return AppColors.accentDark;
    if (pct >= 40) return const Color(0xFFF59E0B);
    return AppColors.primaryLight;
  }

  String get _mensaje {
    if (pct == 0) return 'Completa tu expediente para mejores diagnósticos';
    if (pct < 40) return 'Agrega más datos para diagnósticos más precisos';
    if (pct < 80) return 'Vas bien — continúa completando tu expediente';
    return 'Expediente casi completo';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: _barColor, width: 3)),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _barColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_shared_rounded, color: _barColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expediente clínico',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 5,
                      backgroundColor: AppColors.cardBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pct% — $_mensaje',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
