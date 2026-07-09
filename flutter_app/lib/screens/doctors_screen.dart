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
  String _query = '';
  final _searchCtrl = TextEditingController();

  // Búsqueda por síntoma → especialidad sugerida
  static const _sintomas = {
    'fiebre': 'Medicina General',
    'gripe': 'Medicina General',
    'tos': 'Medicina General',
    'dolor de cabeza': 'Medicina General',
    'migraña': 'Medicina General',
    'piel': 'Dermatología',
    'acné': 'Dermatología',
    'manchas': 'Dermatología',
    'ansiedad': 'Psicología',
    'estrés': 'Psicología',
    'depresión': 'Psicología',
    'insomnio': 'Psiquiatría',
    'corazón': 'Cardiología',
    'presión': 'Cardiología',
    'palpitaciones': 'Cardiología',
    'niño': 'Pediatría',
    'bebé': 'Pediatría',
    'embarazo': 'Ginecología',
    'menstruación': 'Ginecología',
    'tiroides': 'Endocrinología',
    'diabetes': 'Endocrinología',
    'oído': 'Otorrino',
    'garganta': 'Otorrino',
    'nariz': 'Otorrino',
    'dieta': 'Nutrición',
    'peso': 'Nutrición',
    'alimentación': 'Nutrición',
  };

  /// Filtrado local instantáneo por nombre o especialidad
  List<Doctor> get _visibles {
    if (_query.isEmpty) return _doctors;
    final q = _query.toLowerCase();
    return _doctors
        .where((d) =>
            d.nombre.toLowerCase().contains(q) ||
            d.especialidad.toLowerCase().contains(q))
        .toList();
  }

  /// Sugerencias de autocompletado: especialidades + síntomas
  List<(String, String)> get _sugerencias {
    if (_query.length < 2) return [];
    final q = _query.toLowerCase();
    final result = <(String, String)>[];
    for (final esp in _especialidades) {
      if (esp != 'Todas' && esp.toLowerCase().contains(q)) {
        result.add((esp, 'Especialidad'));
      }
    }
    for (final e in _sintomas.entries) {
      if (e.key.contains(q)) {
        result.add((e.value, 'Por síntoma: "${e.key}"'));
      }
    }
    // sin duplicados, máximo 4
    final vistos = <String>{};
    return result
        .where((s) => vistos.add('${s.$1}${s.$2}'))
        .take(4)
        .toList();
  }

  final List<String> _especialidades = [
    'Todas',
    'Medicina General',
    'Nutrición',
    'Psicología',
    'Pediatría',
    'Ginecología',
    'Dermatología',
    'Cardiología',
    'Endocrinología',
    'Psiquiatría',
    'Otorrino',
  ];

  List<Map<String, dynamic>> _convenios = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadConvenios();
  }

  Future<void> _loadConvenios() async {
    try {
      final data = await ApiService.getBenefits();
      if (mounted) setState(() => _convenios = data);
    } catch (_) {}
  }

  void _verMasEspecialidades() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Todas las especialidades',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _especialidades
                  .map((esp) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() =>
                              _filtro = esp == 'Todas' ? null : esp);
                          _load(esp == 'Todas' ? null : esp);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: (_filtro == esp ||
                                    (esp == 'Todas' && _filtro == null))
                                ? AppColors.primaryLight.withOpacity(0.1)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (_filtro == esp ||
                                      (esp == 'Todas' && _filtro == null))
                                  ? AppColors.primaryLight
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Text(
                            esp,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: (_filtro == esp ||
                                      (esp == 'Todas' && _filtro == null))
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
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
                                  hintText: 'Médico, especialidad o síntoma…',
                                  hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.5), fontSize: 14),
                                  prefixIcon: const Icon(Icons.search_rounded,
                                      color: Colors.white60, size: 20),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  suffixIcon: _query.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded,
                                              color: Colors.white60, size: 18),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() => _query = '');
                                          },
                                        )
                                      : null,
                                ),
                                // Resultados instantáneos mientras escribe
                                onChanged: (v) => setState(() => _query = v.trim()),
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
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Chips principales (las 5 más comunes)
                    ..._especialidades.take(5).map((esp) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: esp,
                            selected: _filtro == esp ||
                                (esp == 'Todas' && _filtro == null),
                            onTap: () {
                              setState(() => _filtro = esp == 'Todas' ? null : esp);
                              _load(esp == 'Todas' ? null : esp);
                            },
                          ),
                        )),
                    // Si el filtro activo no está entre las visibles, mostrarlo
                    if (_filtro != null &&
                        !_especialidades.take(5).contains(_filtro))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: _filtro!,
                          selected: true,
                          onTap: () {},
                        ),
                      ),
                    _FilterChip(
                      label: 'Más ▾',
                      selected: false,
                      onTap: _verMasEspecialidades,
                    ),
                  ],
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
          else if (_visibles.isEmpty)
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
          else ...[
            // ── Autocompletado: sugerencias mientras escribe ────────────────
            if (_sugerencias.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    decoration: AppTheme.glassCard(radius: 16),
                    child: Column(
                      children: _sugerencias
                          .map((s) => ListTile(
                                dense: true,
                                leading: Icon(
                                  s.$2 == 'Especialidad'
                                      ? Icons.medical_services_outlined
                                      : Icons.healing_outlined,
                                  size: 18,
                                  color: AppColors.primaryLight,
                                ),
                                title: Text(s.$1,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                subtitle: Text(s.$2,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint)),
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _query = '';
                                    _filtro = s.$1;
                                  });
                                  _load(s.$1);
                                  FocusScope.of(context).unfocus();
                                },
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            // ── Convenios: espacio publicitario siempre visible (arriba) ────
            if (_convenios.isNotEmpty && _query.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CONVENIOS Y BENEFICIOS',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 116,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 16),
                          itemCount: _convenios.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) =>
                              _ConvenioCard(convenio: _convenios[i]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => DoctorCard(
                    doctor: _visibles[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DoctorDetailScreen(doctor: _visibles[i])),
                    ),
                  ),
                  childCount: _visibles.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Chip de filtro de especialidad ────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
}

// ── Tarjeta de convenio ────────────────────────────────────────────────────────

class _ConvenioCard extends StatelessWidget {
  final Map<String, dynamic> convenio;
  const _ConvenioCard({required this.convenio});

  (IconData, Color) get _estilo {
    switch (convenio['tipo'] as String? ?? '') {
      case 'laboratorio':
        return (Icons.biotech_rounded, const Color(0xFF7C3AED));
      case 'optica':
        return (Icons.visibility_rounded, const Color(0xFF2563EB));
      case 'farmacia':
        return (Icons.local_pharmacy_rounded, AppColors.accentDark);
      case 'gimnasio':
        return (Icons.fitness_center_rounded, const Color(0xFFF59E0B));
      default:
        return (Icons.card_giftcard_rounded, AppColors.primaryLight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _estilo;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              if ((convenio['descuento'] as String? ?? '').isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    convenio['descuento'] as String,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            convenio['nombre_convenio'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              convenio['descripcion'] as String? ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
