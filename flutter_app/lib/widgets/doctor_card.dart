import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/models.dart';

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;

  const DoctorCard({super.key, required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border(left: BorderSide(color: AppColors.primaryLight, width: 3)),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GradientAvatar(
                initials: doctor.nombre.length >= 2
                    ? doctor.nombre.substring(0, 2)
                    : doctor.nombre,
                radius: 28,
              ),
              const SizedBox(width: 14),
              // Nombre y especialidad (jerarquía por peso tipográfico)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.medical_services_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            doctor.especialidad,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Calificación y precio alineados a la derecha: escaneo rápido
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 15, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        doctor.calificacion.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      '\$${doctor.tarifa.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.accentDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
}
