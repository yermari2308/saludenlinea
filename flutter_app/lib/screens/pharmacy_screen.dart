import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'cart_screen.dart';
import 'pharmacy_orders_screen.dart';

/// Farmacia — Design System 2.0. Lienzo papel, floating search, chips de
/// tinta, product cards con línea base fija precio/acción.
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
  String _query = '';
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> get _visibles {
    if (_query.isEmpty) return _productos;
    final q = _query.toLowerCase();
    return _productos
        .where((p) =>
            (p['nombre'] as String? ?? '').toLowerCase().contains(q) ||
            (p['descripcion'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${p['nombre']} agregado al carrito'),
        backgroundColor: DSColors.ink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: DSColors.coral));
    }
  }

  Future<void> _abrirCarrito() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // ── Título + accesos ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, DS.s1),
              child: Row(
                children: [
                  const Expanded(child: Text('Farmacia', style: DSText.title)),
                  DSPressable(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PharmacyOrdersScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                          color: DSColors.surface, shape: BoxShape.circle, boxShadow: DSElevation.rest),
                      child: const Icon(Icons.receipt_long_rounded, size: 19, color: DSColors.textMid),
                    ),
                  ),
                  DSPressable(
                    onTap: _abrirCarrito,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: DSColors.surface, shape: BoxShape.circle, boxShadow: DSElevation.rest),
                        child: const Icon(Icons.shopping_bag_outlined, size: 19, color: DSColors.textMid),
                      ),
                      if (_cartCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: DSColors.coral, shape: BoxShape.circle),
                            child: Text('$_cartCount',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
            // ── Floating search ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DS.s2),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: DSColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: DSElevation.float,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: DSColors.textStrong, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Buscar medicamento o producto…',
                    hintStyle: const TextStyle(color: DSColors.textFaint, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: DSColors.mint, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: DSColors.textFaint, size: 18),
                            onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
            ),
            const SizedBox(height: DS.s2),
            // ── Categorías (píldoras de tinta) ───────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DS.s2),
                itemCount: _categorias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (id, label, icon) = _categorias[i];
                  final selected = _categoria == id;
                  return DSPressable(
                    onTap: () { setState(() => _categoria = id); _load(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? DSColors.ink : DSColors.surface,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: selected ? [] : DSElevation.rest,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 15, color: selected ? DSColors.mint : DSColors.textMid),
                        const SizedBox(width: 6),
                        Text(label,
                            style: TextStyle(
                                color: selected ? Colors.white : DSColors.textMid,
                                fontSize: 12.5,
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: DS.s1),
            // ── Productos ─────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? ListView(children: const [SkeletonCard(), SkeletonCard(), SkeletonCard()])
                  : _visibles.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: DSColors.mint,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(DS.s2, 0, DS.s2, 120),
                            itemCount: _visibles.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(height: DS.s1),
                            itemBuilder: (_, i) {
                              if (i == 0) return const _AvisoLegalFarmacia();
                              return _ProductCard(
                                producto: _visibles[i - 1],
                                onAdd: () => _agregar(_visibles[i - 1]),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100, height: 100,
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 100, height: 100,
                    decoration: const BoxDecoration(color: DSColors.mintSoft, shape: BoxShape.circle)),
                const Icon(Icons.local_pharmacy_rounded, size: 40, color: DSColors.mint),
              ]),
            ),
            const SizedBox(height: DS.s2),
            const Text('Sin productos en esta categoría', style: DSText.headline),
          ],
        ),
      );
}

class _AvisoLegalFarmacia extends StatelessWidget {
  const _AvisoLegalFarmacia();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(DS.s2),
        decoration: BoxDecoration(
          color: DSColors.brandSoft,
          borderRadius: DSRadius.rSm,
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_rounded, size: 18, color: DSColors.brand),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Los medicamentos son despachados por una farmacia aliada autorizada, '
                'bajo supervisión de un regente farmacéutico. Los antibióticos y '
                'psicotrópicos requieren Receta Digital del Ministerio de Salud.',
                style: TextStyle(fontSize: 11.5, color: DSColors.brand, height: 1.4),
              ),
            ),
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

    return DSCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: DSColors.mintSoft, borderRadius: DSRadius.rSm),
            child: const Icon(Icons.medication_rounded, color: DSColors.mint, size: 26),
          ),
          const SizedBox(width: DS.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(producto['nombre'] as String? ?? '', style: DSText.headline),
                const SizedBox(height: 3),
                Text(producto['descripcion'] as String? ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: DSText.label),
                const SizedBox(height: DS.s1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('\$${precio.toStringAsFixed(2)}', style: DSText.mono.copyWith(fontSize: 17)),
                    const SizedBox(width: 8),
                    if (requiereReceta)
                      const DSChip(label: 'Requiere receta', color: Color(0xFFF97316), icon: Icons.description_rounded),
                    if (stock == 0) ...[
                      const SizedBox(width: 8),
                      const DSChip(label: 'Agotado', color: DSColors.coral),
                    ],
                    const Spacer(),
                    DSPressable(
                      onTap: stock > 0 ? onAdd : null,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: stock > 0 ? DSColors.mint : DSColors.line,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
