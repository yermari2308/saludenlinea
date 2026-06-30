import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'programada': return Colors.blue;
      case 'completada': return Colors.green;
      case 'cancelada': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Citas'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No tienes citas aún',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Busca un médico y agenda tu primera consulta',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    itemBuilder: (_, i) {
                      final apt = _appointments[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Cita #${apt.id}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _estadoColor(apt.estado).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      apt.estado.toUpperCase(),
                                      style: TextStyle(
                                          color: _estadoColor(apt.estado),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(apt.fechaHora),
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              if (apt.notas.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Divider(),
                                const Text('Notas del médico:',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                Text(apt.notas, style: const TextStyle(fontSize: 13)),
                              ],
                              if (apt.receta.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                const Text('Receta:',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                Text(apt.receta,
                                    style: const TextStyle(fontSize: 13, color: Colors.green)),
                              ],
                              if (apt.estado == 'programada') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.video_call, color: Colors.white),
                                    label: const Text('Entrar a la consulta',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ConsultationScreen(appointmentId: apt.id),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2ecc71),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF1976D2)),
                                    label: const Text('Chat con el médico',
                                        style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
                                    onPressed: () => _abrirChat(apt.id),
                                    style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF1976D2)),
                                        padding: const EdgeInsets.symmetric(vertical: 12)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_calendar, color: Color(0xFF795548)),
                                    label: const Text('Cambiar fecha',
                                        style: TextStyle(color: Color(0xFF795548))),
                                    onPressed: () => _reagendar(apt.id),
                                    style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF795548)),
                                        padding: const EdgeInsets.symmetric(vertical: 12)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                    label: const Text('Cancelar cita',
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () => _cancelar(apt.id),
                                    style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.red)),
                                  ),
                                ),
                              ],
                              if (apt.estado == 'completada') ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                                      SizedBox(width: 8),
                                      Text('Consulta finalizada',
                                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                if (apt.recetaArchivoNombre.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.download, color: Colors.white),
                                      label: Text('Descargar receta (${apt.recetaArchivoNombre})',
                                          style: const TextStyle(color: Colors.white)),
                                      onPressed: () => _descargarReceta(apt.id, apt.recetaArchivoNombre),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1a3a5c),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _abrirChat(int citaId) async {
    final prefs = await ApiService.getUserInfo();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          citaId: citaId,
          remitente: prefs['role'] ?? 'paciente',
          remitenteId: prefs['id'] ?? 0,
          nombreOtro: prefs['role'] == 'doctor' ? 'Paciente' : 'Médico',
        ),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita reagendada correctamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancelar(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text('¿Estás seguro de que deseas cancelar esta cita?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.cancelAppointment(id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
