import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/doctor_card.dart';
import 'doctor_detail_screen.dart';

/// Buscar médico — Design System 2.0.
/// Sin header sólido: la búsqueda flota sobre el lienzo papel (floating
/// search bar), chips en píldora de tinta, empty state ilustrado.
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

  static const _sintomas = {
    'fiebre': 'Medicina General', 'gripe': 'Medicina General',
    'tos': 'Medicina General', 'dolor de cabeza': 'Medicina General',
    'migraña': 'Medicina General', 'piel': 'Dermatología',
    'acné': 'Dermatología', 'manchas': 'Dermatología',
    'ansiedad': 'Psicología', 'estrés': 'Psicología',
    'depresión': 'Psicología', 'insomnio': 'Psiquiatría',
    'corazón': 'Cardiología', 'presión': 'Cardiología',
    'palpitaciones': 'Cardiología', 'niño': 'Pediatría',
    'bebé': 'Pediatría', 'embarazo': 'Ginecología',
    'menstruación': 'Ginecología', 'tiroides': 'Endocrinología',
    'diabetes': 'Endocrinología', 'oído': 'Otorrino',
    'garganta': 'Otorrino', 'nariz': 'Otorrino',
    'dieta': 'Nutrición', 'peso': 'Nutrición',
    'alimentación': 'Nutrición',
  };

  List<Doctor> get _visibles {
    if (_query.isEmpty) return _doctors;
    final q = _query.toLowerCase();
    return _doctors
        .where((d) =>
            d.nombre.toLowerCase().contains(q) ||
            d.especialidad.toLowerCase().contains(q))
        .toList();
  }

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
      if (e.key.contains(q)) result.add((e.value, 'Por síntoma: "${e.key}"'));
    }
    final vistos = <String>{};
    return result.where((s) => vistos.add('${s.$1}${s.$2}')).take(4).toList();
  }

  final List<String> _especialidades = [
    'Todas', 'Medicina General', 'Nutrición', 'Psicología', 'Pediatría',
    'Ginecología', 'Dermatología', 'Cardiología', 'Endocrinología',
    'Psiquiatría', 'Otorrino',
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
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(DS.s3),
        decoration: BoxDecoration(
          color: DSColors.surface,
          borderRadius: DSRadius.rLg,
          boxShadow: DSElevation.hero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: DS.s3),
              decoration: BoxDecoration(
                color: DSColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Todas las especialidades', style: DSText.title),
            const SizedBox(height: DS.s3),
            Wrap(
              spacing: DS.s1,
              runSpacing: DS.s1,
              children: _especialidades.map((esp) {
                final sel = _filtro == esp || (esp == 'Todas' && _filtro == null);
                return DSPressable(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _filtro = esp == 'Todas' ? null : esp);
                    _load(esp == 'Todas' ? null : esp);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: sel ? DSColors.ink : DSColors.canvas,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(esp,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : DSColors.textMid)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: DS.s2),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: DSColors.coral));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // ── Título flotante sobre lienzo (sin header sólido) ───────────
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, DS.s1),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Buscar médico', style: DSText.title),
                  ),
                  DSPressable(
                    onTap: () => _load(_filtro),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DSColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: DSElevation.rest,
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          size: 19, color: DSColors.textMid),
                    ),
                  ),
                ],
              ),
            ),
            // ── Floating search bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DS.s2),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: DSColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: DSElevation.float,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: DSText.body.copyWith(color: DSColors.textStrong, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Médico, especialidad o síntoma…',
                    hintStyle: const TextStyle(color: DSColors.textFaint, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: DSColors.brand, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: DSColors.textFaint, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
            ),
            const SizedBox(height: DS.s2),
            // ── Chips de especialidad (píldoras de tinta) ───────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DS.s2),
                children: [
                  ..._especialidades.take(5).map((esp) => Padding(
                        padding: const EdgeInsets.only(right: DS.s1),
                        child: _Pill(
                          label: esp,
                          selected: _filtro == esp || (esp == 'Todas' && _filtro == null),
                          onTap: () {
                            setState(() => _filtro = esp == 'Todas' ? null : esp);
                            _load(esp == 'Todas' ? null : esp);
                          },
                        ),
                      )),
                  if (_filtro != null && !_especialidades.take(5).contains(_filtro))
                    Padding(
                      padding: const EdgeInsets.only(right: DS.s1),
                      child: _Pill(label: _filtro!, selected: true, onTap: () {}),
                    ),
                  _Pill(label: 'Más ▾', selected: false, onTap: _verMasEspecialidades),
                ],
              ),
            ),
            const SizedBox(height: DS.s1),
            // ── Contenido ────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? ListView(children: const [
                      SkeletonCard(), SkeletonCard(), SkeletonCard(),
                      SkeletonCard(), SkeletonCard(),
                    ])
                  : _visibles.isEmpty
                      ? _buildEmpty()
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 120),
                          children: [
                            if (_sugerencias.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(DS.s2, DS.s1, DS.s2, 0),
                                child: DSCard(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: _sugerencias
                                        .map((s) => ListTile(
                                              dense: true,
                                              leading: Icon(
                                                s.$2 == 'Especialidad'
                                                    ? Icons.medical_services_outlined
                                                    : Icons.healing_outlined,
                                                size: 18, color: DSColors.brand,
                                              ),
                                              title: Text(s.$1, style: DSText.headline),
                                              subtitle: Text(s.$2, style: DSText.label),
                                              onTap: () {
                                                _searchCtrl.clear();
                                                setState(() { _query = ''; _filtro = s.$1; });
                                                _load(s.$1);
                                                FocusScope.of(context).unfocus();
                                              },
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ),
                            if (_convenios.isNotEmpty && _query.isEmpty) ...[
                              const SizedBox(height: DS.s2),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: DS.s2),
                                child: const DSSectionHeader(title: 'Convenios y beneficios'),
                              ),
                              SizedBox(
                                height: 116,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: DS.s2),
                                  itemCount: _convenios.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: DS.s1),
                                  itemBuilder: (_, i) => _ConvenioCard(convenio: _convenios[i]),
                                ),
                              ),
                              const SizedBox(height: DS.s1),
                            ],
                            ..._visibles.map((d) => DoctorCard(
                                  doctor: d,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: d)),
                                  ),
                                )),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(DS.s3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ilustración generativa: anillos concéntricos con lupa
              SizedBox(
                width: 120, height: 120,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: DSColors.brandSoft, shape: BoxShape.circle),
                  ),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                        color: DSColors.brand.withOpacity(0.12), shape: BoxShape.circle),
                  ),
                  const Icon(Icons.person_search_rounded, size: 40, color: DSColors.brand),
                ]),
              ),
              const SizedBox(height: DS.s3),
              const Text('Sin resultados', style: DSText.headline),
              const SizedBox(height: 6),
              const Text('Probá con otra especialidad o síntoma',
                  style: DSText.body, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

// ── Píldora de filtro (tinta cuando activa) ───────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => DSPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? DSColors.ink : DSColors.surface,
            borderRadius: BorderRadius.circular(100),
            boxShadow: selected ? [] : DSElevation.rest,
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : DSColors.textMid,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        ),
      );
}

