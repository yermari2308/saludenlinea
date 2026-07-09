import 'package:flutter/material.dart';

class AppColors {
  // ── Identidad médica premium ────────────────────────────────────────────
  // Azul petróleo: profundidad y confianza (evita el azul hospital típico)
  static const primary = Color(0xFF0D3B4F);
  // Azul eléctrico: tecnología y rapidez
  static const primaryLight = Color(0xFF2563EB);
  // Turquesa: medicina moderna
  static const accent = Color(0xFF14B8A6);
  static const accentDark = Color(0xFF0D9488);
  // Blanco casi puro con un respiro de gris frío
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0F2A37);
  static const textSecondary = Color(0xFF5B6B7F);
  static const textHint = Color(0xFF94A3B8);
  static const error = Color(0xFFE53E3E);
  static const warning = Color(0xFFED8936);
  static const success = Color(0xFF16A34A);  // verde SOLO para estados positivos
  static const cardBorder = Color(0xFFE9EEF4);

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
        // Transiciones fluidas estilo Apple (deslizamiento con física suave)
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        splashFactory: InkSparkle.splashFactory,
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

  // Degradado sutil petróleo → azul profundo (nunca saturado)
  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [AppColors.primary, Color(0xFF14557A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Tarjeta glass: translúcida, borde suave, flotante
  static BoxDecoration glassCard({double radius = 20}) => BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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

/// Microinteracción táctil: escala suave al presionar (feedback inmediato).
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressableCard({super.key, required this.child, this.onTap});

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
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
