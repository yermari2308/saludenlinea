import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../services/api_service.dart';

class MedicalRecordScreen extends StatefulWidget {
  const MedicalRecordScreen({super.key});

  @override
  State<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
  Map<String, dynamic>? _record;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getMedicalRecord();
      if (mounted) setState(() { _record = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int get _completitud => (_record?['completitud_pct'] as int?) ?? 0;

  /// Color semántico según el avance del expediente.
  Color get _colorAvance => _completitud >= 80
      ? DSColors.mint
      : _completitud >= 40
          ? const Color(0xFFF59E0B)
          : DSColors.coral;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.ink,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: DSColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: DSColors.brand))
                  : _error != null
                      ? _buildError()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(DS.s3, DS.s3, DS.s3, DS.s5),
                          children: _buildSecciones(),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  /// Encabezado de tinta con anillo de completitud y serie del expediente.
  Widget _buildHeader() {
    final serie = _record?['id'] != null
        ? 'EXP-${_record!['id'].toString().padLeft(6, '0')}'
        : null;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [DSColors.ink, DSColors.inkSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s3, DS.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DSPressable(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  if (serie != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(serie,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w800, letterSpacing: 0.6,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                ],
              ),
              const SizedBox(height: DS.s2),
              Row(
                children: [
                  DSProgressRing(
                    pct: _completitud / 100,
                    color: _colorAvance,
                    size: 72,
                    center: Text('$_completitud%',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                  const SizedBox(width: DS.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Expediente clínico',
                            style: TextStyle(
                                color: Colors.white, fontSize: 21,
                                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        const SizedBox(height: 5),
                        Text(
                          _completitud < 40
                              ? 'Completalo para consultas más precisas'
                              : _completitud < 80
                                  ? 'Buen avance — agregá más datos'
                                  : 'Expediente casi completo',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSecciones() {
    final secciones = _record?['secciones'] as Map<String, dynamic>? ?? {};

    final config = [
      _SeccionConfig(
        key: 'datos_personales',
        titulo: 'Datos personales',
        icono: Icons.badge_rounded,
        color: AppColors.primaryLight,
        campos: [
          _Campo('tipo_sangre', 'Tipo de sangre', tipo: _TipoCampo.texto),
          _Campo('estado_civil', 'Estado civil', tipo: _TipoCampo.select,
              opciones: ['Soltero/a', 'Casado/a', 'Divorciado/a', 'Viudo/a', 'Unión libre']),
          _Campo('ocupacion', 'Ocupación', tipo: _TipoCampo.texto),
          _Campo('contacto_emergencia', 'Contacto de emergencia', tipo: _TipoCampo.texto),
        ],
      ),
      _SeccionConfig(
        key: 'somatometria',
        titulo: 'Somatometría',
        icono: Icons.monitor_heart_rounded,
        color: const Color(0xFF7C3AED),
        campos: [
          _Campo('peso', 'Peso (kg)', tipo: _TipoCampo.numero),
          _Campo('altura', 'Altura (m)', tipo: _TipoCampo.numero),
          _Campo('presion_arterial', 'Presión arterial', tipo: _TipoCampo.texto),
          _Campo('frecuencia_cardiaca', 'Frecuencia cardíaca (lpm)', tipo: _TipoCampo.numero),
        ],
        extraInfo: (datos) {
          final imc = datos['imc'];
          if (imc == null) return null;
          final v = (imc as num).toDouble();
          String cat;
          Color c;
          if (v < 18.5) { cat = 'Bajo peso'; c = const Color(0xFF3B82F6); }
          else if (v < 25) { cat = 'Normal'; c = AppColors.accentDark; }
          else if (v < 30) { cat = 'Sobrepeso'; c = const Color(0xFFF59E0B); }
          else { cat = 'Obesidad'; c = AppColors.error; }
          return _ImcBadge(imc: v, categoria: cat, color: c);
        },
      ),
      _SeccionConfig(
        key: 'patologicos',
        titulo: 'Antecedentes patológicos',
        icono: Icons.local_hospital_rounded,
        color: AppColors.error,
        campos: [
          _Campo('enfermedades_cronicas', 'Enfermedades crónicas', tipo: _TipoCampo.lista),
          _Campo('cirugias', 'Cirugías previas', tipo: _TipoCampo.lista),
          _Campo('alergias', 'Alergias', tipo: _TipoCampo.lista),
          _Campo('medicamentos_actuales', 'Medicamentos actuales', tipo: _TipoCampo.lista),
        ],
      ),
      _SeccionConfig(
        key: 'no_patologicos',
        titulo: 'Hábitos y estilo de vida',
        icono: Icons.self_improvement_rounded,
        color: AppColors.accentDark,
        campos: [
          _Campo('tabaquismo', 'Tabaquismo', tipo: _TipoCampo.select,
              opciones: ['No fuma', 'Ex-fumador', 'Fumador ocasional', 'Fumador frecuente']),
          _Campo('alcohol', 'Consumo de alcohol', tipo: _TipoCampo.select,
              opciones: ['No consume', 'Ocasional', 'Moderado', 'Frecuente']),
          _Campo('ejercicio', 'Actividad física', tipo: _TipoCampo.select,
              opciones: ['Sedentario', '1-2 días/semana', '3-4 días/semana', 'Diario']),
          _Campo('alimentacion', 'Tipo de alimentación', tipo: _TipoCampo.texto),
        ],
      ),
      _SeccionConfig(
        key: 'vacunacion',
        titulo: 'Vacunación',
        icono: Icons.vaccines_rounded,
        color: const Color(0xFF0891B2),
        campos: [],
        esLista: true,
      ),
      _SeccionConfig(
        key: 'salud_femenina',
        titulo: 'Salud femenina',
        icono: Icons.favorite_rounded,
        color: const Color(0xFFDB2777),
        campos: [
          _Campo('fecha_ultima_menstruacion', 'Última menstruación', tipo: _TipoCampo.texto),
          _Campo('embarazos', 'Número de embarazos', tipo: _TipoCampo.numero),
          _Campo('metodo_anticonceptivo', 'Método anticonceptivo', tipo: _TipoCampo.texto),
        ],
        opcional: true,
      ),
    ];

    final widgets = <Widget>[const SizedBox(height: 16)];
    for (final sec in config) {
      final secData = secciones[sec.key] as Map<String, dynamic>? ?? {};
      final pct = secData['completitud_pct'] as int? ?? 0;
      final datos = secData['datos'] as Map<String, dynamic>? ?? {};
      widgets.add(_SeccionCard(
        config: sec,
        datos: datos,
        completitudPct: pct,
        onGuardar: (nuevosDatos) => _guardar(sec.key, nuevosDatos),
      ));
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Future<void> _guardar(String seccion, dynamic datos) async {
    try {
      await ApiService.updateMedicalSection(seccion: seccion, datos: datos);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Sección guardada'),
        ]),
        backgroundColor: AppColors.accentDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Widget _buildError() => DSEmpty(
        icon: Icons.cloud_off_rounded,
        color: DSColors.coral,
        title: 'No pudimos cargar tu expediente',
        message: _error ?? 'Revisá tu conexión e intentá de nuevo.',
        action: DSButton(
          label: 'Reintentar',
          icon: Icons.refresh_rounded,
          onTap: _load,
        ),
      );
}

// ── Modelos de configuración ──────────────────────────────────────────────────

enum _TipoCampo { texto, numero, select, lista }

class _Campo {
  final String key;
  final String label;
  final _TipoCampo tipo;
  final List<String>? opciones;

  const _Campo(this.key, this.label, {required this.tipo, this.opciones});
}

class _SeccionConfig {
  final String key;
  final String titulo;
  final IconData icono;
  final Color color;
  final List<_Campo> campos;
  final bool esLista;
  final bool opcional;
  final Widget? Function(Map<String, dynamic>)? extraInfo;

  const _SeccionConfig({
    required this.key,
    required this.titulo,
    required this.icono,
    required this.color,
    required this.campos,
    this.esLista = false,
    this.opcional = false,
    this.extraInfo,
  });
}

// ── Card de sección ───────────────────────────────────────────────────────────

class _SeccionCard extends StatefulWidget {
  final _SeccionConfig config;
  final Map<String, dynamic> datos;
  final int completitudPct;
  final Future<void> Function(dynamic) onGuardar;

  const _SeccionCard({
    required this.config,
    required this.datos,
    required this.completitudPct,
    required this.onGuardar,
  });

  @override
  State<_SeccionCard> createState() => _SeccionCardState();
}

class _SeccionCardState extends State<_SeccionCard> {
  bool _expanded = false;
  bool _saving = false;
  late Map<String, dynamic> _editData;

  @override
  void initState() {
    super.initState();
    _editData = Map<String, dynamic>.from(widget.datos);
  }

  @override
  void didUpdateWidget(_SeccionCard old) {
    super.didUpdateWidget(old);
    if (old.datos != widget.datos) {
      _editData = Map<String, dynamic>.from(widget.datos);
    }
  }

  Color get _barColor {
    if (widget.completitudPct >= 80) return AppColors.accentDark;
    if (widget.completitudPct >= 40) return const Color(0xFFF59E0B);
    return AppColors.textHint;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onGuardar(_editData);
    if (mounted) setState(() { _saving = false; _expanded = false; });
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.config.extraInfo?.call(_editData);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.rMd,
        boxShadow: _expanded ? DSElevation.float : DSElevation.rest,
      ),
      child: Column(
        children: [
          // Header clicable
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.config.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.config.icono,
                        color: widget.config.color, size: 19),
                  ),
                  const SizedBox(width: DS.s1 + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(widget.config.titulo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                )),
                            if (widget.config.opcional) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.textHint.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('opcional',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textHint)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: widget.completitudPct / 100,
                                  minHeight: 5,
                                  backgroundColor:
                                      AppColors.cardBorder,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      _barColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${widget.completitudPct}%',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _barColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DS.s1),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: DSColors.textFaint),
                  ),
                ],
              ),
            ),
          ),
          // Contenido expandible
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.cardBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (extra != null) ...[extra, const SizedBox(height: 14)],
                  if (widget.config.esLista)
                    _VacunasList(
                      datos: _editData,
                      onChange: (v) => setState(() => _editData = v),
                    )
                  else
                    ...widget.config.campos.map((campo) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CampoWidget(
                            campo: campo,
                            valor: _editData[campo.key],
                            onChange: (v) =>
                                setState(() => _editData[campo.key] = v),
                          ),
                        )),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.config.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar sección',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widget por tipo de campo ──────────────────────────────────────────────────

class _CampoWidget extends StatelessWidget {
  final _Campo campo;
  final dynamic valor;
  final ValueChanged<dynamic> onChange;

  const _CampoWidget({
    required this.campo,
    required this.valor,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    switch (campo.tipo) {
      case _TipoCampo.select:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(campo.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: campo.opciones!.contains(valor?.toString())
                  ? valor?.toString()
                  : null,
              decoration: _inputDeco(),
              hint: const Text('Seleccionar'),
              items: campo.opciones!
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => onChange(v),
            ),
          ],
        );
      case _TipoCampo.lista:
        final lista = (valor is List)
            ? List<String>.from(valor)
            : <String>[];
        return _ListaCampo(
          label: campo.label,
          items: lista,
          onChange: onChange,
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(campo.label),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: valor?.toString() ?? '',
              keyboardType: campo.tipo == _TipoCampo.numero
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: _inputDeco(),
              onChanged: (v) => onChange(
                campo.tipo == _TipoCampo.numero
                    ? (double.tryParse(v) ?? v)
                    : v,
              ),
            ),
          ],
        );
    }
  }

  InputDecoration _inputDeco() => InputDecoration(
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
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}

// ── Lista editable (alergias, cirugías, etc.) ─────────────────────────────────

class _ListaCampo extends StatefulWidget {
  final String label;
  final List<String> items;
  final ValueChanged<List<String>> onChange;

  const _ListaCampo({
    required this.label,
    required this.items,
    required this.onChange,
  });

  @override
  State<_ListaCampo> createState() => _ListaCampoState();
}

class _ListaCampoState extends State<_ListaCampo> {
  late List<String> _items;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _add() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    setState(() => _items.add(v));
    _ctrl.clear();
    widget.onChange(_items);
  }

  void _remove(int i) {
    setState(() => _items.removeAt(i));
    widget.onChange(_items);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label),
        const SizedBox(height: 6),
        ..._items.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: const BorderSide(color: AppColors.cardBorder) as dynamic,
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(e.value,
                          style: const TextStyle(fontSize: 13))),
                  GestureDetector(
                    onTap: () => _remove(e.key),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textHint),
                  ),
                ],
              ),
            )),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: 'Agregar...',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primaryLight, width: 1.5),
                  ),
                ),
                onFieldSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _add,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Lista de vacunas ──────────────────────────────────────────────────────────

