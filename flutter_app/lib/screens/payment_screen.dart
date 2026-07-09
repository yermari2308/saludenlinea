import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
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

enum _MetodoPago { sinpe, tarjeta }

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  _MetodoPago _metodo = _MetodoPago.tarjeta;
  bool _loading = false;
  bool _enviado = false;
  bool _pagoEnCurso = false; // se abrió el checkout externo
  bool _verificando = false;

  // SINPE form
  final _refCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  String? _sinpeNumero;
  Uint8List? _comprobanteBytes;
  String? _comprobanteNombre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSinpeInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del navegador (checkout ONVO), verificar si el pago se completó
    if (state == AppLifecycleState.resumed && _pagoEnCurso) {
      _verificarPago();
    }
  }

  Future<void> _verificarPago() async {
    if (_verificando) return;
    setState(() => _verificando = true);
    try {
      final info = await ApiService.getAppointmentPago(widget.appointmentId);
      if (!mounted) return;
      if (info['requiere_pago'] == false) {
        _pagoEnCurso = false;
        // Pago confirmado → volver con éxito
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.check_circle_rounded, color: AppColors.accentDark),
              SizedBox(width: 8),
              Text('¡Pago confirmado!',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18,
                      color: AppColors.textPrimary)),
            ]),
            content: const Text(
                'Tu cita quedó pagada. Ya podés entrar a la consulta.',
                style: TextStyle(color: AppColors.textSecondary)),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentDark,
                    foregroundColor: Colors.white),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _loadSinpeInfo() async {
    try {
      final info = await ApiService.getSinpeInfo();
      if (mounted) setState(() => _sinpeNumero = info['numero'] as String?);
    } catch (_) {}
  }

  Future<void> _pickComprobante() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _comprobanteBytes = result.files.single.bytes;
        _comprobanteNombre = result.files.single.name;
      });
    }
  }

  Future<void> _enviarSinpe() async {
    final ref = _refCtrl.text.trim();
    final tel = _telCtrl.text.trim();
    if (ref.isEmpty || tel.isEmpty) {
      _snack('Ingresa la referencia y el teléfono de origen');
      return;
    }
    setState(() => _loading = true);
    try {
      String? b64;
      if (_comprobanteBytes != null) {
        b64 = base64Encode(_comprobanteBytes!);
      }
      await ApiService.reportarSinpe(
        appointmentId: widget.appointmentId,
        sinpeReferencia: ref,
        sinpeTelefono: tel,
        comprobanteB64: b64,
      );
      if (!mounted) return;
      setState(() => _enviado = true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pagarTarjeta() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.onvoCheckout(widget.appointmentId);
      final url = data['checkout_url'] as String?;
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        _pagoEnCurso = true;
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        _snack('No se pudo abrir la página de pago');
      }
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pago seguro',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _enviado ? _buildExito() : _buildForm(),
    );
  }

  Widget _buildExito() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.accentDark.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 64, color: AppColors.accentDark),
              ),
              const SizedBox(height: 24),
              const Text(
                '¡Pago SINPE reportado!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Un administrador verificará tu comprobante y confirmará la cita en breve.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Volver a mis citas', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Resumen ────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.medical_services_rounded,
                    color: Colors.white, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Consulta con ${widget.doctorNombre}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${widget.monto.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Selector de método ─────────────────────────────────────────────
          const Text('Método de pago',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _MetodoTile(
            selected: _metodo == _MetodoPago.tarjeta,
            icon: Icons.bolt_rounded,
            titulo: 'Pago en línea — verificación automática',
            subtitulo: 'Tarjeta o SINPE Móvil vía ONVO Pay — se confirma al instante',
            color: const Color(0xFF6366F1),
            onTap: () => setState(() => _metodo = _MetodoPago.tarjeta),
          ),
          const SizedBox(height: 8),
          _MetodoTile(
            selected: _metodo == _MetodoPago.sinpe,
            icon: Icons.phone_android_rounded,
            titulo: 'SINPE Móvil manual',
            subtitulo: 'Sin comisión — un administrador verifica tu comprobante',
            color: const Color(0xFF16A34A),
            onTap: () => setState(() => _metodo = _MetodoPago.sinpe),
          ),
          const SizedBox(height: 24),

          // ── Formulario SINPE ───────────────────────────────────────────────
          if (_metodo == _MetodoPago.sinpe) ...[
            if (_sinpeNumero != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Envía al número SINPE:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.w600)),
                          Text(
                            _sinpeNumero!,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF14532D),
                                letterSpacing: 1.5),
                          ),
                          const Text('SaludEnLínea S.A.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF166534))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _Campo(
              ctrl: _refCtrl,
              label: 'Código de referencia',
              hint: 'Ej: 4567',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _Campo(
              ctrl: _telCtrl,
              label: 'Teléfono de origen',
              hint: 'Ej: 88887777',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickComprobante,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _comprobanteBytes != null
                        ? const Color(0xFF16A34A)
                        : AppColors.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _comprobanteBytes != null
                          ? Icons.check_circle_rounded
                          : Icons.attach_file_rounded,
                      color: _comprobanteBytes != null
                          ? const Color(0xFF16A34A)
                          : AppColors.textHint,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _comprobanteNombre ?? 'Adjuntar comprobante (opcional)',
                        style: TextStyle(
                          color: _comprobanteBytes != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _enviarSinpe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Reportar pago SINPE',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],

          // ── Tarjeta (ONVO Pay) ─────────────────────────────────────────────
          if (_metodo == _MetodoPago.tarjeta) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Serás redirigido a ONVO Pay — pasarela de pagos costarricense con '
                'cifrado SSL. Podés pagar con tarjeta (Visa/Mastercard) o SINPE Móvil, '
                'y tu cita se confirma automáticamente al completar el pago.',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF4338CA), height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Pagar en línea',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                onPressed: _loading ? null : _pagarTarjeta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_pagoEnCurso) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _verificando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Ya pagué — verificar'),
                  onPressed: _verificando ? null : _verificarPago,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                'Pago seguro con cifrado SSL',
                style: TextStyle(
                    color: AppColors.textHint.withOpacity(0.8), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MetodoTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  const _MetodoTile({
    required this.selected,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.cardBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [] : [AppTheme.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: selected ? color : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitulo,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? color : AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType keyboardType;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textHint, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.primaryLight, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
