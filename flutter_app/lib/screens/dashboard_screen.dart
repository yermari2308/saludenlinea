import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'consultation_screen.dart';
import 'medical_record_screen.dart';
import 'hra_screen.dart';
import 'pharmacy_screen.dart';
import 'subscription_screen.dart';
import 'wearables_screen.dart';

/// HOME 2.0 — Bento grid sobre lienzo papel con hero de tinta.
/// Jerarquía: Hero (saludo + consulta ya) → próxima cita → anillos de
/// estado → acciones → actividad reciente → recomendación.
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
  Appointment? _ultimaConsulta;
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

      final todas = results[0] as List<Appointment>;
      final proximas = todas
          .where((c) =>
              c.estado == 'programada' && c.fechaHora.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
      final completadas = todas
          .where((c) => c.estado == 'completada')
          .toList()
        ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

      final record = results[1] as Map<String, dynamic>;
      final hra = results[2] as List<Map<String, dynamic>>;

      setState(() {
        _proximaCita = proximas.isNotEmpty ? proximas.first : null;
        _ultimaConsulta = completadas.isNotEmpty ? completadas.first : null;
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
    final primerNombre = _nombre.isNotEmpty ? _nombre.split(' ').first : '';

    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: RefreshIndicator(
        color: DSColors.brand,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(DS.s2, 0, DS.s2, 120),
          children: [
            SafeArea(bottom: false, child: SizedBox(height: DS.s1)),

            // ── Saludo sobre el lienzo (sin cabecera de color) ─────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DS.s05),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_saludo,', style: DSText.body),
                        Text(
                          primerNombre.isEmpty ? 'Bienvenido' : primerNombre,
                          style: DSText.display,
                        ),
                      ],
                    ),
                  ),
                  if (primerNombre.isNotEmpty)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [DSColors.brand, Color(0xFF7C74F2)]),
                        shape: BoxShape.circle,
                        boxShadow: DSElevation.glow(DSColors.brand),
                      ),
                      child: Center(
                        child: Text(
                          primerNombre.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DS.s3),

            // ── HERO: tarjeta de tinta con la acción principal ─────────────
            DSInkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const DSChip(
                          label: 'MÉDICOS EN LÍNEA',
                          color: DSColors.mint,
                          icon: Icons.circle),
                      const Spacer(),
                      Icon(Icons.bolt_rounded,
                          color: Colors.white.withOpacity(0.25), size: 20),
                    ],
                  ),
                  const SizedBox(height: DS.s2),
                  const Text(
                    '¿Cómo te sentís\nhoy?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Un médico te atiende por video en minutos.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13.5,
                        height: 1.4),
                  ),
                  const SizedBox(height: DS.s3),
                  DSButton(
                    label: 'Consultar ahora',
                    icon: Icons.video_camera_front_rounded,
                    color: Colors.white,
                    foreground: DSColors.ink,
                    onTap: widget.onConsultarAhora,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DS.s3),

            if (_loading) ...[
              const Skeleton(width: double.infinity, height: 96, radius: 20),
              const SizedBox(height: DS.s2),
              const Row(children: [
                Expanded(child: Skeleton(height: 140, radius: 20)),
                SizedBox(width: DS.s2),
                Expanded(child: Skeleton(height: 140, radius: 20)),
              ]),
            ] else ...[
              // ── Próxima cita (ancho completo) ────────────────────────────
              if (_proximaCita != null) ...[
                const DSSectionHeader(title: 'Próxima cita'),
                _CitaBento(cita: _proximaCita!, onVer: widget.onVerCitas),
                const SizedBox(height: DS.s3),
              ],

              // ── Bento: anillos de estado ─────────────────────────────────
              const DSSectionHeader(title: 'Tu estado de salud'),
              Row(
                children: [
                  Expanded(
                    child: _RingBento(
                      titulo: 'Salud',
                      pct: _saludPct,
                      color: _saludPct == null
                          ? DSColors.textFaint
                          : _saludPct! >= 75
                              ? DSColors.semGood
                              : _saludPct! >= 50
                                  ? DSColors.semWarn
                                  : DSColors.semBad,
                      hint: _saludPct == null
                          ? 'Evaluate en 2 min'
                          : 'Última evaluación',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const HraScreen())),
                    ),
                  ),
                  const SizedBox(width: DS.s2),
                  Expanded(
                    child: _RingBento(
                      titulo: 'Expediente',
                      pct: _expedientePct,
                      color: _expedientePct >= 80
                          ? DSColors.semGood
                          : DSColors.brand,
                      hint: _expedientePct >= 80
                          ? 'Completo'
                          : 'Completalo',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MedicalRecordScreen())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DS.s3),

              // ── Acciones (fila horizontal deslizable) ────────────────────
              const DSSectionHeader(title: 'Servicios'),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ServicioPill(
                        icon: Icons.search_rounded,
                        label: 'Médicos',
                        color: DSColors.brand,
                        onTap: widget.onVerMedicos),
                    _ServicioPill(
                        icon: Icons.local_pharmacy_rounded,
                        label: 'Farmacia',
                        color: DSColors.mint,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PharmacyScreen()))),
                    _ServicioPill(
                        icon: Icons.description_rounded,
                        label: 'Recetas',
                        color: const Color(0xFF8B5CF6),
                        onTap: widget.onVerCitas),
                    _ServicioPill(
                        icon: Icons.watch_rounded,
                        label: 'Actividad',
                        color: const Color(0xFFF59E0B),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WearablesScreen()))),
                    _ServicioPill(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Planes',
                        color: const Color(0xFF0EA5E9),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SubscriptionScreen()))),
                  ],
                ),
              ),
              const SizedBox(height: DS.s3),

              // ── Actividad reciente ───────────────────────────────────────
              if (_ultimaConsulta != null) ...[
                const DSSectionHeader(title: 'Actividad reciente'),
                DSCard(
                  onTap: widget.onVerCitas,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: DSColors.mintSoft,
                          borderRadius: DSRadius.rSm,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: DSColors.mint, size: 20),
                      ),
                      const SizedBox(width: DS.s2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Consulta completada',
                                style: DSText.headline),
                            const SizedBox(height: 2),
                            Text(
                              _fechaCorta(_ultimaConsulta!.fechaHora) +
                                  (_ultimaConsulta!.receta.isNotEmpty
                                      ? ' · con receta'
                                      : ''),
                              style: DSText.label,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: DSColors.textFaint),
                    ],
                  ),
                ),
                const SizedBox(height: DS.s3),
              ],

              // ── Recomendación contextual ─────────────────────────────────
              const DSSectionHeader(title: 'Para vos'),
              _Recomendacion(
                saludPct: _saludPct,
                expedientePct: _expedientePct,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fechaCorta(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
}

// ── Bento de próxima cita ─────────────────────────────────────────────────────

class _CitaBento extends StatelessWidget {
  final Appointment cita;
  final VoidCallback onVer;

  const _CitaBento({required this.cita, required this.onVer});

  static const _meses = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
  ];

  @override
  Widget build(BuildContext context) {
    final f = cita.fechaHora;
    final hoy = DateTime.now();
    final esHoy =
        f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;

    return DSCard(
      onTap: onVer,
      shadows: DSElevation.float,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 60,
            decoration: BoxDecoration(
              color: DSColors.brandSoft,
              borderRadius: DSRadius.rSm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${f.day}',
                    style: const TextStyle(
                        color: DSColors.brand,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1)),
                Text(_meses[f.month - 1],
                    style: const TextStyle(
                        color: DSColors.brand,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(width: DS.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DSChip(
                  label: esHoy ? 'HOY' : 'PROGRAMADA',
                  color: esHoy ? DSColors.mint : DSColors.brand,
                ),
                const SizedBox(height: 6),
                Text(
                  'Videoconsulta · ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}',
                  style: DSText.headline,
                ),
              ],
            ),
          ),
          DSPressable(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ConsultationScreen(appointmentId: cita.id)),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: DSColors.ink,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text('Entrar',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bento con anillo de progreso ──────────────────────────────────────────────

class _RingBento extends StatelessWidget {
  final String titulo;
  final int? pct;
  final Color color;
  final String hint;
  final VoidCallback onTap;

  const _RingBento({
    required this.titulo,
    required this.pct,
    required this.color,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => DSCard(
        onTap: onTap,
        padding: const EdgeInsets.all(DS.s2),
        child: Column(
          children: [
            DSProgressRing(
              pct: (pct ?? 0) / 100,
              color: color,
              size: 84,
              center: Text(
                pct != null ? '$pct%' : '—',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: color),
              ),
            ),
            const SizedBox(height: DS.s1),
            Text(titulo, style: DSText.headline),
            const SizedBox(height: 2),
            Text(hint,
                style: const TextStyle(
                    fontSize: 11, color: DSColors.textFaint)),
          ],
        ),
      );
}

// ── Píldora de servicio ───────────────────────────────────────────────────────

class _ServicioPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServicioPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: DS.s2 - 4),
        child: DSPressable(
          onTap: onTap,
          child: Container(
            width: 84,
            decoration: BoxDecoration(
              color: DSColors.surface,
              borderRadius: DSRadius.rMd,
              boxShadow: DSElevation.rest,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: DSColors.textStrong)),
              ],
            ),
          ),
        ),
      );
}

