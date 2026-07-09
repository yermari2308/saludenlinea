import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

/// Pestaña "Ingresos" del panel médico.
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis ingresos',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
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
                    _buildResumen(),
                    const SizedBox(height: 20),
                    _buildPorMes(),
                    const SizedBox(height: 20),
                    _buildDetalle(),
                    const SizedBox(height: 24),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Este mes',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 13)),
          const SizedBox(height: 4),
          Text('\$${mes.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                  label: 'Histórico',
                  valor: '\$${historico.toStringAsFixed(2)}'),
              const SizedBox(width: 20),
              _MiniStat(label: 'Consultas', valor: '$consultas'),
              const SizedBox(width: 20),
              _MiniStat(
                  label: 'Comisión', valor: '${comision.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPorMes() {
    final porMes =
        (_data?['por_mes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (porMes.isEmpty) return const SizedBox.shrink();

    final maxTotal = porMes
        .map((m) => (m['total'] as num).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('POR MES',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [AppTheme.cardShadow],
          ),
          child: Column(
            children: porMes
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 62,
                            child: Text(m['mes'] as String? ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary)),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxTotal > 0
                                    ? (m['total'] as num) / maxTotal
                                    : 0,
                                minHeight: 8,
                                backgroundColor: AppColors.cardBorder,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.accentDark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: Text(
                              '\$${(m['total'] as num).toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetalle() {
    final detalle =
        (_data?['detalle'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (detalle.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accentDark.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payments_rounded,
                    size: 40, color: AppColors.accentDark),
              ),
              const SizedBox(height: 12),
              const Text('Aún no hay pagos registrados',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Cuando tus pacientes paguen sus consultas verás el detalle aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ÚLTIMOS PAGOS',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6)),
        const SizedBox(height: 10),
        ...detalle.map((p) {
          final fecha = DateTime.tryParse(p['fecha'] as String? ?? '');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [AppTheme.cardShadow],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentDark.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.attach_money_rounded,
                      color: AppColors.accentDark, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cita #${p['cita_id']} · ${p['metodo']}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      if (fecha != null)
                        Text('${fecha.day}/${fecha.month}/${fecha.year}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Text(
                  '+\$${(p['monto_neto'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.accentDark),
                ),
              ],
            ),
          );
        }),
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
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 11)),
        ],
      );
}
