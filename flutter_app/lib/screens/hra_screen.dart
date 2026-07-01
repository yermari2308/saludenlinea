import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import 'doctor_detail_screen.dart';
import 'doctors_screen.dart';

class HraScreen extends StatefulWidget {
  const HraScreen({super.key});

  @override
  State<HraScreen> createState() => _HraScreenState();
}

class _HraScreenState extends State<HraScreen> {
  // Controladores
  final _pesoCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _suenoCtrl = TextEditingController();
  final _satCtrl = TextEditingController();

  String? _tabaco;
  String? _alcohol;
  String? _ejercicio;

  bool _enviando = false;
  Map<String, dynamic>? _resultado;

  static const _tabValues = ['no_fuma', 'ex_fumador', 'fumador_ocasional', 'fumador_frecuente'];
  static const _tabLabels = ['No fumo', 'Ex-fumador', 'Ocasional', 'Frecuente'];
  static const _alcValues = ['no_consume', 'ocasional', 'moderado', 'frecuente'];
  static const _alcLabels = ['No consumo', 'Ocasional', 'Moderado', 'Frecuente'];
  static const _ejValues = ['sedentario', '1_2_dias', '3_4_dias', 'diario'];
  static const _ejLabels = ['Sedentario', '1-2 días/sem', '3-4 días/sem', 'Diario'];

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    _suenoCtrl.dispose();
    _satCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final resultado = await ApiService.submitHra(
        pesoKg: double.tryParse(_pesoCtrl.text),
        alturaM: double.tryParse(_alturaCtrl.text),
        suenoHoras: double.tryParse(_suenoCtrl.text),
        tabaco: _tabaco,
        alcohol: _alcohol,
        ejercicio: _ejercicio,
        saturacionPct: double.tryParse(_satCtrl.text),
      );
      if (mounted) setState(() { _resultado = resultado; _enviando = false; });
    } catch (e) {
      setState(() => _enviando = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Evaluación de salud',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_resultado != null)
            TextButton(
              onPressed: () => setState(() => _resultado = null),
              child: const Text('Repetir',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: _resultado != null
          ? _buildResultados()
          : _buildCuestionario(),
    );
  }

  // ── Cuestionario ──────────────────────────────────────────────────────────

  Widget _buildCuestionario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerInfo(),
          const SizedBox(height: 20),

          // Peso y altura
          _PreguntaCard(
            numero: 1,
            titulo: 'Peso y altura',
            icono: Icons.monitor_weight_rounded,
            color: AppColors.primaryLight,
            child: Row(
              children: [
                Expanded(
                  child: _NumField(
                    ctrl: _pesoCtrl,
                    label: 'Peso (kg)',
                    hint: '70',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumField(
                    ctrl: _alturaCtrl,
                    label: 'Altura (m)',
                    hint: '1.70',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sueño
          _PreguntaCard(
            numero: 2,
            titulo: '¿Cuántas horas duermes?',
            icono: Icons.bedtime_rounded,
            color: const Color(0xFF7C3AED),
            child: _NumField(
              ctrl: _suenoCtrl,
              label: 'Horas por noche',
              hint: '8',
            ),
          ),
          const SizedBox(height: 12),

          // Tabaco
          _PreguntaCard(
            numero: 3,
            titulo: 'Hábito de tabaquismo',
            icono: Icons.smoke_free_rounded,
            color: const Color(0xFF374151),
            child: _ChipGroup(
              values: _tabValues,
              labels: _tabLabels,
              selected: _tabaco,
              onSelect: (v) => setState(() => _tabaco = v),
              activeColor: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),

          // Alcohol
          _PreguntaCard(
            numero: 4,
            titulo: 'Consumo de alcohol',
            icono: Icons.no_drinks_rounded,
            color: const Color(0xFFD97706),
            child: _ChipGroup(
              values: _alcValues,
              labels: _alcLabels,
              selected: _alcohol,
              onSelect: (v) => setState(() => _alcohol = v),
              activeColor: const Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 12),

          // Ejercicio
          _PreguntaCard(
            numero: 5,
            titulo: 'Actividad física semanal',
            icono: Icons.directions_run_rounded,
            color: AppColors.accentDark,
            child: _ChipGroup(
              values: _ejValues,
              labels: _ejLabels,
              selected: _ejercicio,
              onSelect: (v) => setState(() => _ejercicio = v),
              activeColor: AppColors.accentDark,
            ),
          ),
          const SizedBox(height: 12),

          // Saturación
          _PreguntaCard(
            numero: 6,
            titulo: 'Saturación de oxígeno (%)',
            icono: Icons.air_rounded,
            color: const Color(0xFF0891B2),
            child: _NumField(
              ctrl: _satCtrl,
              label: 'Saturación O₂ (%)',
              hint: '98',
            ),
          ),
          const SizedBox(height: 28),

          // Botón enviar
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _enviando ? null : _enviar,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assessment_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Ver mis resultados',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
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
    );
  }

  Widget _headerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Responde las preguntas según tu situación actual. Los resultados son orientativos, no reemplazan una consulta médica.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Resultados ────────────────────────────────────────────────────────────

  Widget _buildResultados() {
    final recs = (_resultado!['recomendaciones'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final pct = _resultado!['pct_salud'] as int? ?? 0;
    final nivel = _resultado!['nivel'] as String? ?? 'regular';
    final imc = _resultado!['imc'] as num?;
    final requiereCita = _resultado!['requiere_cita'] as bool? ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        children: [
          // Score global
          _ScoreGlobal(pct: pct, nivel: nivel, imc: imc),
          const SizedBox(height: 20),

          // Tarjetas por parámetro
          ...recs.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RecomendacionCard(rec: r),
              )),

          // Botón agendar cita si hay rojos
          if (requiereCita) ...[
            const SizedBox(height: 8),
            _AgendarCitaBtn(),
          ],
          const SizedBox(height: 20),

          // Historial
          _HistorialSection(),
        ],
      ),
    );
  }
}

// ── Widgets de cuestionario ───────────────────────────────────────────────────

class _PreguntaCard extends StatelessWidget {
  final int numero;
  final String titulo;
  final IconData icono;
  final Color color;
  final Widget child;

  const _PreguntaCard({
    required this.numero,
    required this.titulo,
    required this.icono,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$numero',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icono, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;

  const _NumField({required this.ctrl, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primaryLight, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> values;
  final List<String> labels;
  final String? selected;
  final ValueChanged<String> onSelect;
  final Color activeColor;

  const _ChipGroup({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onSelect,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(values.length, (i) {
        final isSelected = selected == values[i];
        return GestureDetector(
          onTap: () => onSelect(values[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor
                  : activeColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? activeColor
                    : activeColor.withOpacity(0.25),
              ),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                color: isSelected ? Colors.white : activeColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Widgets de resultados ─────────────────────────────────────────────────────

class _ScoreGlobal extends StatelessWidget {
  final int pct;
  final String nivel;
  final num? imc;

  const _ScoreGlobal({required this.pct, required this.nivel, this.imc});

  Color get _color {
    if (pct >= 75) return AppColors.accentDark;
    if (pct >= 50) return const Color(0xFFF59E0B);
    return AppColors.error;
  }

  String get _nivelLabel {
    switch (nivel) {
      case 'bueno': return 'Salud en buen estado';
      case 'regular': return 'Salud regular — hay áreas a mejorar';
      default: return 'Atención — revisa los parámetros en rojo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _color.withOpacity(0.08),
            _color.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Círculo de score
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _color.withOpacity(0.12),
                  border: Border.all(color: _color.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$pct%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _color,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nivelLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 8,
                        backgroundColor: _color.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(_color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (imc != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monitor_weight_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('IMC calculado: $imc',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecomendacionCard extends StatelessWidget {
  final Map<String, dynamic> rec;

  const _RecomendacionCard({required this.rec});

  Color get _color {
    switch (rec['color']) {
      case 'verde': return AppColors.accentDark;
      case 'amarillo': return const Color(0xFFF59E0B);
      default: return AppColors.error;
    }
  }

  IconData get _icono {
    switch (rec['icono']?.toString()) {
      case 'monitor_weight': return Icons.monitor_weight_rounded;
      case 'bedtime': return Icons.bedtime_rounded;
      case 'smoke_free': return Icons.smoke_free_rounded;
      case 'no_drinks': return Icons.no_drinks_rounded;
      case 'directions_run': return Icons.directions_run_rounded;
      case 'air': return Icons.air_rounded;
      default: return Icons.health_and_safety_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: _color, width: 3)),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_icono, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rec['parametro']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rec['color']?.toString() ?? '',
                        style: TextStyle(
                          color: _color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rec['texto']?.toString() ?? '',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
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

class _AgendarCitaBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DoctorsScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Agendar consulta con un médico',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorialSection extends StatefulWidget {
  @override
  State<_HistorialSection> createState() => _HistorialSectionState();
}

class _HistorialSectionState extends State<_HistorialSection> {
  List<Map<String, dynamic>>? _historial;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await ApiService.getHraHistory();
      if (mounted) setState(() { _historial = h; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_historial == null || _historial!.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HISTORIAL DE EVALUACIONES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        ..._historial!.skip(1).map((h) {
          final pct = h['pct_salud'] as int? ?? 0;
          final fecha = h['creado_en']?.toString().substring(0, 10) ?? '';
          final Color c = pct >= 75
              ? AppColors.accentDark
              : pct >= 50
                  ? const Color(0xFFF59E0B)
                  : AppColors.error;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [AppTheme.cardShadow],
            ),
            child: Row(
              children: [
                Icon(Icons.assessment_rounded, color: c, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(fecha,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
                Text('$pct%',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: c, fontSize: 15)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
