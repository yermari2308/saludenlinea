import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../app_theme.dart';
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

  void _goHome(String role) {
    final screen = role == 'doctor' ? const DoctorHomeScreen() : const HomeScreen();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error con Google: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Fondo con gradiente y formas decorativas
          Positioned.fill(
            child: Container(
              decoration: AppTheme.gradientBox,
              child: Stack(
                children: [
                  Positioned(
                    top: -60,
                    right: -60,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 80,
                    left: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withOpacity(0.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),
                // Logo y branding
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      size: 42, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text('SaludEnLínea',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    )),
                const SizedBox(height: 4),
                Text('Tu doctor en el bolsillo',
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13)),
                const SizedBox(height: 32),
                // Formulario
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text('Iniciar sesión',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.3,
                                    )),
                              ],
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryLight),
                              ),
                              validator: (v) =>
                                  v == null || !v.contains('@') ? 'Correo inválido' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryLight),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                                child: const Text('¿Olvidaste tu contraseña?',
                                    style: TextStyle(color: AppColors.primaryLight, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text('Entrar',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.cardBorder)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('o continúa con',
                                      style: TextStyle(
                                          color: AppColors.textSecondary.withOpacity(0.7),
                                          fontSize: 12)),
                                ),
                                Expanded(child: Divider(color: AppColors.cardBorder)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _loginWithGoogle,
                                icon: Image.network(
                                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                  height: 20,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata),
                                ),
                                label: const Text('Continuar con Google',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.cardBorder),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('¿No tienes cuenta?',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                TextButton(
                                  onPressed: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const RegisterScreen())),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                                  child: const Text('Regístrate',
                                      style: TextStyle(
                                          color: AppColors.primaryLight,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                            const Divider(height: 8, color: AppColors.cardBorder),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.medical_services_outlined,
                                  color: AppColors.accent, size: 18),
                              label: const Text('¿Eres médico? Únete a la plataforma',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const DoctorApplyScreen())),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.accent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
