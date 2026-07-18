import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'reset_password_screen.dart';

/// Recuperar contraseña — Design System 2.0. Dos estados: formulario y
/// confirmación de envío, ambos sobre la cáscara de tinta del sistema.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? DSColors.coral : DSColors.mint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _enviar() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Ingresá un correo válido');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.forgotPassword(email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DSScreen(
        title: _sent ? 'Código enviado' : 'Recuperar contraseña',
        subtitle: _sent
            ? 'Revisá tu bandeja de entrada'
            : 'Te enviamos un código para restablecerla',
        child: _sent ? _vistaEnviado() : _vistaFormulario(),
      );

  Widget _vistaFormulario() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: DSColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, size: 40, color: DSColors.brand),
            ),
          ),
          const SizedBox(height: DS.s3),
          Text(
            'Ingresá el correo con el que te registraste y te enviaremos un '
            'código de 8 caracteres para crear una contraseña nueva.',
            textAlign: TextAlign.center,
            style: DSText.body,
          ),
          const SizedBox(height: DS.s4),
          DSField(
            controller: _emailCtrl,
            label: 'Correo electrónico',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: DS.s3),
          _loading
              ? _botonCargando()
              : DSButton(
                  label: 'Enviar código',
                  icon: Icons.send_rounded,
                  onTap: _enviar,
                ),
        ],
      );

  Widget _vistaEnviado() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: DSColors.mintSoft,
                shape: BoxShape.circle,
                boxShadow: DSElevation.glow(DSColors.mint),
              ),
              child: const Icon(Icons.mark_email_read_rounded, size: 40, color: DSColors.mint),
            ),
          ),
          const SizedBox(height: DS.s3),
          const Text('¡Código enviado!',
              textAlign: TextAlign.center, style: DSText.title),
          const SizedBox(height: DS.s1),
          Text(
            'Revisá el correo ${_emailCtrl.text.trim()} y anotá el código '
            'de 8 caracteres. Puede tardar un par de minutos en llegar.',
            textAlign: TextAlign.center,
            style: DSText.body,
          ),
          const SizedBox(height: DS.s4),
          DSButton(
            label: 'Ingresar código',
            icon: Icons.vpn_key_rounded,
            color: DSColors.mint,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
          ),
          const SizedBox(height: DS.s2),
          TextButton(
            onPressed: () => setState(() => _sent = false),
            child: const Text('Reenviar a otro correo',
                style: TextStyle(color: DSColors.brand, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      );

  Widget _botonCargando() => Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: DSColors.brand,
          borderRadius: BorderRadius.circular(100),
          boxShadow: DSElevation.glow(DSColors.brand),
        ),
        child: const Center(
          child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
        ),
      );
}
