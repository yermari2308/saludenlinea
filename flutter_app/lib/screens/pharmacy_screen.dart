import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'cart_screen.dart';
import 'pharmacy_orders_screen.dart';

/// Farmacia — vitrina comercial. Cuadrícula de dos columnas, identidad
/// cromática por categoría (el catálogo no trae fotos), señales de escasez
/// y barra de carrito persistente para cerrar la compra.
class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

/// Identidad visual de cada familia de productos: color + símbolo.
/// Sustituye a la fotografía de producto, que el catálogo no provee.
({Color color, IconData icon, String nombre}) _identidad(String? categoria) {
  switch (categoria) {
    case 'analgesicos':
      return (color: const Color(0xFFE11D48), icon: Icons.healing_rounded, nombre: 'Analgésicos');
    case 'vitaminas':
      return (color: const Color(0xFFF59E0B), icon: Icons.eco_rounded, nombre: 'Vitaminas');
    case 'cronicos':
      return (color: DSColors.brand, icon: Icons.medication_liquid_rounded, nombre: 'Crónicos');
    case 'cuidado_personal':
      return (color: DSColors.mint, icon: Icons.clean_hands_rounded, nombre: 'Cuidado personal');
    default:
      return (color: const Color(0xFF64748B), icon: Icons.local_pharmacy_rounded, nombre: 'General');
  }
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  List<Map<String, dynamic>> _productos = [];
  bool _loading = true;
  String? _categoria;
  int _cartCount = 0;
  double _cartTotal = 0;
  String _query = '';
  final _searchCtrl = TextEditingController();

  /// Ids con una petición de "agregar" en vuelo, para dar respuesta inmediata.
  final Set<int> _agregando = {};

  static const _categorias = [
    (null, 'Todo'),
    ('analgesicos', 'Analgésicos'),
    ('cronicos', 'Crónicos'),
    ('vitaminas', 'Vitaminas'),
    ('cuidado_personal', 'Cuidado'),
    ('general', 'General'),
  ];

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
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getPharmacyProducts(categoria: _categoria),
        ApiService.getCart(),
      ]);
      if (!mounted) return;
      final carrito = results[1] as Map;
      setState(() {
        _productos = results[0] as List<Map<String, dynamic>>;
        _cartCount = (carrito['items'] as List).length;
        _cartTotal = (carrito['total'] as num?)?.toDouble() ?? 0;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _agregar(Map<String, dynamic> p) async {
    final id = p['id'] as int;
    if (_agregando.contains(id)) return;
    setState(() => _agregando.add(id));
    try {
      await ApiService.addToCart(id);
      if (!mounted) return;
      final precio = (p['precio'] as num?)?.toDouble() ?? 0;
      setState(() {
        _cartCount++;
        _cartTotal += precio;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: DSColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) setState(() => _agregando.remove(id));
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
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _encabezado(),
                const SizedBox(height: DS.s2),
                _buscador(),
                const SizedBox(height: DS.s2),
                _filtros(),
                const SizedBox(height: DS.s1 + 4),
                Expanded(child: _catalogo()),
              ],
            ),
          ),
          // Barra de compra: solo aparece cuando hay algo que cobrar
          if (_cartCount > 0)
            Positioned(left: 0, right: 0, bottom: 0, child: _barraCarrito()),
        ],
      ),
    );
  }

  // ── Encabezado con promesa de entrega ──────────────────────────────────
  Widget _encabezado() => Padding(
        padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, 0),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Farmacia', style: DSText.title)),
                DSPressable(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PharmacyOrdersScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: DSColors.surface,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: DSElevation.rest,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 16, color: DSColors.textMid),
                        SizedBox(width: 6),
                        Text('Mis pedidos',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700, color: DSColors.textMid)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s2),
            // Propuesta de valor: por qué comprar acá y no en la esquina
            Container(
              padding: const EdgeInsets.all(DS.s2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [DSColors.ink, DSColors.inkSoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: DSRadius.rMd,
                boxShadow: DSElevation.float,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DSColors.mint.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: DSColors.mint, size: 24),
                  ),
                  const SizedBox(width: DS.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Te lo llevamos a tu casa',
                            style: TextStyle(
                                color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                        const SizedBox(height: 2),
                        Text('Pedí con SINPE o pagá contra entrega',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Buscador ───────────────────────────────────────────────────────────
  Widget _buscador() => Padding(
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
            style: const TextStyle(
                color: DSColors.textStrong, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Buscar medicamento o producto…',
              hintStyle: const TextStyle(
                  color: DSColors.textFaint, fontSize: 14, fontWeight: FontWeight.w400),
              prefixIcon: const Icon(Icons.search_rounded, color: DSColors.mint, size: 22),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, color: DSColors.textFaint, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
      );

  // ── Filtros por familia ────────────────────────────────────────────────
  Widget _filtros() => SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: DS.s2),
          itemCount: _categorias.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (id, label) = _categorias[i];
            final activo = _categoria == id;
            final ident = _identidad(id);
            return DSPressable(
              onTap: () {
                setState(() => _categoria = id);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activo ? DSColors.ink : DSColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: activo ? DSElevation.rest : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (id != null) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: ident.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(label,
                        style: TextStyle(
                            color: activo ? Colors.white : DSColors.textMid,
                            fontSize: 12.5,
                            fontWeight: activo ? FontWeight.w800 : FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        ),
      );

  // ── Catálogo en cuadrícula ─────────────────────────────────────────────
  Widget _catalogo() {
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(DS.s2, 0, DS.s2, 140),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: DS.s1 + 4,
          mainAxisSpacing: DS.s1 + 4,
          mainAxisExtent: 232,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: DSColors.surface,
            borderRadius: DSRadius.rMd,
            boxShadow: DSElevation.rest,
          ),
        ),
      );
    }

    if (_visibles.isEmpty) {
      return DSEmpty(
        icon: _query.isEmpty ? Icons.local_pharmacy_rounded : Icons.search_off_rounded,
        color: DSColors.mint,
        title: _query.isEmpty ? 'Sin productos en esta categoría' : 'No encontramos ese producto',
        message: _query.isEmpty
            ? 'Probá con otra familia de productos.'
            : 'Revisá cómo lo escribiste o buscá por el principio activo.',
        action: _query.isEmpty
            ? null
            : DSButton(
                label: 'Ver todo el catálogo',
                icon: Icons.grid_view_rounded,
                color: DSColors.mint,
                onTap: () {
                  _searchCtrl.clear();
                  setState(() {
                    _query = '';
                    _categoria = null;
                  });
                  _load();
                },
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: DSColors.mint,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _AvisoRegencia()),
          const SliverToBoxAdapter(child: SizedBox(height: DS.s2)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(DS.s2, 0, DS.s2, _cartCount > 0 ? 150 : 110),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: DS.s1 + 4,
                mainAxisSpacing: DS.s1 + 4,
                mainAxisExtent: 232,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _TarjetaProducto(
                  producto: _visibles[i],
                  ocupado: _agregando.contains(_visibles[i]['id'] as int),
                  onAdd: () => _agregar(_visibles[i]),
                ),
                childCount: _visibles.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra de compra persistente ────────────────────────────────────────
  Widget _barraCarrito() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (_, v, hijo) => Transform.translate(
          offset: Offset(0, 70 * (1 - v)),
          child: Opacity(opacity: v, child: hijo),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(DS.s2, DS.s1 + 4, DS.s2, DS.s1),
          decoration: BoxDecoration(
            color: DSColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
            boxShadow: DSElevation.hero,
          ),
          child: SafeArea(
            top: false,
            child: DSPressable(
              onTap: _abrirCarrito,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DS.s2, vertical: 13),
                decoration: BoxDecoration(
                  color: DSColors.mint,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: DSElevation.glow(DSColors.mint),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('$_cartCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                    const SizedBox(width: 10),
                    const Text('Ver carrito',
                        style: TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('\$${_cartTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Aviso de regencia farmacéutica — obligatorio en Costa Rica.
class _AvisoRegencia extends StatelessWidget {
  const _AvisoRegencia();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: DS.s2),
        padding: const EdgeInsets.all(DS.s2 - 2),
        decoration: BoxDecoration(
          color: DSColors.brandSoft,
          borderRadius: DSRadius.rSm,
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_rounded, size: 17, color: DSColors.brand),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Despachado por una farmacia aliada autorizada, bajo supervisión '
                'de un regente farmacéutico. Antibióticos y psicotrópicos requieren '
                'Receta Digital del Ministerio de Salud.',
                style: TextStyle(fontSize: 11, color: DSColors.brand, height: 1.45,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
}

/// Ficha de producto en la vitrina.
class _TarjetaProducto extends StatelessWidget {
  final Map<String, dynamic> producto;
  final VoidCallback onAdd;
  final bool ocupado;

  const _TarjetaProducto({
    required this.producto,
    required this.onAdd,
    required this.ocupado,
  });

  @override
  Widget build(BuildContext context) {
    final ident = _identidad(producto['categoria'] as String?);
    final requiereReceta = producto['requiere_receta'] == true;
    final stock = producto['stock'] as int? ?? 0;
    final precio = (producto['precio'] as num?)?.toDouble() ?? 0;
    final agotado = stock == 0;
    final ultimas = stock > 0 && stock <= 10;

    return Container(
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.rMd,
        boxShadow: DSElevation.rest,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Lámina de identidad cromática ──────────────────────────
          SizedBox(
            height: 88,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: ident.color.withOpacity(0.09)),
                ),
                // Símbolo grande y desplazado: textura, no ilustración
                Positioned(
                  right: -14,
                  bottom: -14,
                  child: Icon(ident.icon,
                      size: 76, color: ident.color.withOpacity(0.16)),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Icon(ident.icon, size: 26, color: ident.color),
                ),
                if (requiereReceta)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: DSColors.surface,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: DSElevation.rest,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_rounded, size: 10, color: Color(0xFFEA580C)),
                          SizedBox(width: 3),
                          Text('Receta',
                              style: TextStyle(
                                  fontSize: 9.5, fontWeight: FontWeight.w800,
                                  color: Color(0xFFEA580C))),
                        ],
                      ),
                    ),
                  ),
                if (agotado)
                  Positioned.fill(
                    child: Container(
                      color: DSColors.canvas.withOpacity(0.72),
                      alignment: Alignment.center,
                      child: const Text('AGOTADO',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              letterSpacing: 1, color: DSColors.textFaint)),
                    ),
                  ),
              ],
            ),
          ),
          // ── Datos ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto['nombre'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700,
                        color: DSColors.textStrong, height: 1.25),
                  ),
                  const SizedBox(height: 3),
                  if (ultimas)
                    Text('Quedan $stock',
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309)))
                  else
                    Text(
                      producto['descripcion'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: DSColors.textFaint),
                    ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text('\$${precio.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800,
                                color: DSColors.textStrong, letterSpacing: -0.5,
                                fontFeatures: [FontFeature.tabularFigures()])),
                      ),
                      DSPressable(
                        onTap: agotado || ocupado ? null : onAdd,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: agotado ? DSColors.line : DSColors.mint,
                            shape: BoxShape.circle,
                            boxShadow: agotado ? null : DSElevation.glow(DSColors.mint),
                          ),
                          child: ocupado
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(Icons.add_rounded,
                                  color: agotado ? DSColors.textFaint : Colors.white, size: 21),
                        ),
                      ),
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
