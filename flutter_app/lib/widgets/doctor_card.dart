import 'package:flutter/material.dart';
import '../design_system.dart';
import '../models/models.dart';

/// Bento card de médico — Design System 2.0.
/// Avatar en gradiente de marca, jerarquía nombre/especialidad, precio
/// como píldora de tinta alineada a la derecha para escaneo instantáneo.
class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;

  const DoctorCard({super.key, required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iniciales = doctor.nombre.length >= 2
        ? doctor.nombre.substring(0, 2)
        : doctor.nombre;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s2, vertical: 6),
      child: DSCard(
        onTap: onTap,
        padding: const EdgeInsets.all(DS.s2),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [DSColors.brand, Color(0xFF7C74F2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: DSElevation.glow(DSColors.brand),
                  ),
                  child: Center(
                    child: Text(
                      iniciales.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                // Punto de disponibilidad: refuerzo de "ahorra tiempo"
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: DSColors.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: DS.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.nombre, style: DSText.headline),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: DSColors.brandSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doctor.especialidad,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: DSColors.brand,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(doctor.calificacion.toStringAsFixed(1),
                          style: DSText.label),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: DSColors.ink,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '\$${doctor.tarifa.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