// ── Tarjeta de convenio ────────────────────────────────────────────────────────

class _ConvenioCard extends StatelessWidget {
  final Map<String, dynamic> convenio;
  const _ConvenioCard({required this.convenio});

  (IconData, Color) get _estilo {
    switch (convenio['tipo'] as String? ?? '') {
      case 'laboratorio': return (Icons.biotech_rounded, const Color(0xFF8B5CF6));
      case 'optica': return (Icons.visibility_rounded, DSColors.brand);
      case 'farmacia': return (Icons.local_pharmacy_rounded, DSColors.mint);
      case 'gimnasio': return (Icons.fitness_center_rounded, const Color(0xFFF59E0B));
      default: return (Icons.card_giftcard_rounded, DSColors.brand);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _estilo;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(DS.s2),
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.rMd,
        boxShadow: DSElevation.rest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              if ((convenio['descuento'] as String? ?? '').isNotEmpty)
                DSChip(label: convenio['descuento'] as String, color: color),
            ],
          ),
          const SizedBox(height: DS.s1),
          Text(convenio['nombre_convenio'] as String? ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: DSText.headline),
          const SizedBox(height: 3),
          Expanded(
            child: Text(convenio['descripcion'] as String? ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: DSText.label),
          ),
        ],
      ),
    );
  }
}
