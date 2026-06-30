import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'consultation_screen.dart';
import 'chat_screen.dart';

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
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'programada': return AppColors.primaryLight;
      case 'completada': return AppColors.success;
      case 'cancelada': return AppColors.error;
      default: return AppColors.textSecondary;
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
        backgroundColor: AppColors.success,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar cita',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: const Text('¿Estás seguro de que deseas cancelar esta cita?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Citas'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : _appointments.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: AppColors.primaryLight,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _appointments.length,
                    itemBuilder: (_, i) => _AppointmentCard(
                      apt: _appointments[i],
                      estadoColor: _estadoColor(_appointments[i].estado),
                      estadoLabel: _estadoLabel(_appointments[i].estado),
                      onEntrarConsulta: _appointments[i].estado == 'programada'
                          ? () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ConsultationScreen(
                                  appointmentId: _appointments[i].id)))
                          : null,
                      onChat: _appointments[i].estado == 'programada'
                          ? () => _abrirChat(_appointments[i].id)
                          : null,
                      onReagendar: _appointments[i].estado == 'programada'
                          ? () => _reagendar(_appointments[i].id)
                          : null,
                      onCancelar: _appointments[i].estado == 'programada'
                          ? () => _cancelar(_appointments[i].id)
                          : null,
                      onDescargarReceta: _appointments[i].recetaArchivoNombre.isNotEmpty
                          ? () => _descargarReceta(
                              _appointments[i].id, _appointments[i].recetaArchivoNombre)
                          : null,
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  size: 52, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            const Text('No tienes citas aún',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Busca un médico y agenda tu primera consulta',
                style: TextStyle(color: AppColors.textSecondary)),
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

  const _AppointmentCard({
    required this.apt,
    required this.estadoColor,
    required this.estadoLabel,
    this.onEntrarConsulta,
    this.onChat,
    this.onReagendar,
    this.onCancelar,
    this.onDescargarReceta,
  });

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final apt = widget.apt;
    final isProgramada = apt.estado == 'programada';
    final isCompletada = apt.estado == 'completada';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: widget.estadoColor, width: 4)),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cita #${apt.id}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 13, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd MMM yyyy  HH:mm').format(apt.fechaHora),
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      StatusChip(label: widget.estadoLabel, color: widget.estadoColor),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.cardBorder, height: 1),
                  const SizedBox(height: 12),
                  if (apt.notas.isNotEmpty) ...[
                    _InfoRow(icon: Icons.notes_rounded, label: 'Notas del médico', value: apt.notas),
                    const SizedBox(height: 8),
                  ],
                  if (apt.receta.isNotEmpty) ...[
                    _InfoRow(icon: Icons.medication_rounded, label: 'Receta', value: apt.receta,
                        valueColor: AppColors.accentDark),
                    const SizedBox(height: 8),
                  ],
                  // Estado completada
                  if (isCompletada) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 16),
                          SizedBox(width: 8),
                          Text('Consulta finalizada',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    if (widget.onDescargarReceta != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                          label: const Text('Descargar receta',
                              style: TextStyle(color: Colors.white, fontSize: 13)),
                          onPressed: widget.onDescargarReceta,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                  // Acciones programada
                  if (isProgramada) ...[
                    const SizedBox(height: 4),
                    // Entrar a consulta
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.video_call_rounded, size: 18, color: Colors.white),
                        label: const Text('Entrar a la consulta',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        onPressed: widget.onEntrarConsulta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _OutlineAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Chat',
                            color: AppColors.primaryLight,
                            onTap: widget.onChat,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _OutlineAction(
                            icon: Icons.edit_calendar_rounded,
                            label: 'Cambiar fecha',
                            color: AppColors.warning,
                            onTap: widget.onReagendar,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _OutlineAction(
                            icon: Icons.cancel_outlined,
                            label: 'Cancelar',
                            color: AppColors.error,
                            onTap: widget.onCancelar,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
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
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13, color: valueColor ?? AppColors.textPrimary)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
