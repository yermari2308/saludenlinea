import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

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
      // Verificar que el GPS esté activado
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Activá la ubicación (GPS) de tu teléfono e intentá de nuevo');
        return;
      }
      // Solicitar permiso de ubicación
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Ubicación adjuntada al pedido ✓'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) _snack('No se pudo obtener la ubicación: $e');
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  Future<void> _checkout() async {
    var direccion = _direccionCtrl.text.trim();
    if (direccion.length < 10) {
      _snack('Ingresa una dirección de entrega completa');
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.accentDark),
              SizedBox(width: 8),
              Text('¡Pedido creado!',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18,
                      color: AppColors.textPrimary)),
            ],
          ),
          content: Text(
            'Pedido #${result['order_id']} por \$${(result['total'] as num).toStringAsFixed(2)}.\n\n'
            '${result['mensaje']}',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Entendido'),
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

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi carrito',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight))
          : _items.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CartTile(
                          item: _items[i],
                          onMas: () => _cambiarCantidad(_items[i], 1),
                          onMenos: () => _cambiarCantidad(_items[i], -1),
                        ),
                      ),
                    ),
                    _buildCheckoutPanel(),
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
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 48, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            const Text('Tu carrito está vacío',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ver productos'),
            ),
          ],
        ),
      );

  Widget _buildCheckoutPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _direccionCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Dirección de entrega',
              hintText: 'Provincia, cantón, distrito y señas exactas',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // GPS: el repartidor llega al punto exacto
          GestureDetector(
            onTap: _obteniendoGps ? null : _usarMiUbicacion,
            child: Row(
              children: [
                _obteniendoGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primaryLight))
                    : Icon(
                        _ubicacion != null
                            ? Icons.check_circle_rounded
                            : Icons.my_location_rounded,
                        size: 18,
                        color: _ubicacion != null
                            ? AppColors.success
                            : AppColors.primaryLight,
                      ),
                const SizedBox(width: 8),
                Text(
                  _ubicacion != null
                      ? 'Ubicación GPS adjuntada al pedido'
                      : 'Usar mi ubicación actual',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ubicacion != null
                        ? AppColors.success
                        : AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetodoChip(
                  label: 'SINPE Móvil',
                  icon: Icons.phone_android_rounded,
                  selected: _metodoPago == 'sinpe',
                  onTap: () => setState(() => _metodoPago = 'sinpe'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetodoChip(
                  label: 'Contra entrega',
                  icon: Icons.payments_rounded,
                  selected: _metodoPago == 'contra_entrega',
                  onTap: () => setState(() => _metodoPago = 'contra_entrega'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Text(
                    '\$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _procesando ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _procesando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Realizar pedido',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onMas;
  final VoidCallback onMenos;

  const _CartTile({required this.item, required this.onMas, required this.onMenos});

  @override
  Widget build(BuildContext context) {
    final producto = item['producto'] as Map<String, dynamic>;
    final cantidad = item['cantidad'] as int;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication_rounded,
                color: AppColors.primaryLight, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.primaryLight),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _QtyBtn(icon: Icons.remove_rounded, onTap: onMenos),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('$cantidad',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
              ),
              _QtyBtn(icon: Icons.add_rounded, onTap: onMas),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // Mínimo 44x44 px de objetivo táctil (WCAG)
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      );
}

class _MetodoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MetodoChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryLight.withOpacity(0.08)
                : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primaryLight : AppColors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? AppColors.primaryLight
                      : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.primaryLight
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}
