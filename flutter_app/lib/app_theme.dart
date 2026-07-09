import 'package:flutter/material.dart';

class AppColors {
  // ── Paleta de confianza (marca) ─────────────────────────────────────────
  static const primary = Color(0xFF0B2545);      // azul profundo: autoridad
  static const primaryLight = Color(0xFF1557B0);
  static const accent = Color(0xFF00C896);
  static const accentDark = Color(0xFF00A87E);
  // Fondo azul-grisáceo muy claro: limpieza clínica, menos fatiga visual
  static const background = Color(0xFFF6F8FB);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0B2545);
  static const textSecondary = Color(0xFF5B6B7F);
  static const textHint = Color(0xFF94A3B8);
  static const error = Color(0xFFE53E3E);
  static const warning = Color(0xFFED8936);
  static const success = Color(0xFF38A169);
  static const cardBorder = Color(0xFFE8EDF4);

  // ── Acento de emergencia: cinabrio oscuro — urgencia profesional, no alarmista
  static const alert = Color(0xFFD9453A);
  static const alertDark = Color(0xFFB23429);

  // ── Semáforo semántico (HRA / estados clínicos) — distinto de la marca ──
  static const semGreen = Color(0xFF3BA55D);   // salud / seguro
  static const semYellow = Color(0xFFF2B01E);  // precaución / revisión
  static const semRed = Color(0xFFE8590C);     // atención necesaria
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryLight,
          primary: AppColors.primaryLight,
          background: AppColors.background,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        fontFamily: 'Roboto',
        // Legibilidad clínica: interlineado amplio y jerarquía por peso
        textTheme: const TextTheme(
          bodyLarge: TextStyle(height: 1.5, color: AppColors.textPrimary),
          bodyMedium: TextStyle(height: 1.5, color: AppColors.textPrimary),
          bodySmall: TextStyle(height: 1.45, color: AppColors.textSecondary),
          titleLarge: TextStyle(
              fontWeight: FontWeight.w800, letterSpacing: -0.3,
              color: AppColors.textPrimary),
          titleMedium: TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          labelLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textHint),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            side: const BorderSide(color: AppColors.primaryLight),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.background,
          selectedColor: AppColors.primaryLight.withOpacity(0.15),
          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          side: const BorderSide(color: AppColors.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      );

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static BoxDecoration get gradientBox => BoxDecoration(gradient: primaryGradient);

  static BoxDecoration avatarGradient(Color c1, Color c2) => BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      );

  // Sombra suave estilo Fluent: las tarjetas "flotan" sobre el fondo
  static BoxShadow get cardShadow => BoxShadow(
        color: AppColors.primary.withOpacity(0.06),
        blurRadius: 20,
        offset: const Offset(0, 6),
      );

  // Elevación mayor para elementos destacados (FAB, paneles principales)
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.10),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: AppColors.primary.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}

// Shared status chip widget
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// Gradient avatar widget
class GradientAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  final List<Color>? colors;

  const GradientAvatar({
    super.key,
    required this.initials,
    this.radius = 28,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = colors ??
        [AppColors.primaryLight, const Color(0xFF0B4F8A)];
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.6,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
