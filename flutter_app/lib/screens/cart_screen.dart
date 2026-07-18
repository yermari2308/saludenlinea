import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Carrito y checkout de farmacia — Design System 2.0. Lista de artículos con
/// controles táctiles de 44px y panel de entrega fijo con total tabular.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _items = [];
  double _total = 0;
  bool _loading = true;
  bool _procesando = false;

  final _direccionCtrl = TextEditingController();
  String _metodoPago = 'sinpe';
  Position? _ubicacion;
  bool _obteniendoGps = false;

  @override
  void initState() {
    super.initState();
    _direccionCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getCart();
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List).cast<Map<String, dynamic>>();
        _total = (data['total'] as num?)?.toDouble() ?? 0;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cambiarCantidad(Map<String, dynamic> item, int delta) async {
    final nueva = (item['cantidad'] as int) + delta;
    try {
      if (nueva <= 0) {
        await ApiService.removeCartItem(item['item_id'] as int);
      } else {
        await ApiService.updateCartItem(item['item_id'] as int, nueva);
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    }
  }

  Future<void> _usarMiUbicacion() async {
    setState(() => _obteniendoGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Activá la ubicación (GPS) de tu teléfono e intentá de nuevo');
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        _snack('Sin permiso de ubicación. Podés escribir la dirección '
            'manualmente o activarlo en Ajustes.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() => _ubicacion = pos);
      _snack('Ubicación adjuntada al pedido', exito: true);
    } catch (e) {
      if (mounted) _snack('No se pudo obtener la ubicación: $e');
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  Future<void> _checkout() async {
    var direccion = _direccionCtrl.text.trim();
    if (direccion.length < 10) {
      _snack('Ingresá una dirección de entrega completa');
      return;
    }
    // Adjuntar coordenadas GPS para que el repartidor llegue exacto
    if (_ubicacion != null) {
      direccion +=
          '\n📍 GPS: https://maps.google.com/?q=${_ubicacion!.latitude},${_ubicacion!.longitude}';
    }
    setState(() => _procesando = true);
    try {
      final result = await ApiService.pharmacyCheckout(
        direccionEntrega: direccion,
        metodoPago: _metodoPago,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: DSColors.surface,
          shape: RoundedRectangleBorder(borderRadius: DSRadius.rMd),
          title: const Row(children: [
            Icon(Icons.check_circle_rounded, color: DSColors.mint),
            SizedBox(width: 9),
            Expanded(child: Text('¡Pedido creado!', style: DSText.headline)),
          ]),
          content: Text(
            'Pedido #${result['order_id']} por '
            '\$${(result['total'] as num).toStringAsFixed(2)}.\n\n'
            '${result['mensaje']}',
            style: DSText.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido',
                  style: TextStyle(color: DSColors.mint, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _snack(String msg, {bool exito = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: exito ? DSColors.mint : DSColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  @override
  Widget build(BuildContext context) {
    final unidades = _items.fold<int>(0, (a, i) => a + (i['cantidad'] as int? ?? 0));

    return Scaffold(
      backgroundColor: DSColors.ink,
      body: Column(
        children: [
          DSInkHeader(
            title: 'Mi carrito',
            subtitle: _items.isEmpty
                ? null
                : '$unidades ${unidades == 1 ? "artículo" : "artículos"}',
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: DSColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: DSColors.brand))
                  : _items.isEmpty
                      ? DSEmpty(
                          icon: Icons.shopping_cart_outlined,
                          title: 'Tu carrito está vacío',
                          message: 'Agregá productos desde la farmacia y te los '
                              'llevamos hasta tu casa.',
                          action: DSButton(
                            label: 'Ver productos',
                            icon: Icons.local_pharmacy_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(DS.s3, DS.s3, DS.s3, DS.s2),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: DS.s1 + 2),
                                itemBuilder: (_, i) => _FilaArticulo(
                                  item: _items[i],
                                  onMas: () => _cambiarCantidad(_items[i], 1),
                                  onMenos: () => _cambiarCantidad(_items[i], -1),
                                ),
                              ),
                            ),
                            _panelEntrega(),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel de entrega y pago ────────────────────────────────────────────
  Widget _panelEntrega() {
    final direccionOk = _direccionCtrl.text.trim().length >= 10;

    return Container(
      padding: const EdgeInsets.fromLTRB(DS.s3, DS.s3, DS.s3, DS.s2),
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
        boxShadow: DSElevation.hero,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DSSectionHeader(title: 'Entrega'),
            DSField(
              controller: _direccionCtrl,
              label: 'Dirección de entrega',
              icon: Icons.home_outlined,
              maxLines: 2,
              helper: 'Provincia, cantón, distrito y señas exactas',
            ),
            const SizedBox(height: DS.s1 + 4),
            // GPS opcional para que el repartidor llegue al punto exacto
            DSPressable(
              onTap: _obteniendoGps ? null : _usarMiUbicacion,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DS.s2, vertical: 11),
                decoration: BoxDecoration(
                  color: _ubicacion != null ? DSColors.mintSoft : DSColors.canvas,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_obteniendoGps)
                      const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: DSColors.brand))
                    else
                      Icon(
                        _ubicacion != null
                            ? Icons.check_circle_rounded
                            : Icons.my_location_rounded,
                        size: 17,
                        color: _ubicacion != null ? DSColors.mint : DSColors.brand,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _ubicacion != null
                          ? 'Ubicación GPS adjuntada'
                          : 'Usar mi ubicación actual',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ubicacion != null ? DSColors.mint : DSColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DS.s3),
            const DSSectionHeader(title: 'Cómo vas a pagar'),
            Row(
              children: [
                Expanded(
                  child: _ChipMetodo(
                    label: 'SINPE Móvil',
                    icon: Icons.phone_android_rounded,
                    seleccionado: _metodoPago == 'sinpe',
                    onTap: () => setState(() => _metodoPago = 'sinpe'),
                  ),
                ),
                const SizedBox(width: DS.s1 + 2),
                Expanded(
                  child: _ChipMetodo(
                    label: 'Contra entrega',
                    icon: Icons.payments_rounded,
                    seleccionado: _metodoPago == 'contra_entrega',
                    onTap: () => setState(() => _metodoPago = 'contra_entrega'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s3),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL', style: DSText.caption),
                    const SizedBox(height: 2),
                    Text('\$${_total.toStringAsFixed(2)}',
                        style: DSText.mono.copyWith(fontSize: 28)),
                  ],
                ),
                const SizedBox(width: DS.s3),
                Expanded(
                  child: _procesando
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          decoration: BoxDecoration(
                            color: DSColors.mint,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Center(
                            child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                          ),
                        )
                      : direccionOk
                          ? DSButton(
                              label: 'Hacer pedido',
                              icon: Icons.check_rounded,
                              color: DSColors.mint,
                              onTap: _checkout,
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(vertical: 17),
                              decoration: BoxDecoration(
                                color: DSColors.line,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Center(
                                child: Text('Ingresá la dirección',
                                    style: TextStyle(
                                        color: DSColors.textFaint,
                                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                              ),
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Artículo del carrito con control de cantidad táctil.
class _FilaArticulo extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onMas;
  final VoidCallback onMenos;

  const _FilaArticulo({required this.item, required this.onMas, required this.onMenos});

  @override
  Widget build(BuildContext context) {
    final producto = item['producto'] as Map<String, dynamic>;
    final cantidad = item['cantidad'] as int;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;
    final requiereReceta = producto['requiere_receta'] == true;

    return DSCard(
      padding: const EdgeInsets.all(DS.s1 + 4),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: DSColors.brandSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.medication_rounded, color: DSColors.brand, size: 23),
          ),
          const SizedBox(width: DS.s1 + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(producto['nombre'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: DSColors.textStrong)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('\$${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800, color: DSColors.brand,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    if (requiereReceta) ...[
                      const SizedBox(width: DS.s1),
                      const DSChip(label: 'Receta', color: Color(0xFFF97316)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: DS.s1),
          _BotonCantidad(icon: Icons.remove_rounded, onTap: onMenos),
          SizedBox(
            width: 34,
            child: Text('$cantidad',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: DSColors.textStrong,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          _BotonCantidad(icon: Icons.add_rounded, onTap: onMas),
        ],
      ),
    );
  }
}

/// Botón circular de cantidad (44px de área táctil).
class _BotonCantidad extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _BotonCantidad({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => DSPressable(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(
            color: DSColors.canvas,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: DSColors.textStrong),
        ),
      );
}

/// Selector de método de pago del pedido.
class _ChipMetodo extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipMetodo({
    required this.label,
    required this.icon,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => DSPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: seleccionado ? DSColors.ink : DSColors.canvas,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: seleccionado ? Colors.white : DSColors.textMid),
              const SizedBox(width: 7),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: seleccionado ? Colors.white : DSColors.textMid)),
              ),
            ],
          ),
        ),
      );
}
