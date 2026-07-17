import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

/// Registro — Design System 2.0 "Pura Vida Ink". Consistente con Login:
/// hero de tinta compacto + panel de formulario sobre lienzo.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.registerPatient(
        nombre: _nombreCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        telefono: _telCtrl.text.trim(),
      );
      await ApiService.saveToken(res['access_token'], res['role'],
          userId: res['user_id'] ?? 0, nombre: res['nombre'] ?? '');
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: DSColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.ink,
      body: Column(
        children: [
          // ── Hero compacto ───────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s3, DS.s3),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [DSColors.ink, DSColors.inkSoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DSPressable(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: DS.s2),
                  const Text('Crear cuenta',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                  const SizedBox(height: 4),
                  Text('Unite y accedé a tu atención en minutos',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13.5, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          // ── Panel de formulario ─────────────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: DSColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DS.s3, DS.s4, DS.s3, DS.s3),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RegField(
                        controller: _nombreCtrl,
                        label: 'Nombre completo',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: DS.s2),
                      _RegField(
                        controller: _emailCtrl,
                        label: 'Correo electrónico',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@') ? 'Correo inválido' : null,
                      ),
                      const SizedBox(height: DS.s2),
                      _RegField(
                        controller: _telCtrl,
                        label: 'Teléfono (opcional)',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: DS.s2),
                      _RegField(
                        controller: _passCtrl,
                        label: 'Contraseña',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: DSColors.textFaint, size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: DS.s4),
                      _loading
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 17),
                              decoration: BoxDecoration(
                                color: DSColors.brand,
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: DSElevation.glow(DSColors.brand),
                              ),
                              child: const Center(
                                child: SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                              ),
                            )
                          : DSButton(label: 'Registrarme', icon: Icons.check_rounded, onTap: _register),
                      const SizedBox(height: DS.s2),
                      const Text(
                        'Al registrarte aceptás los Términos y Condiciones y la '
                        'Política de Privacidad de SaludEnLínea.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: DSColors.textFaint, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de texto del sistema (idéntico al de Login para consistencia).
class _RegField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _RegField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: 1.4),
        );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: DSColors.textStrong, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: DSColors.textMid, fontSize: 14, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: DSColors.brand, fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: DSColors.textMid, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: DSColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
        enabledBorder: border(DSColors.line),
        focusedBorder: border(DSColors.brand),
        errorBorder: border(DSColors.coral),
        focusedErrorBorder: border(DSColors.coral),
      ),
    );
  }
}
