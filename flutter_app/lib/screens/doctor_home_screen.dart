import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
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

  static const _azul = Color(0xFF1a3a5c);
  static const _verde = Color(0xFF2ecc71);

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
        title: const Text('Finalizar consulta'),
        content: const Text('¿Confirmas que la consulta ha terminado? El paciente no podrá reingresar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Sí, finalizar', style: TextStyle(color: Colors.white)),
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
        const SnackBar(content: Text('Consulta finalizada'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
        const SnackBar(content: Text('Receta subida correctamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'programada': return Colors.orange;
      case 'completada': return _verde;
      case 'cancelada':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'programada': return Icons.schedule;
      case 'completada': return Icons.check_circle;
      case 'cancelada':  return Icons.cancel;
      default:           return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Panel Médico',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_nombreDoctor.isNotEmpty)
              Text('Dr. $_nombreDoctor',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _cargarDatos()),
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: FutureBuilder<List<Appointment>>(
        future: _citasFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error: ${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _cargarDatos()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final citas = snap.data ?? [];
          final hoy = DateTime.now();
          final citasHoy = citas.where((c) =>
              c.fechaHora.year == hoy.year &&
              c.fechaHora.month == hoy.month &&
              c.fechaHora.day == hoy.day).toList();
          final programadas = citas.where((c) => c.estado == 'programada').length;
          final completadas = citas.where((c) => c.estado == 'completada').length;

          return RefreshIndicator(
            onRefresh: () async => setState(() => _cargarDatos()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Tarjetas de estadísticas
                Row(
                  children: [
                    _StatCard(label: 'Hoy', value: citasHoy.length.toString(),
                        icon: Icons.today, color: _azul),
                    const SizedBox(width: 12),
                    _StatCard(label: 'Pendientes', value: programadas.toString(),
                        icon: Icons.schedule, color: Colors.orange),
                    const SizedBox(width: 12),
                    _StatCard(label: 'Completadas', value: completadas.toString(),
                        icon: Icons.check_circle, color: _verde),
                  ],
                ),
                const SizedBox(height: 20),

                // Citas de hoy
                if (citasHoy.isNotEmpty) ...[
                  _SectionTitle(title: 'Citas de hoy (${citasHoy.length})'),
                  const SizedBox(height: 8),
                  ...citasHoy.map((c) => _CitaCard(
                    cita: c,
                    estadoColor: _estadoColor(c.estado),
                    estadoIcon: _estadoIcon(c.estado),
                    onEntrar: c.estado == 'programada' ? () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ConsultationScreen(appointmentId: c.id))) : null,
                    onFinalizar: c.estado == 'programada' ? () => _finalizar(c.id) : null,
                    onChat: c.estado == 'programada' ? () => _abrirChat(c.id) : null,
                    onSubirReceta: () => _subirReceta(c.id),
                  )),
                  const SizedBox(height: 20),
                ],

                // Todas las citas
                _SectionTitle(
                    title: citas.isEmpty ? 'Sin citas registradas' : 'Todas las citas'),
                const SizedBox(height: 8),
                if (citas.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_month_outlined,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No tienes citas aún',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ...citas.map((c) => _CitaCard(
                    cita: c,
                    estadoColor: _estadoColor(c.estado),
                    estadoIcon: _estadoIcon(c.estado),
                    onEntrar: c.estado == 'programada'
                        ? () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ConsultationScreen(appointmentId: c.id)))
                        : null,
                    onFinalizar: c.estado == 'programada' ? () => _finalizar(c.id) : null,
                    onChat: c.estado == 'programada' ? () => _abrirChat(c.id) : null,
                    onSubirReceta: () => _subirReceta(c.id),
                  )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1a3a5c)));
  }
}

class _CitaCard extends StatelessWidget {
  final Appointment cita;
  final Color estadoColor;
  final IconData estadoIcon;
  final VoidCallback? onEntrar;
  final VoidCallback? onFinalizar;
  final VoidCallback? onChat;
  final VoidCallback? onSubirReceta;

  const _CitaCard({
    required this.cita,
    required this.estadoColor,
    required this.estadoIcon,
    this.onEntrar,
    this.onFinalizar,
    this.onChat,
    this.onSubirReceta,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = cita.fechaHora;
    final fechaStr =
        '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: estadoColor.withOpacity(.15),
                  child: Icon(estadoIcon, color: estadoColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paciente #${cita.pacienteId}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(fechaStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: estadoColor.withOpacity(.12),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(cita.estado.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold, color: estadoColor)),
                      ),
                    ],
                  ),
                ),
                if (onEntrar != null)
                  ElevatedButton(
                    onPressed: onEntrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a3a5c),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Entrar', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            if (cita.estado == 'programada') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onChat != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Chat', style: TextStyle(fontSize: 12)),
                        onPressed: onChat,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1976D2),
                          side: const BorderSide(color: Color(0xFF1976D2)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  if (onChat != null && onSubirReceta != null) const SizedBox(width: 8),
                  if (onSubirReceta != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Receta', style: TextStyle(fontSize: 12)),
                        onPressed: onSubirReceta,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2ecc71),
                          side: const BorderSide(color: Color(0xFF2ecc71)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  if (onFinalizar != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                        label: const Text('Finalizar', style: TextStyle(fontSize: 12, color: Colors.white)),
                        onPressed: onFinalizar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (cita.estado == 'completada' && cita.recetaArchivoNombre.isEmpty && onSubirReceta != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Subir receta PDF', style: TextStyle(fontSize: 13)),
                  onPressed: onSubirReceta,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1a3a5c),
                    side: const BorderSide(color: Color(0xFF1a3a5c)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
