import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/doctor_card.dart';
import 'doctor_detail_screen.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  List<Doctor> _doctors = [];
  bool _loading = true;
  String? _filtro;
  final _searchCtrl = TextEditingController();

  final List<String> _especialidades = [
    'Todas',
    'Medicina General',
    'Pediatría',
    'Cardiología',
    'Dermatología',
    'Psicología',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? esp]) async {
    setState(() => _loading = true);
    try {
      final doctors = await ApiService.getDoctors(especialidad: esp == 'Todas' ? null : esp);
      setState(() => _doctors = doctors);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: AppTheme.gradientBox,
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('SaludEnLínea',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    )),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded,
                                      color: Colors.white70, size: 22),
                                  onPressed: () => _load(_filtro),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Encuentra tu especialista',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.65), fontSize: 13)),
                            const SizedBox(height: 14),
                            // Search bar
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Buscar por especialidad…',
                                  hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.5), fontSize: 14),
                                  prefixIcon: const Icon(Icons.search_rounded,
                                      color: Colors.white60, size: 20),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded,
                                              color: Colors.white60, size: 18),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            _load();
                                          },
                                        )
                                      : null,
                                ),
                                onSubmitted: (v) => _load(v.isEmpty ? null : v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: AppColors.primary,
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _especialidades.length,
                  itemBuilder: (_, i) {
                    final esp = _especialidades[i];
                    final selected =
                        _filtro == esp || (esp == 'Todas' && _filtro == null);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _filtro = esp == 'Todas' ? null : esp);
                          _load(esp == 'Todas' ? null : esp);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accent
                                : Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.accent
                                  : Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            esp,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryLight),
              ),
            )
          else if (_doctors.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_search_rounded,
                          size: 52, color: AppColors.primaryLight),
                    ),
                    const SizedBox(height: 16),
                    const Text('No se encontraron médicos',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    const Text('Intenta con otra especialidad',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => DoctorCard(
                    doctor: _doctors[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DoctorDetailScreen(doctor: _doctors[i])),
                    ),
                  ),
                  childCount: _doctors.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
