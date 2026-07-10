import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Ingresos del médico — estética Stripe Dashboard: cifra hero en tinta,
/// gráfico de barras mensual, feed de transacciones con cifras tabulares.
class DoctorEarningsScreen extends StatefulWidget {
  const DoctorEarningsScreen({super.key});

  @override
  State<DoctorEarningsScreen> createState() => _DoctorEarningsScreenState();
}

class _DoctorEarningsScreenState extends State<DoctorEarningsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getDoctorIngresos();
      if (mounted) setState(() => _data = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: DSColors.brand))
            : RefreshIndicator(
                color: DSColors.brand,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, 100),
                  children: [
                    const Text('Ingresos', style: DSText.title),
                    const SizedBox(height: DS.s2),
                    _buildResumen(),
                    const SizedBox(height: DS.s3),
                    _buildPorMes(),
                    const SizedBox(height: DS.s3),
                    _buildDetalle(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildResumen() {
    final mes = (_data?['total_mes'] as num?)?.toDouble() ?? 0;
    final historico = (_data?['total_historico'] as num?)?.toDouble() ?? 0;
    final consultas = _data?['consultas_cobradas'] as int? ?? 0;
    final comision = ((_data?['comision_plataforma'] as num?) ?? 0.15) * 100;

    return DSInkCard(
      padding: const EdgeInsets.all(DS.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Este mes', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('\$${mes.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800,
                  letterSpacing: -1.2, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: DS.s2),
          Container(height: 1, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: DS.s2),
          Row(
            children: [
              _MiniStat(label: 'Histórico', valor: '\$${historico.toStringAsFixed(0)}'),
              const SizedBox(width: DS.s3),
              _MiniStat(label: 'Consultas', valor: '$consultas'),
              const SizedBox(width: DS.s3),
              _MiniStat(label: 'Comisión', valor: '${comision.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPorMes() {
    final porMes = (_data?['por_mes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (porMes.isEmpty) return const SizedBox.shrink();
    final maxTotal = porMes.map((m) => (m['total'] as num).toDouble()).fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DSSectionHeader(title: 'Por mes'),
        DSCard(
          child: Column(
            children: porMes.map((m) {
              final v = (m['total'] as num).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: DS.s1),
                child: Row(
                  children: [
                    SizedBox(width: 58, child: Text(m['mes'] as String? ?? '', style: DSText.label)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: maxTotal > 0 ? v / maxTotal : 0),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, val, __) => LinearProgressIndicator(
                            value: val, minHeight: 9,
                            backgroundColor: DSColors.line,
                            valueColor: const AlwaysStoppedAnimation(DSColors.brand),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 66,
                      child: Text('\$${v.toStringAsFixed(0)}', textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: DSColors.textStrong, fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetalle() {
    final detalle = (_data?['detalle'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (detalle.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DS.s3),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: DSColors.mintSoft, shape: BoxShape.circle),
                child: const Icon(Icons.payments_rounded, size: 36, color: DSColors.mint),
              ),
              const SizedBox(height: DS.s2),
              const Text('Aún no hay pagos registrados', style: DSText.headline),
              const SizedBox(height: 4),
              const Text('Cuando tus pacientes paguen sus consultas verás el detalle aquí.',
                  textAlign: TextAlign.center, style: DSText.label),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DSSectionHeader(title: 'Últimos pagos'),
        DSCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: detalle.asMap().entries.map((e) {
              final p = e.value;
              final fecha = DateTime.tryParse(p['fecha'] as String? ?? '');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: DS.s2, vertical: 13),
                decoration: BoxDecoration(
                  border: e.key < detalle.length - 1
                      ? const Border(bottom: BorderSide(color: DSColors.line))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: DSColors.mintSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_downward_rounded, color: DSColors.mint, size: 15),
                    ),
                    const SizedBox(width: DS.s2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cita #${p['cita_id']} · ${p['metodo']}', style: DSText.headline.copyWith(fontSize: 14)),
                          if (fecha != null)
                            Text('${fecha.day}/${fecha.month}/${fecha.year}', style: DSText.caption),
                        ],
                      ),
                    ),
                    Text('+\$${(p['monto_neto'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: DSColors.mint, fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String valor;
  const _MiniStat({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: [FontFeature.tabularFigures()])),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      );
}
