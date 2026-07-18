import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

/// Nueva contraseña — Design System 2.0. Código + contraseña con
/// verificación de coincidencia en vivo.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Refresca el indicador de coincidencia mientras escribe
    _passCtrl.addListener(_refrescar);
    _pass2Ctrl.addListener(_refrescar);
  }

  void _refrescar() => setState(() {});

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  bool get _coinciden =>
      _pass2Ctrl.text.isNotEmpty && _passCtrl.text == _pass2Ctrl.text;

  Future<void> _resetear() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text;

    if (code.length < 8) return _error('Ingresá el código completo de 8 caracteres');
    if (pass.length < 6) return _error('La contraseña debe tener al menos 6 caracteres');
    if (pass != _pass2Ctrl.text) return _error('Las contraseñas no coinciden');

    setState(() => _loading = true);
    try {
      await ApiService.resetPassword(token: code.toLowerCase(), newPassword: pass);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Contraseña actualizada. Iniciá sesión.'),
        backgroundColor: DSColors.mint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    } catch (e) {
      if (mounted) _error(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: DSColors.coral,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) => DSScreen(
        title: 'Nueva contraseña',
        subtitle: 'Usá el código que te llegó por correo',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: DSColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_open_rounded, size: 40, color: DSColors.brand),
              ),
            ),
            const SizedBox(height: DS.s4),
            DSField(
              controller: _codeCtrl,
              label: 'Código de 8 caracteres',
              icon: Icons.vpn_key_outlined,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: DS.s1),
            DSField(
              controller: _passCtrl,
              label: 'Nueva contraseña',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              helper: 'Mínimo 6 caracteres',
              suffix: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: DSColors.textFaint, size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: DS.s2),
            DSField(
              controller: _pass2Ctrl,
              label: 'Confirmar contraseña',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              suffix: _pass2Ctrl.text.isEmpty
                  ? null
                  : Icon(
                      _coinciden ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: _coinciden ? DSColors.mint : DSColors.coral,
                      size: 21,
                    ),
            ),
            if (_pass2Ctrl.text.isNotEmpty && !_coinciden) ...[
              const SizedBox(height: DS.s1),
              const Text('Las contraseñas no coinciden',
                  style: TextStyle(color: DSColors.coral, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: DS.s4),
            _loading
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: DSColors.mint,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: DSElevation.glow(DSColors.mint),
                    ),
                    child: const Center(
                      child: SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                    ),
                  )
                : DSButton(
                    label: 'Cambiar contraseña',
                    icon: Icons.check_rounded,
                    color: DSColors.mint,
                    onTap: _resetear,
                  ),
          ],
        ),
      );
}
