import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'consultation_screen.dart';
import 'chat_screen.dart';
import 'payment_screen.dart';
import 'legal_screen.dart';
import 'hra_screen.dart';
import 'medical_record_screen.dart';
import 'pharmacy_screen.dart';

/// Mis citas — Design System 2.0.
/// Activity Timeline real: riel de tinta con punto luminoso por estado,
/// tarjetas que se expanden con física suave, empty state con próximos pasos.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Appointment> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getAppointments();
      setState(() => _appointments = list..sort((a, b) => b.fechaHora.compareTo(a.fechaHora)));
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: DSColors.coral,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'programada': return DSColors.brand;
      case 'completada': return DSColors.mint;
      case 'cancelada': return DSColors.coral;
      default: return DSColors.textFaint;
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'programada': return 'PROGRAMADA';
      case 'completada': return 'COMPLETADA';
      case 'cancelada': return 'CANCELADA';
      default: return estado.toUpperCase();
    }
  }

  Future<void> _entrarConsulta(Appointment apt) async {
    final prefs = await ApiService.getUserInfo();
    final esDoctor = (prefs['role'] ?? '') == 'doctor';

    if (!esDoctor) {
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
        final info = await ApiService.getAppointmentPago(apt.id);
        if (!mounted) return;
        if (info['requiere_pago'] == true) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentScreen(
                appointmentId: apt.id,
                doctorNombre: info['doctor_nombre'] as String? ?? 'Médico',
                monto: (info['monto'] as num?)?.toDouble() ?? 0,
              ),
            ),
          );
          _load();
          return;
        }
      } catch (e) {
        if (!mounted) return;
        _showError(e.toString());
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => ConsultationScreen(appointmentId: apt.id)));
  }

  Future<void> _ocultarCita(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DSRadius.rMd),
        title: const Text('Eliminar del historial', style: DSText.headline),
        content: const Text(
          'La cita dejará de aparecer en tu lista. Tus recetas y datos médicos '
          'se conservan de forma segura y el médico mantiene su registro.',
          style: DSText.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: DSColors.coral,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.ocultarCita(id);
      _load();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  Future<void> _abrirChat(int citaId) async {
    final prefs = await ApiService.getUserInfo();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        citaId: citaId,
        remitente: prefs['role'] ?? 'paciente',
        remitenteId: prefs['id'] ?? 0,
        nombreOtro: prefs['role'] == 'doctor' ? 'Paciente' : 'Médico',
      ),
    ));
  }

  Future<void> _reagendar(int citaId) async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: ahora.add(const Duration(days: 1)),
      firstDate: ahora.add(const Duration(hours: 1)),
      lastDate: ahora.add(const Duration(days: 90)),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (hora == null || !mounted) return;
    final nueva = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    try {
      await ApiService.reagendarCita(citaId, nueva);
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Cita reagendada correctamente'),
        backgroundColor: DSColors.mint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  Future<void> _descargarReceta(int citaId, String nombre) async {
    try {
      final bytes = await ApiService.descargarRecetaArchivo(citaId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  Future<void> _cancelar(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: DSRadius.rMd),
        title: const Text('Cancelar cita', style: DSText.headline),
        content: const Text('¿Estás seguro de que deseas cancelar esta cita?', style: DSText.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, volver')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: DSColors.coral,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.cancelAppointment(id);
      _load();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
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
                  const Expanded(child: Text('Mis citas', style: DSText.title)),
                  DSPressable(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DSColors.surface, shape: BoxShape.circle,
                        boxShadow: DSElevation.rest,
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 19, color: DSColors.textMid),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? ListView(children: const [
                      SkeletonCard(), SkeletonCard(), SkeletonCard(),
                    ])
                  : _appointments.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: DSColors.brand,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(DS.s2, 0, DS.s2, 120),
                            itemCount: _appointments.length,
                            itemBuilder: (_, i) => _TimelineEntry(
                              color: _estadoColor(_appointments[i].estado),
                              isFirst: i == 0,
                              isLast: i == _appointments.length - 1,
                              child: _AppointmentCard(
                                apt: _appointments[i],
                                estadoColor: _estadoColor(_appointments[i].estado),
                                estadoLabel: _estadoLabel(_appointments[i].estado),
                                onEntrarConsulta: _appointments[i].estado == 'programada'
                                    ? () => _entrarConsulta(_appointments[i]) : null,
                                onChat: _appointments[i].estado == 'programada'
                                    ? () => _abrirChat(_appointments[i].id) : null,
                                onReagendar: _appointments[i].estado == 'programada'
                                    ? () => _reagendar(_appointments[i].id) : null,
                                onCancelar: _appointments[i].estado == 'programada'
                                    ? () => _cancelar(_appointments[i].id) : null,
                                onDescargarReceta: _appointments[i].recetaArchivoNombre.isNotEmpty
                                    ? () => _descargarReceta(_appointments[i].id, _appointments[i].recetaArchivoNombre)
                                    : null,
                                onOcultar: _appointments[i].estado != 'programada'
                                    ? () => _ocultarCita(_appointments[i].id) : null,
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, 120),
        child: Column(
          children: [
            const SizedBox(height: 12),
            SizedBox(
              width: 120, height: 120,
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 120, height: 120,
                    decoration: const BoxDecoration(color: DSColors.brandSoft, shape: BoxShape.circle)),
                Container(width: 78, height: 78,
                    decoration: BoxDecoration(color: DSColors.brand.withOpacity(0.12), shape: BoxShape.circle)),
                const Icon(Icons.calendar_month_rounded, size: 38, color: DSColors.brand),
              ]),
            ),
            const SizedBox(height: DS.s3),
            const Text('Sin citas todavía', style: DSText.title),
            const SizedBox(height: 6),
            const Text('Buscá un médico y agendá tu primera consulta',
                style: DSText.body, textAlign: TextAlign.center),
            const SizedBox(height: DS.s4),
            const Align(alignment: Alignment.centerLeft, child: DSSectionHeader(title: 'Próximos pasos')),
            _SugerenciaCard(
              icon: Icons.monitor_heart_rounded,
              color: DSColors.mint,
              titulo: 'Hacé tu evaluación de salud',
              subtitulo: '6 preguntas y recibís tu semáforo de salud (HRA)',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HraScreen())),
            ),
            const SizedBox(height: DS.s1),
            _SugerenciaCard(
              icon: Icons.folder_shared_rounded,
              color: DSColors.brand,
              titulo: 'Completá tu expediente clínico',
              subtitulo: 'Ayuda al médico a darte un mejor diagnóstico',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalRecordScreen())),
            ),
            const SizedBox(height: DS.s1),
            _SugerenciaCard(
              icon: Icons.local_pharmacy_rounded,
              color: const Color(0xFF8B5CF6),
              titulo: '¿Necesitás medicamentos?',
              subtitulo: 'Pedilos en la farmacia con entrega a domicilio',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyScreen())),
            ),
          ],
        ),
      );
}

