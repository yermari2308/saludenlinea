import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/doctor_home_screen.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
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
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role') ?? 'paciente';
    if (!mounted) return;

    if (token == null) {
      _goLogin();
      return;
    }

    // Verificar que el token sea válido antes de entrar
    try {
      final res = await ApiService.getUserInfo();
      if (!mounted) return;
      if (role == 'doctor') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DoctorHomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (_) {
      // Token inválido o expirado → limpiar y mandar al login
      await ApiService.logout();
      if (!mounted) return;
      _goLogin();
    }
  }

  void _goLogin() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1976D2),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'SaludEnLínea',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
