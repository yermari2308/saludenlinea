import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Mis pedidos de farmacia — Design System 2.0. Cada pedido como tarjeta con
/// riel de estado, detalle de artículos y total tabular.
class PharmacyOrdersScreen extends StatefulWidget {
  const PharmacyOrdersScreen({super.key});

  @override
  State<PharmacyOrdersScreen> createState() => _PharmacyOrdersScreenState();
}

class _PharmacyOrdersScreenState extends State<PharmacyOrdersScreen> {
  List<Map<String, dynamic>> _pedidos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getPharmacyOrders();
      if (mounted) setState(() => _pedidos = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DSScreen(
        title: 'Mis pedidos',
        subtitle: _pedidos.isEmpty ? null : '${_pedidos.length} en total',
        padding: const EdgeInsets.fromLTRB(DS.s3, DS.s3, DS.s3, DS.s3),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: DS.s6),
                child: Center(child: CircularProgressIndicator(color: DSColors.brand)),
              )
            : _pedidos.isEmpty
                ? const DSEmpty(
                    icon: Icons.receipt_long_rounded,
                    title: 'Todavía no tenés pedidos',
                    message: 'Cuando hagas tu primer pedido en la farmacia, '
                        'vas a poder seguirlo desde acá.',
                  )
                : Column(
                    children: _pedidos
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: DS.s2),
                              child: _TarjetaPedido(pedido: p),
                            ))
                        .toList(),
                  ),
      );
}

class _TarjetaPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _TarjetaPedido({required this.pedido});

  (Color, IconData, String) get _estado {
    switch (pedido['estado'] as String? ?? '') {
      case 'confirmado':
        return (DSColors.brand, Icons.thumb_up_rounded, 'Confirmado');
      case 'enviado':
        return (const Color(0xFF7C3AED), Icons.local_shipping_rounded, 'En camino');
      case 'entregado':
        return (DSColors.mint, Icons.check_circle_rounded, 'Entregado');
      case 'cancelado':
        return (DSColors.coral, Icons.cancel_rounded, 'Cancelado');
      default:
        return (const Color(0xFFF59E0B), Icons.schedule_rounded, 'Pendiente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _estado;
    final items = (pedido['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final fecha = DateTime.tryParse(pedido['creado_en'] as String? ?? '');
    final total = (pedido['total'] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.rMd,
        boxShadow: DSElevation.rest,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Riel de estado
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(DSRadius.md)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(DS.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Pedido #${pedido['id']}', style: DSText.headline),
                      const Spacer(),
                      DSChip(label: label, color: color, icon: icon),
                    ],
                  ),
                  if (fecha != null) ...[
                    const SizedBox(height: 3),
                    Text('${fecha.day}/${fecha.month}/${fecha.year}',
                        style: const TextStyle(
                            fontSize: 11.5, color: DSColors.textFaint, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: DS.s2),
                  ...items.map((it) {
                    final cant = (it['cantidad'] as num?) ?? 0;
                    final precio = (it['precio_unitario'] as num?) ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: DSColors.canvas,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${cant}x',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w800, color: DSColors.textMid)),
                          ),
                          const SizedBox(width: DS.s1),
                          Expanded(
                            child: Text(it['nombre'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: DSColors.textMid, fontWeight: FontWeight.w500)),
                          ),
                          Text('\$${(precio * cant).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700, color: DSColors.textMid,
                                  fontFeatures: [FontFeature.tabularFigures()])),
                        ],
                      ),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DS.s1),
                    child: Divider(height: 1, color: DSColors.line),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: DSColors.textFaint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pedido['direccion_entrega'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: DSColors.textFaint),
                        ),
                      ),
                      const SizedBox(width: DS.s1),
                      Text('\$${total.toStringAsFixed(2)}',
                          style: DSText.mono.copyWith(fontSize: 19, color: DSColors.brand)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