class _AppointmentCard extends StatefulWidget {
  final Appointment apt;
  final Color estadoColor;
  final String estadoLabel;
  final VoidCallback? onEntrarConsulta;
  final VoidCallback? onChat;
  final VoidCallback? onReagendar;
  final VoidCallback? onCancelar;
  final VoidCallback? onDescargarReceta;
  final VoidCallback? onOcultar;

  const _AppointmentCard({
    required this.apt,
    required this.estadoColor,
    required this.estadoLabel,
    this.onEntrarConsulta,
    this.onChat,
    this.onReagendar,
    this.onCancelar,
    this.onDescargarReceta,
    this.onOcultar,
  });

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _expanded = false;

  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  String _fmt(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')} ${_meses[f.month - 1]} · ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final apt = widget.apt;
    final isProgramada = apt.estado == 'programada';
    final isCompletada = apt.estado == 'completada';

    return Container(
      margin: const EdgeInsets.only(bottom: DS.s2),
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.rMd,
        boxShadow: DSElevation.rest,
      ),
      child: Column(
        children: [
          DSPressable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(DS.s2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DSChip(label: widget.estadoLabel, color: widget.estadoColor),
                        const SizedBox(height: 6),
                        Text(_fmt(apt.fechaHora), style: DSText.headline),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: DSColors.textFaint, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(DS.s2, 0, DS.s2, DS.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: DSColors.line, height: 1),
                  const SizedBox(height: DS.s2),
                  if (apt.notas.isNotEmpty) ...[
                    _InfoRow(icon: Icons.notes_rounded, label: 'Notas del médico', value: apt.notas),
                    const SizedBox(height: DS.s1),
                  ],
                  if (apt.receta.isNotEmpty) ...[
                    _InfoRow(icon: Icons.medication_rounded, label: 'Receta', value: apt.receta, valueColor: DSColors.mint),
                    const SizedBox(height: DS.s1),
                  ],
                  if (isCompletada) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: DSColors.mintSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(children: [
                        Icon(Icons.check_rounded, color: DSColors.mint, size: 16),
                        SizedBox(width: 8),
                        Text('Consulta finalizada', style: TextStyle(color: DSColors.mint, fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                    if (widget.onDescargarReceta != null) ...[
                      const SizedBox(height: DS.s1),
                      DSButton(label: 'Descargar receta', icon: Icons.download_rounded,
                          color: DSColors.ink, onTap: widget.onDescargarReceta),
                    ],
                  ],
                  if (widget.onOcultar != null) ...[
                    const SizedBox(height: DS.s1),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: DSColors.textFaint),
                        label: const Text('Eliminar del historial', style: TextStyle(fontSize: 12, color: DSColors.textFaint)),
                        onPressed: widget.onOcultar,
                      ),
                    ),
                  ],
                  if (isProgramada) ...[
                    const SizedBox(height: 4),
                    DSButton(label: 'Entrar a la consulta', icon: Icons.video_call_rounded,
                        color: DSColors.mint, onTap: widget.onEntrarConsulta),
                    const SizedBox(height: DS.s1),
                    Row(
                      children: [
                        Expanded(child: _OutlineAction(icon: Icons.chat_bubble_outline_rounded, label: 'Chat', color: DSColors.brand, onTap: widget.onChat)),
                        const SizedBox(width: 8),
                        Expanded(child: _OutlineAction(icon: Icons.edit_calendar_rounded, label: 'Cambiar', color: const Color(0xFFF59E0B), onTap: widget.onReagendar)),
                        const SizedBox(width: 8),
                        Expanded(child: _OutlineAction(icon: Icons.cancel_outlined, label: 'Cancelar', color: DSColors.coral, onTap: widget.onCancelar)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

/// Activity Timeline: riel de tinta con nodo luminoso por estado.
class _TimelineEntry extends StatelessWidget {
  final Color color;
  final bool isFirst;
  final bool isLast;
  final Widget child;

  const _TimelineEntry({required this.color, required this.isFirst, required this.isLast, required this.child});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 2, height: 26, color: isFirst ? Colors.transparent : DSColors.line),
                Container(
                  width: 13, height: 13,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)],
                  ),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : DSColors.line)),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SugerenciaCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _SugerenciaCard({required this.icon, required this.color, required this.titulo, required this.subtitulo, required this.onTap});

  @override
  Widget build(BuildContext context) => DSCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: DS.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: DSText.headline),
                  const SizedBox(height: 2),
                  Text(subtitulo, style: DSText.label),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DSColors.textFaint),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: DSColors.textMid),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: DSText.label),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13.5, color: valueColor ?? DSColors.textStrong)),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _OutlineAction({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return DSPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
