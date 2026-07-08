import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = true;
  Map<String, dynamic>? _suscripcion;
  List<Map<String, dynamic>> _planes = [];
  bool _subscribing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getMiSuscripcion(),
        ApiService.getPlanes(),
      ]);
      if (!mounted) return;
      final subData = results[0] as Map<String, dynamic>;
      setState(() {
        _suscripcion = subData['activo'] == true ? subData['suscripcion'] as Map<String, dynamic>? : null;
        _planes = (results[1] as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _suscribir(String planId) async {
    setState(() => _subscribing = true);
    try {
      final data = await ApiService.subscribirStripe(planId);
      final url = data['checkout_url'] as String?;
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        _snack('No se pudo abrir la página de pago');
      }
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Planes de suscripción',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_suscripcion != null) ...[
                      _ActivePlanCard(sub: _suscripcion!),
                      const SizedBox(height: 20),
                    ],
                    const Text('Elige tu plan',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text(
                      'Accede a consultas con médicos certificados a precio fijo mensual.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ..._planes.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PlanCard(
                            plan: p,
                            isActual: _suscripcion?['plan'] == p['id'],
                            onSuscribir: _subscribing
                                ? null
                                : () => _suscribir(p['id'] as String),
                          ),
                        )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 16, color: AppColors.textHint),
                              SizedBox(width: 8),
                              Text('Información',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                          SizedBox(height: 8),
                          _Bullet('El plan se activa inmediatamente tras el pago.'),
                          _Bullet('Las consultas no usadas no se acumulan al siguiente mes.'),
                          _Bullet('Puedes cancelar en cualquier momento desde el panel.'),
                          _Bullet('Precio en dólares; tipo de cambio ₡ referencial.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ActivePlanCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  const _ActivePlanCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final usadas = sub['consultas_usadas'] as int? ?? 0;
    final incluidas = sub['consultas_incluidas'] as int? ?? 0;
    final restantes = sub['consultas_restantes'];
    final fin = sub['fin'] as String? ?? '';
    final finDate = fin.isNotEmpty ? DateTime.tryParse(fin) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                sub['nombre_plan'] as String? ?? sub['plan'] as String? ?? 'Plan activo',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('ACTIVO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (incluidas == 0) ...[
            const Text('Consultas ilimitadas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ] else ...[
            Text(
              '$usadas de $incluidas consultas usadas',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9), fontSize: 13),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: incluidas > 0 ? usadas / incluidas : 0,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              restantes != null
                  ? '$restantes consultas restantes'
                  : 'Sin límite',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 12),
            ),
          ],
          if (finDate != null) ...[
            const SizedBox(height: 12),
            Text(
              'Vence: ${finDate.day}/${finDate.month}/${finDate.year}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isActual;
  final VoidCallback? onSuscribir;

  const _PlanCard({
    required this.plan,
    required this.isActual,
    required this.onSuscribir,
  });

  Color get _color {
    switch (plan['id']) {
      case 'premium':
        return AppColors.primaryLight;
      case 'ilimitado':
        return AppColors.accentDark;
      default:
        return const Color(0xFF16A34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usd = plan['monto_usd'] as double? ?? 0;
    final crc = plan['monto_crc'] as int? ?? 0;
    final consultas = plan['consultas'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActual ? _color : AppColors.cardBorder,
          width: isActual ? 2 : 1,
        ),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    consultas == 0
                        ? Icons.all_inclusive_rounded
                        : Icons.medical_services_rounded,
                    color: _color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['nombre'] as String? ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isActual ? _color : AppColors.textPrimary),
                      ),
                      Text(
                        plan['descripcion'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isActual)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Activo',
                      style: TextStyle(
                          color: _color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${usd.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _color),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('/mes',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
                const Spacer(),
                Text(
                  '≈ ₡${_formatCRC(crc)}/mes',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isActual ? null : onSuscribir,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActual ? AppColors.cardBorder : _color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.cardBorder,
                  disabledForegroundColor: AppColors.textHint,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isActual ? 'Plan actual' : 'Suscribirme',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCRC(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ',
                style: TextStyle(color: AppColors.textHint, fontSize: 13)),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4)),
            ),
          ],
        ),
      );
}
