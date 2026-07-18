import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Suscripciones — Design System 2.0. Plan activo como tarjeta de tinta con
/// anillo de consumo; planes disponibles en tarjetas con precio tabular.
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
        _suscripcion = subData['activo'] == true
            ? subData['suscripcion'] as Map<String, dynamic>?
            : null;
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
      final data = await ApiService.subscribirOnvo(planId);
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

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: DSColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  @override
  Widget build(BuildContext context) => DSScreen(
        title: 'Suscripciones',
        subtitle: 'Consultas a precio fijo cada mes',
        padding: EdgeInsets.zero,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: DS.s6),
                child: Center(child: CircularProgressIndicator(color: DSColors.brand)),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(DS.s3, DS.s4, DS.s3, DS.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_suscripcion != null) ...[
                      _PlanActivo(sub: _suscripcion!),
                      const SizedBox(height: DS.s4),
                    ],
                    const DSSectionHeader(title: 'Planes disponibles'),
                    ..._planes.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: DS.s2),
                          child: _TarjetaPlan(
                            plan: p,
                            esActual: _suscripcion?['plan'] == p['id'],
                            onSuscribir: _subscribing
                                ? null
                                : () => _suscribir(p['id'] as String),
                          ),
                        )),
                    const SizedBox(height: DS.s2),
                    const DSSectionHeader(title: 'Cómo funciona'),
                    DSCard(
                      child: Column(
                        children: const [
                          _Punto(Icons.bolt_rounded, 'El plan se activa al instante después del pago.'),
                          _Punto(Icons.event_busy_rounded, 'Las consultas no usadas no se acumulan al mes siguiente.'),
                          _Punto(Icons.cancel_outlined, 'Podés cancelar cuando querás desde tu perfil.'),
                          _Punto(Icons.currency_exchange_rounded, 'Precio en dólares; el monto en colones es referencial.', ultimo: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      );
}

/// Tarjeta de tinta del plan vigente, con anillo de consumo.
class _PlanActivo extends StatelessWidget {
  final Map<String, dynamic> sub;
  const _PlanActivo({required this.sub});

  @override
  Widget build(BuildContext context) {
    final usadas = sub['consultas_usadas'] as int? ?? 0;
    final incluidas = sub['consultas_incluidas'] as int? ?? 0;
    final restantes = sub['consultas_restantes'];
    final ilimitado = incluidas == 0;
    final fin = sub['fin'] as String? ?? '';
    final finDate = fin.isNotEmpty ? DateTime.tryParse(fin) : null;
    final pct = ilimitado ? 1.0 : (incluidas > 0 ? usadas / incluidas : 0.0);

    return DSInkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: DSColors.mint, size: 19),
              const SizedBox(width: DS.s1),
              Expanded(
                child: Text(
                  sub['nombre_plan'] as String? ?? sub['plan'] as String? ?? 'Plan activo',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16.5,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: DSColors.mint.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('ACTIVO',
                    style: TextStyle(
                        color: DSColors.mint, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: DS.s3),
          Row(
            children: [
              DSProgressRing(
                pct: pct,
                color: DSColors.mint,
                size: 76,
                center: ilimitado
                    ? const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 26)
                    : Text('${restantes ?? 0}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
              ),
              const SizedBox(width: DS.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ilimitado ? 'Consultas ilimitadas' : 'Consultas restantes',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ilimitado
                          ? 'Usá las que necesités este mes'
                          : '$usadas de $incluidas usadas',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 12.5),
                    ),
                    if (finDate != null) ...[
                      const SizedBox(height: DS.s1),
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 13, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 5),
                          Text(
                            'Vence ${finDate.day}/${finDate.month}/${finDate.year}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de plan disponible.
class _TarjetaPlan extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool esActual;
  final VoidCallback? onSuscribir;

  const _TarjetaPlan({
    required this.plan,
    required this.esActual,
    required this.onSuscribir,
  });

  Color get _color {
    switch (plan['id']) {
      case 'premium':
        return DSColors.brand;
      case 'ilimitado':
        return DSColors.ink;
      default:
        return DSColors.mint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usd = plan['monto_usd'] as double? ?? 0;
    final crc = plan['monto_crc'] as int? ?? 0;
    final consultas = plan['consultas'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.rMd,
        border: esActual ? Border.all(color: _color, width: 2) : null,
        boxShadow: esActual ? DSElevation.float : DSElevation.rest,
      ),
      padding: const EdgeInsets.all(DS.s2 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  consultas == 0 ? Icons.all_inclusive_rounded : Icons.medical_services_rounded,
                  color: _color, size: 20,
                ),
              ),
              const SizedBox(width: DS.s1 + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan['nombre'] as String? ?? '', style: DSText.headline),
                    const SizedBox(height: 2),
                    Text(plan['descripcion'] as String? ?? '',
                        style: DSText.body.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
              if (esActual) DSChip(label: 'Actual', color: _color),
            ],
          ),
          const SizedBox(height: DS.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${usd.toStringAsFixed(2)}',
                  style: DSText.mono.copyWith(color: _color, fontSize: 28)),
              const Padding(
                padding: EdgeInsets.only(bottom: 5, left: 3),
                child: Text('/mes', style: TextStyle(fontSize: 13, color: DSColors.textMid, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('≈ ₡${_formatCRC(crc)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: DSColors.textFaint, fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: DS.s2),
          if (esActual)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: DSColors.canvas,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Center(
                child: Text('Tu plan actual',
                    style: TextStyle(color: DSColors.textFaint, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            )
          else
            DSButton(label: 'Suscribirme', color: _color, onTap: onSuscribir),
        ],
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

/// Fila informativa con ícono.
class _Punto extends StatelessWidget {
  final IconData icon;
  final String texto;
  final bool ultimo;
  const _Punto(this.icon, this.texto, {this.ultimo = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: ultimo ? 0 : DS.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: DSColors.textFaint),
            const SizedBox(width: DS.s1 + 2),
            Expanded(
              child: Text(texto,
                  style: const TextStyle(
                      fontSize: 12.5, color: DSColors.textMid, height: 1.45, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}
