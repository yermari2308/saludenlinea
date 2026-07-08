import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import 'cart_screen.dart';
import 'pharmacy_orders_screen.dart';

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  List<Map<String, dynamic>> _productos = [];
  bool _loading = true;
  String? _categoria;
  int _cartCount = 0;

  static const _categorias = [
    (null, 'Todo', Icons.grid_view_rounded),
    ('analgesicos', 'Analgésicos', Icons.healing_rounded),
    ('vitaminas', 'Vitaminas', Icons.energy_savings_leaf_rounded),
    ('cronicos', 'Crónicos', Icons.medication_rounded),
    ('cuidado_personal', 'Cuidado', Icons.clean_hands_rounded),
    ('general', 'General', Icons.local_pharmacy_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getPharmacyProducts(categoria: _categoria),
        ApiService.getCart(),
      ]);
      if (!mounted) return;
      setState(() {
        _productos = results[0] as List<Map<String, dynamic>>;
        _cartCount = ((results[1] as Map)['items'] as List).length;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _agregar(Map<String, dynamic> p) async {
    try {
      await ApiService.addToCart(p['id'] as int);
      if (!mounted) return;
      setState(() => _cartCount++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${p['nombre']} agregado al carrito'),
          backgroundColor: AppColors.accentDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _abrirCarrito() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CartScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Farmacia',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Mis pedidos',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PharmacyOrdersScreen())),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_rounded),
                tooltip: 'Carrito',
                onPressed: _abrirCarrito,
              ),
              if (_cartCount > 0)
                Positioned(
                  top: 8,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: AppColors.error, shape: BoxShape.circle),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Categorías ─────────────────────────────────────────────────────
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categorias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (id, label, icon) = _categorias[i];
                  final selected = _categoria == id;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _categoria = id);
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(icon,
                              size: 15,
                              color: selected ? AppColors.primary : Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              color: selected ? AppColors.primary : Colors.white,
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // ── Productos ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLight))
                : _productos.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _productos.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ProductCard(
                            producto: _productos[i],
                            onAdd: () => _agregar(_productos[i]),
                          ),
                        ),
                      ),
          ),
        ],
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
              child: const Icon(Icons.local_pharmacy_rounded,
                  size: 48, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            const Text('No hay productos en esta categoría',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      );
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final VoidCallback onAdd;

  const _ProductCard({required this.producto, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final requiereReceta = producto['requiere_receta'] == true;
    final stock = producto['stock'] as int? ?? 0;
    final precio = (producto['precio'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication_rounded,
                color: AppColors.primaryLight, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre'] as String? ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  producto['descripcion'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '\$${precio.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.primaryLight),
                    ),
                    const SizedBox(width: 8),
                    if (requiereReceta)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_rounded,
                                size: 10, color: Color(0xFF92400E)),
                            SizedBox(width: 3),
                            Text('Receta',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E))),
                          ],
                        ),
                      ),
                    if (stock == 0) ...[
                      const SizedBox(width: 8),
                      const Text('Agotado',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: stock > 0 ? onAdd : null,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: stock > 0 ? AppColors.accentDark : AppColors.cardBorder,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_shopping_cart_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
