import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design_system.dart';

/// Pantalla de bienvenida animada — escena de telemedicina dibujada 100% en
/// Flutter (sin video ni assets): un médico y un paciente conectados por
/// ondas de señal, con la marca apareciendo en secuencia.
///
/// Se dibuja con CustomPainter para no agregar ni un MB al APK ni depender
/// de la red — arranca instantáneo incluso sin conexión.
class SplashScene extends StatefulWidget {
  /// Mensaje de estado bajo el logo (ej. "Verificando sesión…").
  final String? estado;

  const SplashScene({super.key, this.estado});

  @override
  State<SplashScene> createState() => _SplashSceneState();
}

class _SplashSceneState extends State<SplashScene>
    with TickerProviderStateMixin {
  late final AnimationController _entrada; // aparición en secuencia
  late final AnimationController _bucle;   // ondas y pulso continuos

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _bucle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _entrada.dispose();
    _bucle.dispose();
    super.dispose();
  }

  /// Interpolación escalonada: cada elemento entra en su propia ventana.
  double _tramo(double inicio, double fin) {
    final t = ((_entrada.value - inicio) / (fin - inicio)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.ink,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [DSColors.ink, DSColors.inkSoft],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_entrada, _bucle]),
            builder: (_, __) {
              final aparecerEscena = _tramo(0.00, 0.45);
              final aparecerLogo = _tramo(0.35, 0.75);
              final aparecerTexto = _tramo(0.60, 1.00);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // ── Escena: médico ←señal→ paciente ─────────────────
                  Opacity(
                    opacity: aparecerEscena,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - aparecerEscena)),
                      child: SizedBox(
                        width: 300,
                        height: 190,
                        child: CustomPaint(
                          painter: _EscenaTelemedicina(
                            progresoEntrada: aparecerEscena,
                            fase: _bucle.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DS.s5),
                  // ── Marca ──────────────────────────────────────────
                  Opacity(
                    opacity: aparecerLogo,
                    child: Transform.scale(
                      scale: 0.88 + 0.12 * aparecerLogo,
                      child: Column(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [DSColors.mint, Color(0xFF059669)]),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: DSElevation.glow(DSColors.mint),
                            ),
                            child: const Icon(Icons.health_and_safety_rounded,
                                size: 30, color: Colors.white),
                          ),
                          const SizedBox(height: DS.s2),
                          const Text(
                            'SaludEnLínea',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DS.s1),
                  Opacity(
                    opacity: aparecerTexto,
                    child: Text(
                      'Tu doctor, en el bolsillo',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // ── Estado de carga ────────────────────────────────
                  Opacity(
                    opacity: aparecerTexto,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 130,
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.white.withOpacity(0.10),
                              valueColor: const AlwaysStoppedAnimation(DSColors.mint),
                            ),
                          ),
                        ),
                        const SizedBox(height: DS.s2),
                        Text(
                          widget.estado ?? 'Preparando todo…',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DS.s5),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dibuja la consulta: el médico en su pantalla a la izquierda, el paciente
/// con su teléfono a la derecha, y ondas de señal viajando entre ambos.
class _EscenaTelemedicina extends CustomPainter {
  final double progresoEntrada;
  final double fase; // 0..1 continuo

  _EscenaTelemedicina({required this.progresoEntrada, required this.fase});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height * 0.52;

    _dibujarPantallaMedico(canvas, Offset(size.width * 0.17, cy));
    _dibujarOndas(canvas, size, cy);
    _dibujarTelefonoPaciente(canvas, Offset(size.width * 0.83, cy));
  }

  // ── Médico: monitor con figura y bata ────────────────────────────────
  void _dibujarPantallaMedico(Canvas canvas, Offset centro) {
    const anchoM = 104.0;
    const altoM = 82.0;
    final marco = Rect.fromCenter(center: centro, width: anchoM, height: altoM);
    final rrect = RRect.fromRectAndRadius(marco, const Radius.circular(12));

    // Cuerpo del monitor
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withOpacity(0.07),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withOpacity(0.16),
    );

    // Base del monitor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(centro.dx, centro.dy + altoM / 2 + 9),
            width: 34, height: 5),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withOpacity(0.14),
    );

    // Figura del médico dentro de la pantalla
    final cabezaC = Offset(centro.dx, centro.dy - 13);
    canvas.drawCircle(cabezaC, 12, Paint()..color = DSColors.mint);

    // Bata (hombros)
    final bata = Path()
      ..moveTo(centro.dx - 26, centro.dy + 28)
      ..quadraticBezierTo(centro.dx - 24, centro.dy + 4, centro.dx - 9, centro.dy - 1)
      ..lineTo(centro.dx + 9, centro.dy - 1)
      ..quadraticBezierTo(centro.dx + 24, centro.dy + 4, centro.dx + 26, centro.dy + 28)
      ..close();
    canvas.drawPath(bata, Paint()..color = Colors.white.withOpacity(0.88));

    // Cuello en V de la bata
    final cuello = Path()
      ..moveTo(centro.dx - 7, centro.dy - 1)
      ..lineTo(centro.dx, centro.dy + 11)
      ..lineTo(centro.dx + 7, centro.dy - 1)
      ..close();
    canvas.drawPath(cuello, Paint()..color = DSColors.inkSoft);

    // Estetoscopio: tubo + campana (latido sincronizado con la fase)
    final tubo = Path()
      ..moveTo(centro.dx - 6, centro.dy + 2)
      ..quadraticBezierTo(
          centro.dx - 15, centro.dy + 14, centro.dx - 9, centro.dy + 22);
    canvas.drawPath(
      tubo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = DSColors.brand,
    );
    final latido = 1 + 0.18 * math.sin(fase * math.pi * 2 * 2);
    canvas.drawCircle(
      Offset(centro.dx - 9, centro.dy + 24),
      3.4 * latido,
      Paint()..color = DSColors.brand,
    );

    // Punto "en vivo"
    canvas.drawCircle(
      Offset(marco.right - 11, marco.top + 11),
      3,
      Paint()..color = DSColors.mint.withOpacity(0.5 + 0.5 * math.sin(fase * math.pi * 2)),
    );
  }

  // ── Ondas de señal viajando de izquierda a derecha ───────────────────
  void _dibujarOndas(Canvas canvas, Size size, double cy) {
    final xIni = size.width * 0.32;
    final xFin = size.width * 0.68;
    final tramo = xFin - xIni;

    // Línea guía punteada
    final guia = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (double x = xIni; x < xFin; x += 9) {
      canvas.drawLine(Offset(x, cy), Offset(x + 4, cy), guia);
    }

    // Tres paquetes de datos desfasados
    for (int i = 0; i < 3; i++) {
      final t = (fase + i / 3) % 1.0;
      final x = xIni + tramo * t;
      // Se desvanece en los extremos del recorrido
      final vis = math.sin(t * math.pi).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(x, cy),
        4.2,
        Paint()..color = DSColors.mint.withOpacity(0.9 * vis),
      );
      canvas.drawCircle(
        Offset(x, cy),
        9 * (0.6 + 0.4 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = DSColors.mint.withOpacity(0.30 * vis),
      );
    }
  }

  // ── Paciente: teléfono con la persona en pantalla ────────────────────
  void _dibujarTelefonoPaciente(Canvas canvas, Offset centro) {
    const anchoT = 66.0;
    const altoT = 116.0;
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centro, width: anchoT, height: altoT),
      const Radius.circular(15),
    );

    canvas.drawRRect(cuerpo, Paint()..color = Colors.white.withOpacity(0.07));
    canvas.drawRRect(
      cuerpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withOpacity(0.16),
    );

    // Muesca superior
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(centro.dx, centro.dy - altoT / 2 + 8),
            width: 22, height: 4),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withOpacity(0.20),
    );

    // Paciente en pantalla
    final cabezaP = Offset(centro.dx, centro.dy - 16);
    canvas.drawCircle(cabezaP, 11, Paint()..color = DSColors.brand);

    final torso = Path()
      ..moveTo(centro.dx - 20, centro.dy + 26)
      ..quadraticBezierTo(centro.dx - 18, centro.dy + 3, centro.dx, centro.dy - 2)
      ..quadraticBezierTo(centro.dx + 18, centro.dy + 3, centro.dx + 20, centro.dy + 26)
      ..close();
    canvas.drawPath(torso, Paint()..color = DSColors.brand.withOpacity(0.75));

    // Barra de "llamada activa" al pie de la pantalla
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(centro.dx, centro.dy + altoT / 2 - 14),
            width: 40, height: 8),
        const Radius.circular(4),
      ),
      Paint()..color = DSColors.mint.withOpacity(0.22),
    );
    // Progreso de la barra pulsando
    final ancho = 40 * (0.35 + 0.45 * (0.5 + 0.5 * math.sin(fase * math.pi * 2)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centro.dx - 20, centro.dy + altoT / 2 - 18, ancho, 8),
        const Radius.circular(4),
      ),
      Paint()..color = DSColors.mint,
    );
  }

  @override
  bool shouldRepaint(_EscenaTelemedicina old) =>
      old.fase != fase || old.progresoEntrada != progresoEntrada;
}
