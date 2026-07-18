// ═══════════════════════════════════════════════════════════════════════════
// SALUDENLÍNEA DESIGN SYSTEM 2.0 — "Pura Vida Ink"
// ═══════════════════════════════════════════════════════════════════════════
// Lenguaje visual reconstruido desde cero. Identidad: tinta grafito +
// índigo eléctrico + menta clínica sobre lienzo papel. Nada de azul hospital.
//
// Fundamentos:
//   · Escala de espaciado de 8 px          (DS.s1..s6)
//   · Escala tipográfica de 6 niveles      (DSText)
//   · 3 niveles de elevación               (DSElevation)
//   · Radios: 12 / 20 / 28 / full          (DSRadius)
//   · Tokens duales claro/oscuro           (DSColors / DSColorsDark)
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Tokens de color (modo claro) ──────────────────────────────────────────────
class DSColors {
  // Base
  static const canvas = Color(0xFFF4F5F7);   // lienzo papel frío
  static const surface = Colors.white;
  static const ink = Color(0xFF16181D);      // tinta: texto y superficies fuertes
  static const inkSoft = Color(0xFF2A3140);  // grafito: gradientes de tinta

  // Marca
  static const brand = Color(0xFF4F46E5);        // índigo eléctrico: acción
  static const brandSoft = Color(0xFFEEF0FE);    // índigo 50: fondos de acento
  static const mint = Color(0xFF10B981);         // menta clínica: positivo
  static const mintSoft = Color(0xFFE7F8F1);
  static const coral = Color(0xFFF43F5E);        // coral: urgencia
  static const coralDeep = Color(0xFFE11D48);

  // Texto
  static const textStrong = Color(0xFF16181D);
  static const textMid = Color(0xFF626B77);
  static const textFaint = Color(0xFF9AA3AE);

  // Bordes y divisores
  static const line = Color(0xFFE7E9EE);

  // Semáforo clínico
  static const semGood = Color(0xFF10B981);
  static const semWarn = Color(0xFFF59E0B);
  static const semBad = Color(0xFFEF4444);
}

// ── Tokens de color (modo oscuro — listos para activarse) ─────────────────────
class DSColorsDark {
  static const canvas = Color(0xFF0E1013);
  static const surface = Color(0xFF16191E);
  static const ink = Color(0xFFF2F3F5);
  static const textStrong = Color(0xFFF2F3F5);
  static const textMid = Color(0xFFA5ADB8);
  static const line = Color(0xFF272B33);
}

// ── Espaciado (escala de 8 px) ────────────────────────────────────────────────
class DS {
  static const s05 = 4.0;
  static const s1 = 8.0;
  static const s2 = 16.0;
  static const s3 = 24.0;
  static const s4 = 32.0;
  static const s5 = 40.0;
  static const s6 = 48.0;
}

// ── Radios ────────────────────────────────────────────────────────────────────
class DSRadius {
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
}

// ── Elevación (3 niveles) ─────────────────────────────────────────────────────
class DSElevation {
  /// Nivel 1: reposa sobre el lienzo
  static List<BoxShadow> get rest => [
        BoxShadow(
          color: DSColors.ink.withOpacity(0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Nivel 2: flota (tarjetas interactivas)
  static List<BoxShadow> get float => [
        BoxShadow(
          color: DSColors.ink.withOpacity(0.08),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: DSColors.ink.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Nivel 3: protagonista (hero, dock, overlays)
  static List<BoxShadow> get hero => [
        BoxShadow(
          color: DSColors.ink.withOpacity(0.16),
          blurRadius: 44,
          offset: const Offset(0, 18),
        ),
      ];

  /// Resplandor de urgencia
  static List<BoxShadow> glow(Color c) => [
        BoxShadow(
          color: c.withOpacity(0.42),
          blurRadius: 26,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        ),
      ];
}

// ── Escala tipográfica ────────────────────────────────────────────────────────
class DSText {
  static const display = TextStyle(
      fontSize: 32, fontWeight: FontWeight.w800,
      letterSpacing: -1.0, height: 1.1, color: DSColors.textStrong);
  static const title = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800,
      letterSpacing: -0.5, height: 1.2, color: DSColors.textStrong);
  static const headline = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w700,
      letterSpacing: -0.3, height: 1.3, color: DSColors.textStrong);
  static const body = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w400,
      height: 1.5, color: DSColors.textMid);
  static const label = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600,
      height: 1.3, color: DSColors.textMid);
  static const caption = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 1.0, height: 1.2, color: DSColors.textFaint);
  /// Números tabulares (métricas, dinero, series)
  static const mono = TextStyle(
      fontSize: 26, fontWeight: FontWeight.w800,
      letterSpacing: -0.5, height: 1.1,
      fontFeatures: [FontFeature.tabularFigures()],
      color: DSColors.textStrong);
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENTES
// ═══════════════════════════════════════════════════════════════════════════

/// Superficie estándar del sistema: blanca, radio md, elevación rest.
class DSCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final List<BoxShadow>? shadows;

  const DSCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DS.s2),
    this.onTap,
    this.color,
    this.radius = DSRadius.md,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? DSColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows ?? DSElevation.rest,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return DSPressable(onTap: onTap, child: card);
  }
}

/// Tarjeta de tinta: superficie oscura protagonista (hero, métricas).
class DSInkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const DSInkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DS.s3),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DSColors.ink, DSColors.inkSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DSRadius.rLg,
        boxShadow: DSElevation.hero,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return DSPressable(onTap: onTap, child: card);
  }
}

