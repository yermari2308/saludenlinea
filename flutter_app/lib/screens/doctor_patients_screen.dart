import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

/// Pestaña "Pacientes" del panel médico: lista de pacientes atendidos,
/// con acceso al expediente, chat y subida de recetas.
class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

/// Número de serie único del expediente, derivado del id del paciente.
String serieExpediente(int pacienteId) =>
    'EXP-${pacienteId.toString().padLeft(6, '0')}';

/// Command Palette (estilo Raycast): búsqueda instantánea de expedientes
/// por N° de serie o nombre, desde cualquier parte del panel médico.
Future<void> mostrarCommandPalette(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CommandPalette(),
  );
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette();

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  List<Map<String, dynamic>> _pacientes = [];
  String _q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ApiService.getDoctorPatients().then((d) {
      if (mounted) setState(() { _pacientes = d; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  List<Map<String, dynamic>> get _resultados {
    if (_q.isEmpty) return _pacientes.take(5).toList();
    final q = _q.toLowerCase().trim();
    final qNum = q.replaceAll(RegExp(r'[^0-9]'), '');
    return _pacientes.where((p) {
      final nombre = (p['nombre'] as String).toLowerCase();
      final id = p['paciente_id'] as int;
      if (nombre.contains(q)) return true;
      if (serieExpediente(id).toLowerCase().contains(q)) return true;
      if (qNum.isNotEmpty &&
          id.toString() == qNum.replaceFirst(RegExp(r'^0+'), '')) return true;
      return false;
    }).take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DSColors.ink.withOpacity(0.97),
          borderRadius: BorderRadius.circular(24),
          boxShadow: DSElevation.hero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Campo de comando ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'EXP-000123, nombre del paciente…',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 15),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: DSColors.mint, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(height: 8),
            // ── Resultados en tiempo real ─────────────────────────────────
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: DSColors.mint),
              )
            else if (_resultados.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Sin resultados para "$_q"',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 14)),
              )
            else
              ..._resultados.map((p) => _PaletteRow(
                    paciente: p,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                DoctorPatientDetailScreen(paciente: p)),
                      );
                    },
                  )),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  final Map<String, dynamic> paciente;
  final VoidCallback onTap;

  const _PaletteRow({required this.paciente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final id = paciente['paciente_id'] as int;
    return DSPressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DSColors.mint.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                serieExpediente(id),
                style: const TextStyle(
                    color: DSColors.mint,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                paciente['nombre'] as String? ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${paciente['total_citas']} consultas',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 12),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  List<Map<String, dynamic>> _pacientes = [];
  bool _loading = true;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getDoctorPatients();
      if (mounted) setState(() => _pacientes = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busqueda.isEmpty) return _pacientes;
    final q = _busqueda.toLowerCase().trim();
    final qSerie = q.replaceAll(RegExp(r'[^0-9]'), '');
    return _pacientes.where((p) {
      final nombre = (p['nombre'] as String).toLowerCase();
      if (nombre.contains(q)) return true;
      final id = p['paciente_id'] as int;
      final serie = serieExpediente(id).toLowerCase();
      if (serie.contains(q)) return true;
      if (qSerie.isNotEmpty && id.toString() == qSerie.replaceFirst(RegExp(r'^0+'), '')) {
        return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, DS.s1),
              child: Row(
                children: [
                  const Expanded(child: Text('Mis pacientes', style: DSText.title)),
                  DSPressable(
                    onTap: () => mostrarCommandPalette(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: DSColors.ink, shape: BoxShape.circle, boxShadow: DSElevation.rest),
                      child: const Icon(Icons.bolt_rounded, size: 18, color: DSColors.mint),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DS.s2),
              child: Container(
                height: 48,
                decoration: BoxDecoration(color: DSColors.surface, borderRadius: BorderRadius.circular(14), boxShadow: DSElevation.float),
                child: TextField(
                  style: const TextStyle(fontSize: 14, color: DSColors.textStrong),
                  decoration: InputDecoration(
                    hintText: 'Nombre o N° de expediente (EXP-000123)…',
                    hintStyle: const TextStyle(color: DSColors.textFaint, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: DSColors.brand, size: 21),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
            ),
            const SizedBox(height: DS.s1),
            Expanded(
              child: _loading
                  ? ListView(children: const [SkeletonCard(), SkeletonCard(), SkeletonCard()])
                  : _filtrados.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: DSColors.brand,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(DS.s2, 0, DS.s2, 120),
                            itemCount: _filtrados.length,
                            separatorBuilder: (_, __) => const SizedBox(height: DS.s1),
                            itemBuilder: (_, i) => _PacienteCard(
                              paciente: _filtrados[i],
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DoctorPatientDetailScreen(paciente: _filtrados[i])),
                                );
                                _load();
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100, height: 100,
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 100, height: 100, decoration: const BoxDecoration(color: DSColors.brandSoft, shape: BoxShape.circle)),
                const Icon(Icons.groups_rounded, size: 40, color: DSColors.brand),
              ]),
            ),
            const SizedBox(height: DS.s2),
            const Text('Aún no tenés pacientes', style: DSText.headline),
            const SizedBox(height: 6),
            const Text('Aparecerán aquí cuando agenden citas con vos', style: DSText.body, textAlign: TextAlign.center),
          ],
        ),
      );
}

class _PacienteCard extends StatelessWidget {
  final Map<String, dynamic> paciente;
  final VoidCallback onTap;

  const _PacienteCard({required this.paciente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombre = paciente['nombre'] as String? ?? '';
    final iniciales = nombre.length >= 2 ? nombre.substring(0, 2).toUpperCase() : nombre.toUpperCase();
    final totalCitas = paciente['total_citas'] as int? ?? 0;
    final activa = paciente['cita_activa_id'] != null;

    return DSCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [DSColors.brand, Color(0xFF7C74F2)]),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(iniciales, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: DS.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: DSText.headline),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: DSColors.brandSoft, borderRadius: BorderRadius.circular(6)),
                      child: Text(serieExpediente(paciente['paciente_id'] as int),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: DSColors.brand)),
                    ),
                    const SizedBox(width: 6),
                    Text('$totalCitas consulta${totalCitas == 1 ? '' : 's'}', style: DSText.label),
                  ],
                ),
              ],
            ),
          ),
          if (activa) const DSChip(label: 'Cita activa', color: DSColors.mint),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: DSColors.textFaint),
        ],
      ),
    );
  }
}

