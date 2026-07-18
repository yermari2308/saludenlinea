import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Pago de consulta — Design System 2.0. Monto protagonista en tinta,
/// selector de método y verificación automática al volver del checkout.
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

class _PaymentScreenState extends State<PaymentScreen> with WidgetsBindingObserver {
  _MetodoPago _metodo = _MetodoPago.tarjeta;
  bool _loading = false;
  bool _enviado = false;
  bool _pagoEnCurso = false; // se abrió el checkout externo
  bool _verificando = false;

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
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: DSColors.surface,
            shape: RoundedRectangleBorder(borderRadius: DSRadius.rMd),
            title: const Row(children: [
              Icon(Icons.check_circle_rounded, color: DSColors.mint),
              SizedBox(width: 9),
              Expanded(child: Text('¡Pago confirmado!', style: DSText.headline)),
            ]),
            content: Text('Tu cita quedó pagada. Ya podés entrar a la consulta.',
                style: DSText.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar',
                    style: TextStyle(color: DSColors.mint, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        _snack('Todavía no vemos el pago confirmado. Si ya pagaste, esperá unos segundos y volvé a verificar.');
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
      _snack('Ingresá la referencia y el teléfono de origen');
      return;
    }
    setState(() => _loading = true);
    try {
      String? b64;
      if (_comprobanteBytes != null) b64 = base64Encode(_comprobanteBytes!);
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

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: DSColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  @override
  Widget build(BuildContext context) => DSScreen(
        title: _enviado ? 'Pago reportado' : 'Pago de consulta',
        subtitle: _enviado ? 'En verificación' : 'Necesario para entrar a la consulta',
        child: _enviado ? _vistaExito() : _vistaFormulario(),
      );

  // ── Éxito SINPE ────────────────────────────────────────────────────────
  Widget _vistaExito() => DSEmpty(
        icon: Icons.receipt_long_rounded,
        color: DSColors.mint,
        title: '¡Pago SINPE reportado!',
        message: 'Un administrador va a verificar tu comprobante y confirmar '
            'la cita en breve. Te avisamos apenas quede lista.',
        action: DSButton(
          label: 'Volver a mis citas',
          icon: Icons.arrow_back_rounded,
          color: DSColors.mint,
          onTap: () => Navigator.pop(context),
        ),
      );

  // ── Formulario ─────────────────────────────────────────────────────────
  Widget _vistaFormulario() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monto protagonista
          DSInkCard(
            child: Column(
              children: [
                Text('Consulta con ${widget.doctorNombre}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: DS.s1),
                Text('\$${widget.monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 44,
                        fontWeight: FontWeight.w800, letterSpacing: -1.5,
                        fontFeatures: [FontFeature.tabularFigures()])),
                Text('USD',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: DS.s4),

          const DSSectionHeader(title: 'Método de pago'),
          _TileMetodo(
            seleccionado: _metodo == _MetodoPago.tarjeta,
            icon: Icons.bolt_rounded,
            titulo: 'Pago en línea',
            subtitulo: 'Tarjeta o SINPE vía ONVO Pay — se confirma al instante',
            color: DSColors.brand,
            onTap: () => setState(() => _metodo = _MetodoPago.tarjeta),
          ),
          const SizedBox(height: DS.s1 + 2),
          _TileMetodo(
            seleccionado: _metodo == _MetodoPago.sinpe,
            icon: Icons.phone_android_rounded,
            titulo: 'SINPE Móvil manual',
            subtitulo: 'Sin comisión — un administrador verifica tu comprobante',
            color: DSColors.mint,
            onTap: () => setState(() => _metodo = _MetodoPago.sinpe),
          ),
          const SizedBox(height: DS.s4),

          if (_metodo == _MetodoPago.sinpe) ..._bloqueSinpe(),
          if (_metodo == _MetodoPago.tarjeta) ..._bloqueTarjeta(),

          const SizedBox(height: DS.s3),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: DSColors.textMid, fontWeight: FontWeight.w700)),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_rounded, size: 12, color: DSColors.textFaint),
                SizedBox(width: 5),
                Text('Pago protegido con cifrado SSL',
                    style: TextStyle(color: DSColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      );

  // ── Bloque SINPE ───────────────────────────────────────────────────────
  List<Widget> _bloqueSinpe() => [
        if (_sinpeNumero != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DS.s2 + 2),
            decoration: BoxDecoration(
              color: DSColors.mintSoft,
              borderRadius: DSRadius.rMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_outward_rounded, color: DSColors.mint, size: 17),
                    const SizedBox(width: 7),
                    Text('Enviá el SINPE a este número',
                        style: DSText.label.copyWith(color: const Color(0xFF166534))),
                  ],
                ),
                const SizedBox(height: DS.s1),
                Text(_sinpeNumero!,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800,
                        color: Color(0xFF14532D), letterSpacing: 2,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const Text('SaludEnLínea',
                    style: TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: DS.s3),
        ],
        DSField(
          controller: _refCtrl,
          label: 'Código de referencia',
          icon: Icons.tag_rounded,
          keyboardType: TextInputType.number,
          helper: 'El número que te da el comprobante del SINPE',
        ),
        const SizedBox(height: DS.s2),
        DSField(
          controller: _telCtrl,
          label: 'Teléfono desde el que enviaste',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: DS.s2),
        DSPressable(
          onTap: _pickComprobante,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DS.s2),
            decoration: BoxDecoration(
              color: DSColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _comprobanteBytes != null ? DSColors.mint : DSColors.line,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _comprobanteBytes != null
                      ? Icons.check_circle_rounded
                      : Icons.attach_file_rounded,
                  color: _comprobanteBytes != null ? DSColors.mint : DSColors.textFaint,
                  size: 21,
                ),
                const SizedBox(width: DS.s1 + 2),
                Expanded(
                  child: Text(
                    _comprobanteNombre ?? 'Adjuntar comprobante (opcional)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _comprobanteBytes != null ? DSColors.textStrong : DSColors.textFaint,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DS.s3),
        _loading
            ? _botonCargando(DSColors.mint)
            : DSButton(
                label: 'Reportar pago SINPE',
                icon: Icons.send_rounded,
                color: DSColors.mint,
                onTap: _enviarSinpe,
              ),
      ];

  // ── Bloque ONVO ────────────────────────────────────────────────────────
  List<Widget> _bloqueTarjeta() => [
        Container(
          padding: const EdgeInsets.all(DS.s2),
          decoration: BoxDecoration(
            color: DSColors.brandSoft,
            borderRadius: DSRadius.rSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_rounded, color: DSColors.brand, size: 18),
              const SizedBox(width: DS.s1 + 2),
              Expanded(
                child: Text(
                  'Te llevamos a ONVO Pay, la pasarela costarricense. Podés pagar '
                  'con tarjeta (Visa/Mastercard) o SINPE Móvil, y tu cita se '
                  'confirma automáticamente al volver.',
                  style: const TextStyle(
                      fontSize: 12.5, color: DSColors.textMid, height: 1.55, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DS.s3),
        _loading
            ? _botonCargando(DSColors.brand)
            : DSButton(
                label: 'Pagar en línea',
                icon: Icons.open_in_new_rounded,
                onTap: _pagarTarjeta,
              ),
        if (_pagoEnCurso) ...[
          const SizedBox(height: DS.s1 + 4),
          DSPressable(
            onTap: _verificando ? null : _verificarPago,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: DSColors.brand, width: 1.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_verificando)
                    const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: DSColors.brand))
                  else
                    const Icon(Icons.refresh_rounded, size: 18, color: DSColors.brand),
                  const SizedBox(width: 9),
                  Text(_verificando ? 'Verificando…' : 'Ya pagué — verificar',
                      style: const TextStyle(
                          color: DSColors.brand, fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ];

  Widget _botonCargando(Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
          boxShadow: DSElevation.glow(color),
        ),
        child: const Center(
          child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
        ),
      );
}

/// Opción de método de pago con estado seleccionado.
class _TileMetodo extends StatelessWidget {
  final bool seleccionado;
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  const _TileMetodo({
    required this.seleccionado,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => DSPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(DS.s2),
          decoration: BoxDecoration(
            color: DSColors.surface,
            borderRadius: DSRadius.rMd,
            border: Border.all(
              color: seleccionado ? color : DSColors.line,
              width: seleccionado ? 2 : 1.2,
            ),
            boxShadow: seleccionado ? DSElevation.float : DSElevation.rest,
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: DS.s1 + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5,
                            color: seleccionado ? color : DSColors.textStrong)),
                    const SizedBox(height: 2),
                    Text(subtitulo,
                        style: const TextStyle(
                            fontSize: 11.5, color: DSColors.textMid, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: DS.s1),
              Icon(
                seleccionado
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: seleccionado ? color : DSColors.textFaint,
                size: 21,
              ),
            ],
          ),
        ),
      );
}