/// Microinteracción de presión con física suave.
class DSPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const DSPressable({super.key, required this.child, this.onTap});

  @override
  State<DSPressable> createState() => _DSPressableState();
}

class _DSPressableState extends State<DSPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.965 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      );
}

/// Botón primario del sistema (píldora índigo).
class DSButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final Color foreground;
  final bool expanded;

  const DSButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color = DSColors.brand,
    this.foreground = Colors.white,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final btn = DSPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.s3, vertical: 17),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
          boxShadow: DSElevation.glow(color),
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foreground, size: 21),
              const SizedBox(width: 10),
            ],
            Text(label,
                style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
    );
    return btn;
  }
}

/// Chip de estado / etiqueta del sistema.
class DSChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const DSChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          ],
        ),
      );
}

/// Anillo de progreso animado (indicadores de salud).
class DSProgressRing extends StatelessWidget {
  final double pct; // 0..1
  final Color color;
  final double size;
  final Widget? center;

  const DSProgressRing({
    super.key,
    required this.pct,
    required this.color,
    this.size = 72,
    this.center,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: pct.clamp(0, 1)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(v, color),
              ),
              if (center != null) center!,
            ],
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  _RingPainter(this.pct, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.12);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * pct, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.color != color;
}

/// Dock flotante de navegación (reemplaza la barra inferior tradicional).
class DSDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items; // (outline, filled, label)
  final VoidCallback? onCenterTap; // acción central (urgencia)
  final IconData centerIcon;

  const DSDock({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
    this.onCenterTap,
    this.centerIcon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final mitad = (items.length / 2).ceil();
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(DS.s2, 0, DS.s2, 10),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: DS.s1),
        decoration: BoxDecoration(
          color: DSColors.ink.withOpacity(0.94),
          borderRadius: BorderRadius.circular(34),
          boxShadow: DSElevation.hero,
        ),
        child: Row(
          children: [
            for (var i = 0; i < mitad; i++) _item(i),
            if (onCenterTap != null) _center(),
            for (var i = mitad; i < items.length; i++) _item(i),
          ],
        ),
      ),
    );
  }

  Widget _item(int i) {
    final selected = index == i;
    return Expanded(
      child: DSPressable(
        onTap: () => onTap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? items[i].$2 : items[i].$1,
                size: 22,
                color: selected ? Colors.white : Colors.white.withOpacity(0.45),
              ),
              const SizedBox(height: 1),
              Text(items[i].$3,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.45))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _center() => DSPressable(
        onTap: onCenterTap,
        child: Container(
          width: 52,
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [DSColors.coral, DSColors.coralDeep]),
            shape: BoxShape.circle,
            boxShadow: DSElevation.glow(DSColors.coral),
          ),
          child: Icon(centerIcon, color: Colors.white, size: 28),
        ),
      );
}

/// Campo de texto del sistema: superficie blanca, radio 14, foco índigo.
class DSField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final String? helper;

  const DSField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: 1.4),
        );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: obscure ? 1 : maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: const TextStyle(
          fontSize: 15, color: DSColors.textStrong, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperStyle: const TextStyle(fontSize: 11.5, color: DSColors.textFaint),
        labelStyle: const TextStyle(
            color: DSColors.textMid, fontSize: 14, fontWeight: FontWeight.w500),
        floatingLabelStyle:
            const TextStyle(color: DSColors.brand, fontWeight: FontWeight.w700),
        prefixIcon: icon == null ? null : Icon(icon, color: DSColors.textMid, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: DSColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
        enabledBorder: border(DSColors.line),
        focusedBorder: border(DSColors.brand),
        errorBorder: border(DSColors.coral),
        focusedErrorBorder: border(DSColors.coral),
      ),
    );
  }
}

/// Encabezado de tinta para pantallas secundarias: botón atrás circular,
/// título y subtítulo sobre gradiente grafito.
class DSInkHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  const DSInkHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) => Container(
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
            padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s3, DS.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DSPressable(
                      onTap: onBack ?? () => Navigator.maybePop(context),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: DS.s2),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
        ),
      );
}

/// Cáscara de pantalla secundaria: encabezado de tinta + panel de lienzo.
class DSScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Widget? bottom;
  final EdgeInsets padding;

  const DSScreen({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(DS.s3, DS.s4, DS.s3, DS.s3),
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: DSColors.ink,
        body: Column(
          children: [
            DSInkHeader(title: title, subtitle: subtitle, trailing: trailing),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: DSColors.canvas,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
                ),
                child: SingleChildScrollView(padding: padding, child: child),
              ),
            ),
          ],
        ),
        bottomNavigationBar: bottom,
      );
}

/// Estado vacío ilustrado del sistema.
class DSEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color color;

  const DSEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.color = DSColors.brand,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: DS.s6, horizontal: DS.s3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: color),
            ),
            const SizedBox(height: DS.s3),
            Text(title, style: DSText.headline, textAlign: TextAlign.center),
            const SizedBox(height: DS.s1),
            Text(message, style: DSText.body, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: DS.s3),
              action!,
            ],
          ],
        ),
      );
}

/// Encabezado de sección del sistema.
class DSSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const DSSectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: DS.s2 - 4),
        child: Row(
          children: [
            Text(title.toUpperCase(), style: DSText.caption),
            const Spacer(),
            if (action != null)
              GestureDetector(
                onTap: onAction,
                child: Text(action!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DSColors.brand)),
              ),
          ],
        ),
      );
}
