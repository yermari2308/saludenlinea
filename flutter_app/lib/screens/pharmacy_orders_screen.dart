import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis pedidos',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight))
          : _pedidos.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pedidos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _OrderCard(pedido: _pedidos[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 48, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            const Text('Aún no tienes pedidos',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      );
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _OrderCard({required this.pedido});

  (Color, IconData, String) get _estadoInfo {
    switch (pedido['estado'] as String? ?? '') {
      case 'confirmado':
        return (const Color(0xFF2563EB), Icons.thumb_up_rounded, 'Confirmado');
      case 'enviado':
        return (const Color(0xFF7C3AED), Icons.local_shipping_rounded, 'Enviado');
      case 'entregado':
        return (AppColors.accentDark, Icons.check_circle_rounded, 'Entregado');
      case 'cancelado':
        return (AppColors.error, Icons.cancel_rounded, 'Cancelado');
      default:
        return (const Color(0xFFF59E0B), Icons.schedule_rounded, 'Pendiente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _estadoInfo;
    final items = (pedido['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final fecha = DateTime.tryParse(pedido['creado_en'] as String? ?? '');
    final total = (pedido['total'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Pedido #${pedido['id']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 11, color: color),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ],
                ),
              ),
            ],
          ),
          if (fecha != null) ...[
            const SizedBox(height: 2),
            Text(
              '${fecha.day}/${fecha.month}/${fecha.year}',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
          const SizedBox(height: 10),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('${it['cantidad']}x ',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                    Expanded(
                      child: Text(
                        it['nombre'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      '\$${((it['precio_unitario'] as num) * (it['cantidad'] as num)).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )),
          const Divider(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 13, color: AppColors.textHint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  pedido['direccion_entrega'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primaryLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
