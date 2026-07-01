import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import 'doctors_screen.dart';
import 'appointments_screen.dart';
import 'profile_screen.dart';
import 'waiting_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _role = 'patient';

  final List<Widget> _screens = const [
    DoctorsScreen(),
    AppointmentsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _role = prefs.getString('role') ?? 'patient');
  }

  Future<void> _onBotonRojo() async {
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
      body: _screens[_currentIndex],
      floatingActionButton: _role == 'patient'
          ? _BotonRojo(onTap: _onBotonRojo)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: _currentIndex,
        showFab: _role == 'patient',
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Botón Rojo ────────────────────────────────────────────────────────────────

class _BotonRojo extends StatelessWidget {
  final VoidCallback onTap;
  const _BotonRojo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53E3E).withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.medical_services_rounded, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text(
              'URGENTE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final bool showFab;
  final ValueChanged<int> onTap;

  const _BottomBar({
    required this.currentIndex,
    required this.showFab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.search_rounded, 'Médicos'),
      (Icons.calendar_month_rounded, 'Mis citas'),
      (Icons.person_rounded, 'Perfil'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, showFab ? 0 : 8),
          child: showFab
              ? _buildWithFabSlot(items)
              : _buildNormal(items),
        ),
      ),
    );
  }

  Widget _buildNormal(List<(IconData, String)> items) {
    return Row(
      children: List.generate(items.length, (i) => _NavItem(
        icon: items[i].$1,
        label: items[i].$2,
        selected: currentIndex == i,
        onTap: () => onTap(i),
      )),
    );
  }

  Widget _buildWithFabSlot(List<(IconData, String)> items) {
    // Índices 0,1 a la izquierda | slot FAB | índice 2 a la derecha
    return Row(
      children: [
        _NavItem(
          icon: items[0].$1,
          label: items[0].$2,
          selected: currentIndex == 0,
          onTap: () => onTap(0),
        ),
        _NavItem(
          icon: items[1].$1,
          label: items[1].$2,
          selected: currentIndex == 1,
          onTap: () => onTap(1),
        ),
        const SizedBox(width: 80), // espacio para el FAB centrado
        _NavItem(
          icon: items[2].$1,
          label: items[2].$2,
          selected: currentIndex == 2,
          onTap: () => onTap(2),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryLight.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? AppColors.primaryLight : AppColors.textHint,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color:
                      selected ? AppColors.primaryLight : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
