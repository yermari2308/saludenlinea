import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Actividad física (Health Connect) — Design System 2.0. Resumen del día en
/// anillos, historial semanal con barras proporcionales.
class WearablesScreen extends StatefulWidget {
  const WearablesScreen({super.key});

  @override
  State<WearablesScreen> createState() => _WearablesScreenState();
}

class _WearablesScreenState extends State<WearablesScreen> {
  bool _loading = true;
  bool _sincronizando = false;
  bool _conectado = false;
  List<Map<String, dynamic>> _metricas = [];

  /// Meta diaria de referencia para el anillo de pasos.
  static const _metaPasos = 10000;

  static final _tipos = [
    HealthDataType.STEPS,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getHealthMetrics();
      if (mounted) {
        setState(() {
          _metricas = data;
          _conectado = data.isNotEmpty;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    try {
      final health = Health();
      await health.configure();

      final permisos = await health.requestAuthorization(_tipos);
      if (!permisos) {
        _snack('Permisos de Health Connect denegados. '
            'Activalos en Ajustes → Health Connect.');
        return;
      }

      final ahora = DateTime.now();
      final dias = <Map<String, dynamic>>[];

      for (int i = 0; i < 7; i++) {
        final dia = DateTime(ahora.year, ahora.month, ahora.day)
            .subtract(Duration(days: i));
        final fin = dia.add(const Duration(days: 1));

        int pasos = 0;
        double calorias = 0;
        double distancia = 0;

        try {
          pasos = await health.getTotalStepsInInterval(dia, fin) ?? 0;
        } catch (_) {}

        try {
          final puntos = await health.getHealthDataFromTypes(
            types: [
              HealthDataType.TOTAL_CALORIES_BURNED,
              HealthDataType.DISTANCE_DELTA,
            ],
            startTime: dia,
            endTime: fin,
          );
          for (final p in puntos) {
            final v = p.value;
            final num cantidad = v is NumericHealthValue ? v.numericValue : 0;
            if (p.type == HealthDataType.TOTAL_CALORIES_BURNED) {
              calorias += cantidad.toDouble();
            } else if (p.type == HealthDataType.DISTANCE_DELTA) {
              distancia += cantidad.toDouble();
            }
          }
        } catch (_) {}

        if (pasos > 0 || calorias > 0 || distancia > 0) {
          dias.add({
            'fecha':
                '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}',
            'pasos': pasos,
            'calorias': double.parse(calorias.toStringAsFixed(1)),
            'distancia': double.parse(distancia.toStringAsFixed(1)),
            'fuente': 'health_connect',
          });
        }
      }

      if (dias.isEmpty) {
        _snack('No encontramos actividad en los últimos 7 días. Verificá que '
            'tu reloj o app de salud esté conectada a Health Connect.');
        return;
      }

      await ApiService.syncHealthMetrics(dias);
      if (!mounted) return;
      _snack('${dias.length} días sincronizados correctamente', exito: true);
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Error al sincronizar: $e');
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  void _snack(String msg, {bool exito = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: exito ? DSColors.mint : DSColors.coral,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) => DSScreen(
        title: 'Actividad física',
        subtitle: _conectado ? 'Sincronizado con Health Connect' : 'Conectá tu reloj o pulsera',
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: DS.s6),
                child: Center(child: CircularProgressIndicator(color: DSColors.brand)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_conectado) _onboarding() else ...[
                    _resumenHoy(),
                    const SizedBox(height: DS.s4),
                    const DSSectionHeader(title: 'Últimos días'),
                    ..._historial(),
                  ],
                  const SizedBox(height: DS.s4),
                  _sincronizando
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          decoration: BoxDecoration(
                            color: DSColors.mint,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: DSElevation.glow(DSColors.mint),
                          ),
                          child: const Center(
                            child: SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                          ),
                        )
                      : DSButton(
                          label: _conectado ? 'Sincronizar de nuevo' : 'Conectar con Health Connect',
                          icon: Icons.sync_rounded,
                          color: DSColors.mint,
                          onTap: _sincronizar,
                        ),
                ],
              ),
      );

  // ── Onboarding ─────────────────────────────────────────────────────────
  Widget _onboarding() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSInkCard(
            child: Column(
              children: [
                Container(
                  width: 66, height: 66,
                  decoration: BoxDecoration(
                    color: DSColors.mint.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.watch_rounded, color: DSColors.mint, size: 32),
                ),
                const SizedBox(height: DS.s2),
                const Text('Conectá tu reloj o pulsera',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontSize: 19,
                        fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(height: DS.s1),
                Text(
                  'Leemos tus pasos, calorías y distancia desde Health Connect. '
                  'Tu médico ve tu nivel de actividad y te da mejores recomendaciones.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: DS.s4),
          const DSSectionHeader(title: 'Cómo conectarlo'),
          DSCard(
            child: Column(
              children: const [
                _Paso('1', 'Instalá o abrí Health Connect (viene incluido en Android 14+).'),
                _Paso('2', 'Conectá tu reloj —Samsung Health, Fitbit, Garmin, Mi Fitness— a Health Connect.'),
                _Paso('3', 'Tocá el botón de abajo y aceptá los permisos de lectura.', ultimo: true),
              ],
            ),
          ),
        ],
      );

  // ── Resumen del día ────────────────────────────────────────────────────
  Widget _resumenHoy() {
    final hoy = _metricas.isNotEmpty ? _metricas.first : null;
    if (hoy == null) return const SizedBox.shrink();

    final pasos = (hoy['pasos'] as num?)?.toInt() ?? 0;
    final cal = ((hoy['calorias'] as num?) ?? 0).round();
    final dist = ((hoy['distancia'] as num?) ?? 0) / 1000;

    return DSInkCard(
      child: Row(
        children: [
          DSProgressRing(
            pct: pasos / _metaPasos,
            color: DSColors.mint,
            size: 92,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$pasos',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()])),
                Text('pasos',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: DS.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tu día',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('Meta: ${_metaPasos ~/ 1000} mil pasos',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                const SizedBox(height: DS.s2),
                _LineaMetrica(
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF59E0B),
                  valor: '$cal',
                  unidad: 'kcal quemadas',
                ),
                const SizedBox(height: DS.s1),
                _LineaMetrica(
                  icon: Icons.route_rounded,
                  color: DSColors.brand,
                  valor: dist.toStringAsFixed(1),
                  unidad: 'km recorridos',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Historial con barras proporcionales ────────────────────────────────
  List<Widget> _historial() {
    final maxPasos = _metricas
        .map((m) => (m['pasos'] as num?)?.toInt() ?? 0)
        .fold<int>(1, (a, b) => b > a ? b : a);

    return _metricas
        .map((m) => Padding(
              padding: const EdgeInsets.only(bottom: DS.s1),
              child: _DiaFila(metrica: m, maxPasos: maxPasos),
            ))
        .toList();
  }
}

/// Fila de métrica secundaria sobre tinta.
class _LineaMetrica extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String valor;
  final String unidad;

  const _LineaMetrica({
    required this.icon,
    required this.color,
    required this.valor,
    required this.unidad,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Text(valor,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 5),
          Text(unidad,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      );
}

/// Paso numerado del onboarding.
class _Paso extends StatelessWidget {
  final String numero;
  final String texto;
  final bool ultimo;
  const _Paso(this.numero, this.texto, {this.ultimo = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: ultimo ? 0 : DS.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26, height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: DSColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Text(numero,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12.5, color: DSColors.brand)),
            ),
            const SizedBox(width: DS.s1 + 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(texto,
                    style: const TextStyle(
                        fontSize: 13, color: DSColors.textMid, height: 1.5, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      );
}

/// Fila de día con barra proporcional de pasos.
class _DiaFila extends StatelessWidget {
  final Map<String, dynamic> metrica;
  final int maxPasos;
  const _DiaFila({required this.metrica, required this.maxPasos});

  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final fechaStr = metrica['fecha'] as String? ?? '';
    final fecha = DateTime.tryParse(fechaStr);
    final pasos = (metrica['pasos'] as num?)?.toInt() ?? 0;
    final cal = ((metrica['calorias'] as num?) ?? 0).round();
    final dist = ((metrica['distancia'] as num?) ?? 0) / 1000;
    final pct = maxPasos > 0 ? pasos / maxPasos : 0.0;
    final etiqueta = fecha != null
        ? '${_dias[fecha.weekday - 1]} ${fecha.day}'
        : fechaStr;

    return DSCard(
      padding: const EdgeInsets.symmetric(horizontal: DS.s2, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(etiqueta,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: DSColors.textStrong)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$pasos',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800, color: DSColors.textStrong,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(width: 3),
                    const Text('pasos',
                        style: TextStyle(fontSize: 11, color: DSColors.textFaint, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('$cal kcal · ${dist.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontSize: 11, color: DSColors.textFaint, fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
                const SizedBox(height: 6),
                // Barra proporcional
                LayoutBuilder(
                  builder: (_, c) => Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: DSColors.canvas,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct.clamp(0, 1)),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Container(
                          height: 6,
                          width: c.maxWidth * v,
                          decoration: BoxDecoration(
                            color: DSColors.mint,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
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