// ── Recomendación contextual ──────────────────────────────────────────────────

class _Recomendacion extends StatelessWidget {
  final int? saludPct;
  final int expedientePct;

  const _Recomendacion({required this.saludPct, required this.expedientePct});

  @override
  Widget build(BuildContext context) {
    final String texto;
    final String cta;
    final Widget destino;
    final IconData icon;

    if (saludPct == null) {
      texto =
          'Aún no conocés tu estado de salud. Respondé 6 preguntas y recibí tu semáforo personalizado.';
      cta = 'Hacer mi evaluación';
      destino = const HraScreen();
      icon = Icons.monitor_heart_rounded;
    } else if (expedientePct < 80) {
      texto =
          'Tu expediente está al $expedientePct%. Completarlo ayuda al médico a darte un mejor diagnóstico.';
      cta = 'Completar expediente';
      destino = const MedicalRecordScreen();
      icon = Icons.folder_shared_rounded;
    } else {
      texto =
          'Todo al día. Sincronizá tu actividad física para que tu médico vea tu progreso.';
      cta = 'Conectar mi reloj';
      destino = const WearablesScreen();
      icon = Icons.watch_rounded;
    }

    return DSCard(
      color: DSColors.brandSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: DSColors.brand, size: 20),
              const SizedBox(width: DS.s1),
              const Text('Recomendado para vos',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: DSColors.brand)),
            ],
          ),
          const SizedBox(height: DS.s1),
          Text(texto,
              style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: DSColors.textStrong)),
          const SizedBox(height: DS.s2),
          DSPressable(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => destino)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: DSColors.brand,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(cta,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
