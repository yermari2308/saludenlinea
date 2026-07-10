import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'doctors_screen.dart';
import 'appointments_screen.dart';
import 'profile_screen.dart';
import 'waiting_room_screen.dart';
import 'legal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _role = 'patient';

  List<Widget> get _screens => [
        DashboardScreen(
          onConsultarAhora: _onBotonRojo,
          onVerMedicos: () => setState(() => _currentIndex = 1),
          onVerCitas: () => setState(() => _currentIndex = 2),
        ),
        const DoctorsScreen(),
        const AppointmentsScreen(),
        const ProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _loadRole();
    // Primer inicio de sesión: mostrar consentimiento informado y políticas
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConsent());
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _role = prefs.getString('role') ?? 'patient');
  }

  Future<void> _checkConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getString('role') ?? 'patient') == 'doctor') return;
      final acepto = await ApiService.getConsentStatus();
      if (acepto || !mounted) return;
      final resultado = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const ConsentScreen()),
      );
      if (resultado != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Podés explorar la app, pero para consultar con un médico '
              'necesitás aceptar el consentimiento informado.'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {}
  }

  Future<void> _onBotonRojo() async {
    // ── Aviso legal: no es un servicio de emergencias ─────────────────────
    final continuar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: Color(0xFFE53E3E)),
            SizedBox(width: 8),
            Expanded(
              child: Text('¿Es una emergencia?',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17,
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
        content: const Text(
          'Si tu vida está en peligro (dolor de pecho intenso, dificultad severa '
          'para respirar, pérdida de conciencia, sangrado abundante), NO uses la app: '
          'llamá al 9-1-1 de inmediato.\n\n'
          'Este servicio es para atención médica urgente que NO amenaza la vida.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('No es emergencia, continuar'),
          ),
        ],
      ),
    );
    if (continuar != true || !mounted) return;

    // ── Consentimiento informado obligatorio ──────────────────────────────
    try {
      final acepto = await ApiService.getConsentStatus();
      if (!acepto) {
        if (!mounted) return;
        final resultado = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const ConsentScreen()),
        );
        if (resultado != true) return;
      }
    } catch (_) {}
    if (!mounted) return;

    try {
      final result = await ApiService.joinUrgentQueue();
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final pacienteId = prefs.getInt('user_id') ?? 0;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(
            queueId: result['queue_id'] as int,
            posicion: result['posicion'] as int,
            pacienteId: pacienteId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.canvas,
      extendBody: true, // el contenido fluye bajo el dock flotante
      body: _screens[_currentIndex],
      bottomNavigationBar: DSDock(
        index: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        onCenterTap: _role == 'patient' ? _onBotonRojo : null,
        centerIcon: Icons.emergency_rounded,
        items: const [
          (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
          (Icons.search_outlined, Icons.search_rounded, 'Médicos'),
          (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Citas'),
          (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
        ],
      ),
    );
  }
}