// ── Detalle del paciente ────────────────────────────────────────────

class DoctorPatientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> paciente;
  const DoctorPatientDetailScreen({super.key, required this.paciente});

  @override
  State<DoctorPatientDetailScreen> createState() => _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  Map<String, dynamic>? _expediente;
  bool _loadingExp = true;

  @override
  void initState() {
    super.initState();
    _loadExpediente();
  }

  Future<void> _loadExpediente() async {
    try {
      final data = await ApiService.getPatientMedicalRecord(widget.paciente['paciente_id'] as int);
      if (mounted) setState(() => _expediente = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingExp = false);
    }
  }

  Future<void> _abrirChat() async {
    final citaId = widget.paciente['cita_activa_id'] as int?;
    if (citaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El chat está disponible cuando hay una cita programada')));
      return;
    }
    final info = await ApiService.getUserInfo();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          citaId: citaId,
          remitente: 'doctor',
          remitenteId: info['id'] ?? 0,
          nombreOtro: widget.paciente['nombre'] as String? ?? 'Paciente',
        ),
      ),
    );
  }

  Future<void> _subirReceta() async {
    final citaId = (widget.paciente['cita_activa_id'] ?? widget.paciente['ultima_cita_id']) as int?;
    if (citaId == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    try {
      await ApiService.subirRecetaArchivo(citaId, result.files.single.bytes!, result.files.single.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Receta subida correctamente'),
        backgroundColor: DSColors.mint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: DSColors.coral));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.paciente['nombre'] as String? ?? '';
    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, DS.s3),
          children: [
            Row(children: [
              DSPressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: DSColors.surface, shape: BoxShape.circle, boxShadow: DSElevation.rest),
                  child: const Icon(Icons.arrow_back_rounded, size: 18, color: DSColors.textMid),
                ),
              ),
              const SizedBox(width: DS.s2),
              Expanded(child: Text(nombre, style: DSText.title, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: DS.s2),
            Row(
              children: [
                Expanded(child: DSButton(label: 'Chat', icon: Icons.chat_bubble_rounded, color: DSColors.brand, onTap: _abrirChat)),
                const SizedBox(width: DS.s1),
                Expanded(child: DSButton(label: 'Receta', icon: Icons.upload_file_rounded, color: DSColors.mint, onTap: _subirReceta)),
              ],
            ),
            const SizedBox(height: DS.s3),
            const DSSectionHeader(title: 'Contacto'),
            DSCard(
              child: Column(
                children: [
                  _DatoRow(icon: Icons.badge_rounded, valor: 'Expediente N° ${serieExpediente(widget.paciente['paciente_id'] as int)}'),
                  _DatoRow(icon: Icons.email_rounded, valor: widget.paciente['email'] as String? ?? ''),
                  if ((widget.paciente['telefono'] as String? ?? '').isNotEmpty)
                    _DatoRow(icon: Icons.phone_rounded, valor: widget.paciente['telefono'] as String),
                  _DatoRow(icon: Icons.calendar_month_rounded, valor: '${widget.paciente['total_citas']} consultas contigo', isLast: true),
                ],
              ),
            ),
            const SizedBox(height: DS.s2),
            const DSSectionHeader(title: 'Expediente clínico'),
            DSCard(
              child: _loadingExp
                  ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: DSColors.brand)))
                  : _expediente == null
                      ? const Text('El expediente estará disponible cuando exista una cita con este paciente.', style: DSText.body)
                      : _ExpedienteViewer(expediente: _expediente!),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatoRow extends StatelessWidget {
  final IconData icon;
  final String valor;
  final bool isLast;
  const _DatoRow({required this.icon, required this.valor, this.isLast = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : DS.s1),
        child: Row(
          children: [
            Icon(icon, size: 15, color: DSColors.textFaint),
            const SizedBox(width: 10),
            Expanded(child: Text(valor, style: const TextStyle(fontSize: 13.5, color: DSColors.textStrong, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

// ── Visor de expediente (solo lectura) ─────────────────────────────────────────

class _ExpedienteViewer extends StatelessWidget {
  final Map<String, dynamic> expediente;
  const _ExpedienteViewer({required this.expediente});

  static const _titulos = {
    'datos_personales': 'Datos personales',
    'somatometria': 'Somatometría',
    'patologicos': 'Antecedentes patológicos',
    'no_patologicos': 'Antecedentes no patológicos',
    'vacunacion': 'Vacunación',
    'salud_femenina': 'Salud femenina',
  };

  @override
  Widget build(BuildContext context) {
    final pct = expediente['completitud_pct'] as int? ?? 0;
    final secciones = expediente['secciones'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct / 100, minHeight: 6, backgroundColor: DSColors.line, valueColor: const AlwaysStoppedAnimation(DSColors.mint)),
              ),
            ),
            const SizedBox(width: 8),
            Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DSColors.textMid)),
          ],
        ),
        const SizedBox(height: DS.s2),
        ..._titulos.entries.map((e) {
          final sec = secciones[e.key] as Map<String, dynamic>?;
          if (sec == null) return const SizedBox.shrink();
          final datos = sec['datos'];
          if (datos == null) return const SizedBox.shrink();
          return _SeccionExpediente(titulo: e.value, datos: datos);
        }),
      ],
    );
  }
}

