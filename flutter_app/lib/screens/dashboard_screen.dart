import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'consultation_screen.dart';
import 'medical_record_screen.dart';
import 'hra_screen.dart';
import 'pharmacy_screen.dart';
import 'subscription_screen.dart';
import 'wearables_screen.dart';

/// Dashboard del paciente: cada elemento responde "¿qué necesito ahora?"
class DashboardScreen extends StatefulWidget {
  final VoidCallback onConsultarAhora;
  final VoidCallback onVerMedicos;
  final VoidCallback onVerCitas;

  const DashboardScreen({
    super.key,
    required this.onConsultarAhora,
    required this.onVerMedicos,
    required this.onVerCitas,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _nombre = '';
  Appointment? _proximaCita;
  int _expedientePct = 0;
  int? _saludPct;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await ApiService.getUserInfo();
      if (mounted) setState(() => _nombre = (info['nombre'] as String?) ?? '');

      final results = await Future.wait([
        ApiService.getAppointments().catchError((_) => <Appointment>[]),
        ApiService.getMedicalRecord().catchError((_) => <String, dynamic>{}),
        ApiService.getHraHistory().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;

      final citas = (results[0] as List<Appointment>)
          .where((c) =>
              c.estado == 'programada' && c.fechaHora.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

      final record = results[1] as Map<String, dynamic>;
      final hra = results[2] as List<Map<String, dynamic>>;

      setState(() {
        _proximaCita = citas.isNotEmpty ? citas.first : null;
        _expedientePct = record['completitud_pct'] as int? ?? 0;
        if (hra.isNotEmpty) {
          final puntaje = hra.first['puntaje_total'] as int? ?? 0;
          _saludPct = ((puntaje / 12) * 100).round();
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _saludo {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final primerNombre =
        _nombre.isNotEmpty ? _nombre.split(' ').first : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primaryLight,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Cabecera con saludo personalizado ─────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _saludo,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    primerNombre.isEmpty
                                        ? 'Bienvenido'
                                        : primerNombre,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                            ),
                            if (primerNombre.isNotEmpty)
                              GradientAvatar(
                                initials: primerNombre.length >= 2
                                    ? primerNombre.substring(0, 2)
                                    : primerNombre,
                                radius: 24,
                                colors: const [
                                  AppColors.accent,
                                  AppColors.accentDark
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        // ── Botón principal: Consultar ahora ──────────────
                        PressableCard(
                          onTap: widget.onConsultarAhora,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.accent,
                                  AppColors.accentDark
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.video_camera_front_outlined,
                                    color: Colors.white, size: 26),
                                SizedBox(width: 12),
                                Text(
                                  'Consultar ahora',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Un médico te atiende en minutos',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Contenido ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primaryLight)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Próxima cita
                          if (_proximaCita != null) ...[
                            const _SectionTitle('TU PRÓXIMA CITA'),
                            const SizedBox(height: 10),
                            _ProximaCitaCard(
                              cita: _proximaCita!,
                              onTap: widget.onVerCitas,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Accesos rápidos
                          const _SectionTitle('ACCESOS RÁPIDOS'),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.95,
                            children: [
                              _QuickAction(
                                icon: Icons.search_outlined,
                                label: 'Buscar\nmédico',
                                color: AppColors.primaryLight,
                                onTap: widget.onVerMedicos,
                              ),
                              _QuickAction(
                                icon: Icons.description_outlined,
                                label: 'Mis\nrecetas',
                                color: const Color(0xFF7C3AED),
                                onTap: widget.onVerCitas,
                              ),
                              _QuickAction(
                                icon: Icons.local_pharmacy_outlined,
                                label: 'Farmacia',
                                color: AppColors.accentDark,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const PharmacyScreen())),
                              ),
                              _QuickAction(
                                icon: Icons.folder_shared_outlined,
                                label: 'Mi\nexpediente',
                                color: const Color(0xFF0891B2),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const MedicalRecordScreen())),
                              ),
                              _QuickAction(
                                icon: Icons.monitor_heart_outlined,
                                label: 'Evaluación\nde salud',
                                color: const Color(0xFFDB2777),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const HraScreen())),
                              ),
                              _QuickAction(
                                icon: Icons.watch_outlined,
                                label: 'Actividad\nfísica',
                                color: const Color(0xFFF59E0B),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const WearablesScreen())),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Estado de salud
                          const _SectionTitle('TU ESTADO'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _EstadoCard(
                                  icon: Icons.favorite_outline,
                                  label: 'Salud general',
                                  valor: _saludPct != null
                                      ? '$_saludPct%'
                                      : '—',
                                  color: _saludPct == null
                                      ? AppColors.textHint
                                      : _saludPct! >= 75
                                          ? AppColors.semGreen
                                          : _saludPct! >= 50
                                              ? AppColors.semYellow
                                              : AppColors.semRed,
                                  hint: _saludPct == null
                                      ? 'Hacé tu evaluación'
                                      : 'Última evaluación',
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const HraScreen())),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _EstadoCard(
                                  icon: Icons.assignment_outlined,
                                  label: 'Expediente',
                                  valor: '$_expedientePct%',
                                  color: _expedientePct >= 80
                                      ? AppColors.semGreen
                                      : AppColors.primaryLight,
                                  hint: _expedientePct >= 80
                                      ? 'Completo'
                                      : 'Completalo',
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const MedicalRecordScreen())),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Plan mensual
                          PressableCard(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SubscriptionScreen())),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: AppTheme.glassCard(radius: 18),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.workspace_premium_outlined,
                                        color: AppColors.primaryLight,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Planes de suscripción',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color:
                                                    AppColors.textPrimary)),
                                        SizedBox(height: 2),
                                        Text(
                                            'Consultas desde \$9.99 al mes',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors
                                                    .textSecondary)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 14, color: AppColors.textHint),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      );
}

class _ProximaCitaCard extends StatelessWidget {
  final Appointment cita;
  final VoidCallback onTap;

  const _ProximaCitaCard({required this.cita, required this.onTap});

  static const _meses = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
  ];
  static const _dias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  Widget build(BuildContext context) {
    final f = cita.fechaHora;
    final esHoy = f.year == DateTime.now().year &&
        f.month == DateTime.now().month &&
        f.day == DateTime.now().day;

    return PressableCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCard(radius: 18).copyWith(
          border: Border.all(
              color: AppColors.primaryLight.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  AppColors.primaryLight,
                  Color(0xFF1D4ED8),
                ]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${f.day}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1)),
                  Text(
                    _meses[f.month - 1],
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esHoy ? '¡Hoy!' : _dias[f.weekday - 1],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: esHoy
                            ? AppColors.accentDark
                            : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Videoconsulta · ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2),
                  ),
                ],
              ),
            ),
            PressableCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ConsultationScreen(appointmentId: cita.id)),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Entrar',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PressableCard(
        onTap: onTap,
        child: Container(
          decoration: AppTheme.glassCard(radius: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.2),
              ),
            ],
          ),
        ),
      );
}

class _EstadoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final Color color;
  final String hint;
  final VoidCallback onTap;

  const _EstadoCard({
    required this.icon,
    required this.label,
    required this.valor,
    required this.color,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PressableCard(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(valor,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(hint,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
            ],
          ),
        ),
      );
}
