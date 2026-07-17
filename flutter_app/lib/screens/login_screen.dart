import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'doctor_home_screen.dart';
import 'register_screen.dart';
import 'doctor_apply_screen.dart';
import 'forgot_password_screen.dart';

final _googleSignIn = GoogleSignIn(
  serverClientId: '137990449957-5c091uvl7sqnl7md8s5cr0qng8r0bvu7.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);

/// Login — Design System 2.0 "Pura Vida Ink". Hero de tinta con identidad de
/// marca sobre lienzo, formulario en panel flotante con campos de sistema.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _goHome(String role) {
    final screen = role == 'doctor' ? const DoctorHomeScreen() : const HomeScreen();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: DSColors.coral,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.login(_emailCtrl.text.trim(), _passCtrl.text);
      await ApiService.saveToken(res['access_token'], res['role'],
          userId: res['user_id'] ?? 0, nombre: res['nombre'] ?? '');
      if (!mounted) return;
      _goHome(res['role'] ?? 'paciente');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('No se obtuvo token de Google');
      final res = await ApiService.loginWithGoogleToken(idToken);
      await ApiService.saveToken(res['access_token'], res['role'],
          userId: res['user_id'] ?? 0, nombre: res['nombre'] ?? '');
      if (!mounted) return;
      _goHome(res['role'] ?? 'paciente');
    } catch (e) {
      if (!mounted) return;
      _snack('Error con Google: ${e.toString()}');
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
          // ── Hero de tinta con identidad ─────────────────────────────────
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(DS.s3, DS.s4, DS.s3, DS.s4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [DSColors.ink, DSColors.inkSoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [DSColors.mint, Color(0xFF059669)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: DSElevation.glow(DSColors.mint),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, size: 34, color: Colors.white),
                  ),
                  const SizedBox(height: DS.s2),
                  const Text('SaludEnLínea',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6)),
                  const SizedBox(height: 4),
                  Text('Tu doctor, en el bolsillo',
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
                      const Text('Iniciar sesión', style: DSText.title),
                      const SizedBox(height: 4),
                      Text('Ingresá para continuar tu atención', style: DSText.body),
                      const SizedBox(height: DS.s3),
                      _DSField(
                        controller: _emailCtrl,
                        label: 'Correo electrónico',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@') ? 'Correo inválido' : null,
                      ),
                      const SizedBox(height: DS.s2),
                      _DSField(
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                          child: const Text('¿Olvidaste tu contraseña?',
                              style: TextStyle(color: DSColors.brand, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: DS.s1),
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
                          : DSButton(label: 'Entrar', icon: Icons.arrow_forward_rounded, onTap: _login),
                      const SizedBox(height: DS.s3),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: DSColors.line)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: DS.s2),
                            child: Text('o continuá con', style: DSText.label.copyWith(color: DSColors.textFaint)),
                          ),
                          const Expanded(child: Divider(color: DSColors.line)),
                        ],
                      ),
                      const SizedBox(height: DS.s3),
                      _OutlineAction(
                        icon: Icons.g_mobiledata_rounded,
                        iconColor: DSColors.brand,
                        label: 'Continuar con Google',
                        onTap: _loading ? null : _loginWithGoogle,
                      ),
                      const SizedBox(height: DS.s3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('¿No tenés cuenta?', style: DSText.body),
                          TextButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            child: const Text('Registrate',
                                style: TextStyle(color: DSColors.brand, fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: DS.s1),
                      _OutlineAction(
                        icon: Icons.medical_services_outlined,
                        iconColor: DSColors.mint,
                        label: '¿Sos médico? Unite a la plataforma',
                        borderColor: DSColors.mint,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const DoctorApplyScreen())),
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

/// Campo de texto del sistema: relleno de lienzo, radio md, sin borde visible.
class _DSField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DSField({
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

/// Botón de acción secundaria: contorno sobre superficie blanca.
class _OutlineAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? borderColor;
  final VoidCallback? onTap;

  const _OutlineAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => DSPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: DSColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: borderColor ?? DSColors.line, width: 1.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: DSColors.textStrong, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}