class _VacunasList extends StatefulWidget {
  final Map<String, dynamic> datos;
  final ValueChanged<Map<String, dynamic>> onChange;

  const _VacunasList({required this.datos, required this.onChange});

  @override
  State<_VacunasList> createState() => _VacunasListState();
}

class _VacunasListState extends State<_VacunasList> {
  late List<Map<String, String>> _vacunas;
  final _nombreCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final raw = widget.datos['vacunas'];
    if (raw is List) {
      _vacunas = raw.map<Map<String, String>>((e) =>
          {'nombre': e['nombre']?.toString() ?? '', 'fecha': e['fecha']?.toString() ?? ''}).toList();
    } else {
      _vacunas = [];
    }
  }

  void _add() {
    final nombre = _nombreCtrl.text.trim();
    final fecha = _fechaCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _vacunas.add({'nombre': nombre, 'fecha': fecha}));
    _nombreCtrl.clear();
    _fechaCtrl.clear();
    widget.onChange({'vacunas': _vacunas});
  }

  void _remove(int i) {
    setState(() => _vacunas.removeAt(i));
    widget.onChange({'vacunas': _vacunas});
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._vacunas.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vaccines_rounded,
                      size: 16, color: Color(0xFF0891B2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value['nombre'] ?? '',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        if ((e.value['fecha'] ?? '').isNotEmpty)
                          Text(e.value['fecha'] ?? '',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _remove(e.key),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textHint),
                  ),
                ],
              ),
            )),
        const _FieldLabel('Agregar vacuna'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nombreCtrl,
          decoration: _deco('Nombre de la vacuna'),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _fechaCtrl,
          decoration: _deco('Fecha (ej. 2023-06)'),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _add,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF0891B2).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Color(0xFF0891B2), size: 18),
                SizedBox(width: 6),
                Text('Agregar vacuna',
                    style: TextStyle(
                        color: Color(0xFF0891B2),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              const BorderSide(color: Color(0xFF0891B2), width: 1.5),
        ),
      );
}

// ── IMC badge ─────────────────────────────────────────────────────────────────

class _ImcBadge extends StatelessWidget {
  final double imc;
  final String categoria;
  final Color color;

  const _ImcBadge(
      {required this.imc, required this.categoria, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_weight_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('IMC calculado',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
              Text(
                '$imc — $categoria',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: color, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
