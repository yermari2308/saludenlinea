import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../design_system.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Perfil del médico — Design System 2.0. Identidad en tinta, métricas
/// tabulares y agendado en dos pasos con confirmación.
class DoctorDetailScreen extends StatelessWidget {
  final Doctor doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final iniciales = doctor.nombre.length >= 2
        ? doctor.nombre.substring(0, 2).toUpperCase()
        : doctor.nombre.toUpperCase();

    return Scaffold(
      backgroundColor: DSColors.ink,
      body: Column(
        children: [
          // ── Identidad en tinta ──────────────────────────────────────────
          Container(
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
                padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s3, DS.s4),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DSPressable(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: DS.s2),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [DSColors.mint, Color(0xFF059669)]),
                        shape: BoxShape.circle,
                        boxShadow: DSElevation.glow(DSColors.mint),
                      ),
                      child: Center(
                        child: Text(iniciales,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: DS.s2),
                    Text(
                      'Dr. ${doctor.nombre}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: DSColors.mint.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(doctor.especialidad,
                          style: const TextStyle(
                              color: DSColors.mint, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Contenido ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: DSColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DS.s3, DS.s3, DS.s3, DS.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Metrica(
                            icon: Icons.payments_rounded,
                            etiqueta: 'Tarifa por consulta',
                            valor: '\$${doctor.tarifa.toStringAsFixed(0)}',
                            color: DSColors.brand,
                          ),
                        ),
                        const SizedBox(width: DS.s2),
                        Expanded(
                          child: _Metrica(
                            icon: Icons.star_rounded,
                            etiqueta: 'Calificación',
                            valor: doctor.calificacion.toStringAsFixed(1),
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DS.s4),
                    const DSSectionHeader(title: 'Credenciales'),
                    DSCard(
                      padding: const EdgeInsets.all(DS.s2 + 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: DSColors.brandSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.badge_rounded, color: DSColors.brand, size: 18),
                          ),
                          const SizedBox(width: DS.s2),
                          Expanded(
                            child: Text(
                              doctor.credenciales.isEmpty
                                  ? 'Este profesional aún no cargó sus credenciales.'
                                  : doctor.credenciales,
                              style: const TextStyle(
                                  color: DSColors.textMid, fontSize: 14, height: 1.55, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DS.s4),
                    DSButton(
                      label: 'Agendar consulta',
                      icon: Icons.calendar_month_rounded,
                      onTap: () => _agendar(context),
                    ),
                    const SizedBox(height: DS.s2),
                    Container(
                      padding: const EdgeInsets.all(DS.s2),
                      decoration: BoxDecoration(
                        color: DSColors.brandSoft,
                        borderRadius: DSRadius.rSm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: DSColors.brand, size: 18),
                          const SizedBox(width: DS.s1 + 2),
                          Expanded(
                            child: Text(
                              'Vas a pagar \$${doctor.tarifa.toStringAsFixed(0)} USD antes de entrar '
                              'a la consulta. Podés pagar con tarjeta o SINPE Móvil.',
                              style: const TextStyle(
                                  color: DSColors.textMid, fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Flujo de agendado ──────────────────────────────────────────────────
  Future<void> _agendar(BuildContext context) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: DSColors.brand,
            onPrimary: Colors.white,
            surface: DSColors.surface,
            onSurface: DSColors.textStrong,
          ),
        ),
        child: child!,
      ),
    );
    if (fecha == null || !context.mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: DSColors.brand,
            onPrimary: Colors.white,
            surface: DSColors.surface,
            onSurface: DSColors.textStrong,
          ),
        ),
        child: child!,
      ),
    );
    if (hora == null || !context.mounted) return;

    final fechaHora = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: DSColors.surface,
        shape: RoundedRectangleBorder(borderRadius: DSRadius.rMd),
        title: const Text('Confirmar cita', style: DSText.headline),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilaConfirmacion(etiqueta: 'Médico', valor: 'Dr. ${doctor.nombre}'),
            const SizedBox(height: DS.s1 + 2),
            _FilaConfirmacion(
                etiqueta: 'Fecha',
                valor: DateFormat("dd/MM/yyyy 'a las' HH:mm").format(fechaHora)),
            const SizedBox(height: DS.s1 + 2),
            _FilaConfirmacion(
                etiqueta: 'Costo', valor: '\$${doctor.tarifa.toStringAsFixed(2)} USD'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: DSColors.textMid, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar',
                style: TextStyle(color: DSColors.brand, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await ApiService.createAppointment(doctorId: doctor.id, fechaHora: fechaHora);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('¡Cita agendada! Pagala desde "Mis citas".')),
        ]),
        backgroundColor: DSColors.mint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: DSColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

/// Métrica del perfil con número tabular.
class _Metrica extends StatelessWidget {
  final IconData icon;
  final String etiqueta;
  final String valor;
  final Color color;

  const _Metrica({
    required this.icon,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => DSCard(
        padding: const EdgeInsets.all(DS.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: DS.s1 + 2),
            Text(valor, style: DSText.mono.copyWith(fontSize: 24, color: color)),
            const SizedBox(height: 2),
            Text(etiqueta,
                style: const TextStyle(
                    fontSize: 11, color: DSColors.textFaint, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Fila etiqueta/valor del diálogo de confirmación.
class _FilaConfirmacion extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _FilaConfirmacion({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(etiqueta,
                style: const TextStyle(
                    color: DSColors.textFaint, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    color: DSColors.textStrong, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      );
}