class _SeccionExpediente extends StatelessWidget {
  final String titulo;
  final dynamic datos;
  const _SeccionExpediente({required this.titulo, required this.datos});

  String _fmt(dynamic v) {
    if (v == null) return '—';
    if (v is List) {
      if (v.isEmpty) return '—';
      return v.map((e) => e is Map ? e.values.join(' · ') : e.toString()).join('\n');
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> mapa = {};
    List lista = [];
    if (datos is Map) {
      mapa = (datos as Map).cast<String, dynamic>();
    } else if (datos is List) {
      lista = datos as List;
    } else if (datos is String && (datos as String).isNotEmpty) {
      try {
        final dec = jsonDecode(datos as String);
        if (dec is Map) mapa = dec.cast<String, dynamic>();
        if (dec is List) lista = dec;
      } catch (_) {}
    }

    final vacio = mapa.isEmpty && lista.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: DSColors.brand)),
          const SizedBox(height: 5),
          if (vacio)
            const Text('Sin datos registrados', style: TextStyle(fontSize: 12, color: DSColors.textFaint))
          else if (mapa.isNotEmpty)
            ...mapa.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 130, child: Text(e.key.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, color: DSColors.textMid))),
                      Expanded(child: Text(_fmt(e.value), style: const TextStyle(fontSize: 12, color: DSColors.textStrong, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ))
          else
            Text(_fmt(lista), style: const TextStyle(fontSize: 12, color: DSColors.textStrong)),
        ],
      ),
    );
  }
}
