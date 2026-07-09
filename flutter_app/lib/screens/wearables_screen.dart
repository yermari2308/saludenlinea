import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

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
        _snack('No se encontraron datos de actividad en los últimos 7 días. '
            'Verificá que tu reloj o app de salud esté conectada a Health Connect.');
        return;
      }

      await ApiService.syncHealthMetrics(dias);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${dias.length} días sincronizados correctamente'),
          backgroundColor: AppColors.accentDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Error al sincronizar: $e');
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Actividad física',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_conectado) _buildOnboarding(),
                    if (_conectado) ...[
                      _buildResumenHoy(),
                      const SizedBox(height: 20),
                      const Text('ÚLTIMOS DÍAS',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 10),
                      ..._metricas.map((m) => _DiaCard(metrica: m)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _sincronizando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          _conectado
                              ? 'Sincronizar de nuevo'
                              : 'Conectar con Health Connect',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        onPressed: _sincronizando ? null : _sincronizar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOnboarding() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.watch_rounded, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Conecta tu reloj o pulsera',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Nos integramos con Health Connect de Android para leer tus pasos, '
                'calorías y distancia. Tus médicos podrán ver tu nivel de actividad '
                'y darte mejores recomendaciones.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13.5,
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PasoTile(
            numero: '1',
            texto: 'Instalá o abrí Health Connect en tu teléfono (viene incluido en Android 14+)'),
        _PasoTile(
            numero: '2',
            texto: 'Conectá tu reloj (Samsung Health, Fitbit, Garmin, Mi Fitness…) a Health Connect'),
        _PasoTile(
            numero: '3',
            texto: 'Tocá el botón de abajo y aceptá los permisos de lectura'),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResumenHoy() {
    final hoy = _metricas.isNotEmpty ? _metricas.first : null;
    if (hoy == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.directions_walk_rounded,
            color: AppColors.primaryLight,
            valor: '${hoy['pasos']}',
            label: 'Pasos',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFF59E0B),
            valor: '${(hoy['calorias'] as num).round()}',
            label: 'Calorías',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.route_rounded,
            color: AppColors.accentDark,
            valor: '${((hoy['distancia'] as num) / 1000).toStringAsFixed(1)} km',
            label: 'Distancia',
          ),
        ),
      ],
    );
  }
}

class _PasoTile extends StatelessWidget {
  final String numero;
  final String texto;
  const _PasoTile({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(numero,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.primaryLight)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(texto,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4)),
              ),
            ),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String valor;
  final String label;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.valor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(valor,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _DiaCard extends StatelessWidget {
  final Map<String, dynamic> metrica;
  const _DiaCard({required this.metrica});

  @override
  Widget build(BuildContext context) {
    final fecha = metrica['fecha'] as String? ?? '';
    final pasos = metrica['pasos'] as int? ?? 0;
    final cal = (metrica['calorias'] as num?)?.round() ?? 0;
    final dist = ((metrica['distancia'] as num?) ?? 0) / 1000;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(fecha,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Mini(icon: Icons.directions_walk_rounded, valor: '$pasos'),
                _Mini(icon: Icons.local_fire_department_rounded, valor: '$cal'),
                _Mini(
                    icon: Icons.route_rounded,
                    valor: '${dist.toStringAsFixed(1)}km'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String valor;
  const _Mini({required this.icon, required this.valor});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(valor,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      );
}
