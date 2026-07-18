import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/doctor_home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const SaludEnLineaApp());
}

class SaludEnLineaApp extends StatelessWidget {
  const SaludEnLineaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaludEnLínea',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashRouter(),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  /// Tiempo mínimo en pantalla para que la animación de bienvenida se vea
  /// completa aunque la sesión se resuelva al instante.
  static const _minimoEnPantalla = Duration(milliseconds: 2200);

  String _estado = 'Preparando todo…';

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final reloj = Stopwatch()..start();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role') ?? 'paciente';
    if (!mounted) return;

    if (token != null) setState(() => _estado = 'Verificando tu sesión…');

    // Espera lo que falte para completar el mínimo en pantalla
    Future<void> esperarAnimacion() async {
      final resta = _minimoEnPantalla - reloj.elapsed;
      if (resta > Duration.zero) await Future.delayed(resta);
    }

    await _resolverDestino(token, role, esperarAnimacion);
  }

  Future<void> _resolverDestino(
    String? token,
    String role,
    Future<void> Function() esperarAnimacion,
  ) async {
    if (!mounted) return;

    if (token == null) {
      await esperarAnimacion();
      if (!mounted) return;
      _ir(const LoginScreen());
      return;
    }

    // Verificar contra el SERVIDOR que el token siga siendo válido
    try {
      if (role == 'doctor') {
        await ApiService.getDisponibleUrgente(); // requiere token de doctor válido
        await esperarAnimacion();
        if (!mounted) return;
        _ir(const DoctorHomeScreen());
      } else {
        await ApiService.getMyProfile(); // requiere token de paciente válido
        await esperarAnimacion();
        if (!mounted) return;
        _ir(const HomeScreen());
      }
    } on ApiException catch (e) {
      // Token inválido/expirado (401) u otro rechazo → limpiar sesión y al login
      if (e.statusCode == 401 || e.statusCode == 403) {
        await ApiService.logout();
      }
      await esperarAnimacion();
      if (!mounted) return;
      _ir(const LoginScreen());
    } catch (_) {
      // Error de red: dejar pasar; las pantallas manejan sus propios errores
      await esperarAnimacion();
      if (!mounted) return;
      _ir(role == 'doctor' ? const DoctorHomeScreen() : const HomeScreen());
    }
  }

  /// Transición suave desde la bienvenida hacia la app.
  void _ir(Widget destino) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animacion, __) => FadeTransition(
          opacity: animacion,
          child: destino,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SplashScene(estado: _estado);
}
