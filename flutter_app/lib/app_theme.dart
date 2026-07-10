import 'package:flutter/material.dart';

class AppColors {
  // ══ DESIGN SYSTEM 2.0 — "Pura Vida Ink" ═════════════════════════════════
  // Tinta grafito + índigo eléctrico + menta clínica sobre lienzo papel.
  // Estos tokens re-visten TODA la app (ver design_system.dart).
  static const primary = Color(0xFF16181D);      // tinta: superficies fuertes
  static const primaryLight = Color(0xFF4F46E5); // índigo: toda acción
  static const accent = Color(0xFF34D399);       // menta: medicina moderna
  static const accentDark = Color(0xFF10B981);
  static const background = Color(0xFFF4F5F7);   // lienzo papel frío
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF16181D);
  static const textSecondary = Color(0xFF626B77);
  static const textHint = Color(0xFF9AA3AE);
  static const error = Color(0xFFE11D48);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);  // verde SOLO para estados positivos
  static const cardBorder = Color(0xFFE7E9EE);

  // ── Urgencia: coral — alerta viva sin agresión ───────────────────────────
  static const alert = Color(0xFFF43F5E);
  static const alertDark = Color(0xFFE11D48);

  // ── Semáforo clínico (HRA) — separado de la marca ────────────────────────
  static const semGreen = Color(0xFF10B981);
  static const semYellow = Color(0xFFF59E0B);
  static const semRed = Color(0xFFEF4444);
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

  // Degradado de tinta: grafito profundo (cabeceras y superficies hero)
  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [AppColors.primary, Color(0xFF2A3140)],
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

/// Skeleton de carga con pulso suave (shimmer) — estados de carga elegantes.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE4EAF1),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

/// Tarjeta skeleton estándar (avatar + líneas) para listas en carga.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: const Row(
          children: [
            Skeleton(width: 52, height: 52, radius: 26),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 160, height: 15),
                  SizedBox(height: 8),
                  Skeleton(width: 100, height: 12),
                ],
              ),
            ),
            Skeleton(width: 48, height: 26, radius: 13),
          ],
        ),
      );
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
