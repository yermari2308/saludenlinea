import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'consultation_screen.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  late Future<List<Appointment>> _citasFuture;
  String _nombreDoctor = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() {
    _citasFuture = ApiService.getAppointments();
    ApiService.getUserInfo().then((info) {
      if (mounted) setState(() => _nombreDoctor = info['nombre'] ?? 'Doctor');
    });
  }

  Future<void> _finalizar(int citaId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Finalizar consulta',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: const Text(
            '¿Confirmas que la consulta ha terminado? El paciente no podrá reingresar.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sí, finalizar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.finalizarCita(citaId);
      setState(() => _cargarDatos());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Consulta finalizada'),
          ]),
          backgroundColor: AppColors.accentDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  Future<void> _abrirChat(int citaId) async {
    final info = await ApiService.getUserInfo();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          citaId: citaId,
          remitente: 'doctor',
          remitenteId: info['id'] ?? 0,
          nombreOtro: 'Paciente',
        ),
      ),
    );
  }

  Future<void> _subirReceta(int citaId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;
    try {
      await ApiService.subirRecetaArchivo(citaId, bytes, picked.name);
      setState(() => _cargarDatos());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Receta subida correctamente'),
          ]),
          backgroundColor: AppColors.accentDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<Appointment>>(
        future: _citasFuture,
        builder: (context, snap) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(snap),
              if (snap.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLight),
                  ),
                )
              else if (snap.hasError)
                SliverFillRemaining(child: _buildError(snap.error))
              else
                _buildContent(snap.data ?? []),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(AsyncSnapshot snap) {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 22),
          onPressed: () => setState(() => _cargarDatos()),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 22),
          onPressed: _logout,
        ),
      ],
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Panel Médico',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          )),
                      const SizedBox(height: 3),
                      Text(
                        _nombreDoctor.isNotEmpty ? 'Dr. $_nombreDoctor' : 'Bienvenido',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.65), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<Appointment> citas) {
    final hoy = DateTime.now();
    final citasHoy = citas
        .where((c) =>
            c.fechaHora.year == hoy.year &&
            c.fechaHora.month == hoy.month &&
            c.fechaHora.day == hoy.day)
        .toList();
    final programadas = citas.where((c) => c.estado == 'programada').length;
    final completadas = citas.where((c) => c.estado == 'completada').length;

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _StatCard(
                  label: 'Hoy',
                  value: citasHoy.length.toString(),
                  icon: Icons.today_rounded,
                  color: AppColors.primaryLight),
              const SizedBox(width: 10),
              _StatCard(
                  label: 'Pendientes',
                  value: programadas.toString(),
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              _StatCard(
                  label: 'Completadas',
                  value: completadas.toString(),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.accentDark),
            ],
          ),
        ),
        if (citasHoy.isNotEmpty) ...[
          const _SectionTitle(title: 'Citas de hoy', top: true),
          ...citasHoy.map((c) => _CitaCard(
                cita: c,
                onEntrar: c.estado == 'programada'
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ConsultationScreen(appointmentId: c.id)))
                    : null,
                onFinalizar: c.estado == 'programada' ? () => _finalizar(c.id) : null,
                onChat: c.estado == 'programada' ? () => _abrirChat(c.id) : null,
                onSubirReceta: () => _subirReceta(c.id),
              )),
        ],
        _SectionTitle(
            title: citas.isEmpty ? 'Sin citas registradas' : 'Todas las citas',
            top: citasHoy.isEmpty),
        if (citas.isEmpty)
          _buildEmpty()
        else
          ...citas.map((c) => _CitaCard(
                cita: c,
                onEntrar: c.estado == 'programada'
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ConsultationScreen(appointmentId: c.id)))
                    : null,
                onFinalizar: c.estado == 'programada' ? () => _finalizar(c.id) : null,
                onChat: c.estado == 'programada' ? () => _abrirChat(c.id) : null,
                onSubirReceta: () => _subirReceta(c.id),
              )),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_outlined,
                  size: 48, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            const Text('No tienes citas aún',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Las citas de pacientes aparecerán aquí',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );

  Widget _buildError(Object? error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              Text(error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() => _cargarDatos()),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight),
                child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool top;

  const _SectionTitle({required this.title, this.top = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top ? 20 : 24, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CitaCard extends StatelessWidget {
  final Appointment cita;
  final VoidCallback? onEntrar;
  final VoidCallback? onFinalizar;
  final VoidCallback? onChat;
  final VoidCallback? onSubirReceta;

  const _CitaCard({
    required this.cita,
    this.onEntrar,
    this.onFinalizar,
    this.onChat,
    this.onSubirReceta,
  });

  Color get _color {
    switch (cita.estado) {
      case 'programada': return const Color(0xFFF59E0B);
      case 'completada': return AppColors.accentDark;
      case 'cancelada': return AppColors.error;
      default: return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = cita.fechaHora;
    final fechaStr =
        '${f.day}/${f.month}/${f.year}  ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: _color, width: 3)),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_estadoIcon, color: _color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paciente #${cita.pacienteId}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(fechaStr,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                StatusChip(label: cita.estado, color: _color),
                if (onEntrar != null) ...[
                  const SizedBox(width: 8),
                  _EntrarBtn(onTap: onEntrar!),
                ],
              ],
            ),
            if (cita.estado == 'programada') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onChat != null)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        color: AppColors.primaryLight,
                        onTap: onChat!,
                      ),
                    ),
                  if (onChat != null && onSubirReceta != null)
                    const SizedBox(width: 8),
                  if (onSubirReceta != null)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.upload_file_rounded,
                        label: 'Receta',
                        color: AppColors.accentDark,
                        onTap: onSubirReceta!,
                      ),
                    ),
                  if (onFinalizar != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.check_circle_rounded,
                        label: 'Finalizar',
                        color: const Color(0xFFF59E0B),
                        onTap: onFinalizar!,
                        filled: true,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (cita.estado == 'completada' &&
                cita.recetaArchivoNombre.isEmpty &&
                onSubirReceta != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _ActionBtn(
                  icon: Icons.upload_file_rounded,
                  label: 'Subir receta PDF',
                  color: AppColors.primaryLight,
                  onTap: onSubirReceta!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _estadoIcon {
    switch (cita.estado) {
      case 'programada': return Icons.schedule_rounded;
      case 'completada': return Icons.check_circle_rounded;
      case 'cancelada': return Icons.cancel_rounded;
      default: return Icons.help_outline_rounded;
    }
  }
}

class _EntrarBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EntrarBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Entrar',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
