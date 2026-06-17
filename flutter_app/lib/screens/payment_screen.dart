// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final int appointmentId;
  final String doctorNombre;
  final double monto;

  const PaymentScreen({
    super.key,
    required this.appointmentId,
    required this.doctorNombre,
    required this.monto,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false;
  String? _paymentUrl;

  @override
  void initState() {
    super.initState();
    _iniciarPago();
  }

  Future<void> _iniciarPago() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.createPaymentPreference(widget.appointmentId);
      setState(() {
        // En sandbox usa sandbox_init_point; en producción usa init_point
        _paymentUrl = data['sandbox_init_point'] ?? data['init_point'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _abrirPago() {
    if (_paymentUrl != null) {
      html.window.open(_paymentUrl!, '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago seguro'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _loading
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Preparando pago seguro...'),
                  ],
                )
              : _paymentUrl != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment, size: 64, color: Color(0xFF009EE3)),
                        const SizedBox(height: 20),
                        Text(
                          'Consulta con ${widget.doctorNombre}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${widget.monto.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF009EE3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pago procesado por Mercado Pago\nTarjeta, SINPE, transferencia y más',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('Pagar ahora', style: TextStyle(fontSize: 16)),
                            onPressed: _abrirPago,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009EE3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Pago seguro con cifrado SSL',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text('No se pudo cargar el pago'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _iniciarPago,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
