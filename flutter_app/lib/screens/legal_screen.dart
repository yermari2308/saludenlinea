import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Visor genérico de documentos legales — Design System 2.0.
class LegalScreen extends StatefulWidget {
  final String doc; // terminos | privacidad | consentimiento
  const LegalScreen({super.key, required this.doc});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String _titulo = '';
  String _texto = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getLegalDoc(widget.doc);
      if (mounted) {
        setState(() {
          _titulo = data['titulo'] as String? ?? '';
          _texto = data['texto'] as String? ?? '';
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DSScreen(
        title: _titulo.isEmpty ? 'Documento legal' : _titulo,
        subtitle: 'SaludEnLínea · Costa Rica',
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: DS.s6),
                child: Center(child: CircularProgressIndicator(color: DSColors.brand)),
              )
            : DSCard(
                padding: const EdgeInsets.all(DS.s3),
                child: Text(_texto,
                    style: const TextStyle(
                        fontSize: 13.5, height: 1.7, color: DSColors.textStrong, fontWeight: FontWeight.w400)),
              ),
      );
}

/// Chip de acceso a otro documento legal.
class _DocChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DocChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => DSPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: DSColors.brandSoft,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_rounded, size: 13, color: DSColors.brand),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: DSColors.brand)),
            ],
          ),
        ),
      );
}

/// Consentimiento informado — Design System 2.0. Exige lectura completa
/// (scroll al final) antes de habilitar la aceptación, con progreso visible.
/// Retorna `true` vía Navigator.pop si el paciente aceptó.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  String _texto = '';
  bool _loading = true;
  bool _aceptando = false;
  bool _leido = false;
  double _progreso = 0;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final px = _scrollCtrl.position.pixels;
    setState(() {
      _progreso = max <= 0 ? 1 : (px / max).clamp(0.0, 1.0);
      if (!_leido && px >= max - 60) _leido = true;
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getLegalDoc('consentimiento');
      if (mounted) setState(() => _texto = data['texto'] as String? ?? '');
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _aceptar() async {
    setState(() => _aceptando = true);
    try {
      await ApiService.acceptConsent('telemedicina');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: DSColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) setState(() => _aceptando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.ink,
      body: Column(
        children: [
          DSInkHeader(
            title: 'Consentimiento informado',
            subtitle: 'Necesario para atenderte por telemedicina',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: _leido
                    ? DSColors.mint.withOpacity(0.18)
                    : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_leido ? Icons.check_circle_rounded : Icons.menu_book_rounded,
                      size: 13, color: _leido ? DSColors.mint : Colors.white70),
                  const SizedBox(width: 5),
                  Text(_leido ? 'Leído' : '${(_progreso * 100).round()}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _leido ? DSColors.mint : Colors.white70)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: DSColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: DSColors.brand))
                  : Column(
                      children: [
                        // Barra de progreso de lectura
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(DSRadius.lg)),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: _progreso),
                            duration: const Duration(milliseconds: 180),
                            builder: (_, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 3,
                              backgroundColor: DSColors.line,
                              valueColor: AlwaysStoppedAnimation(
                                  _leido ? DSColors.mint : DSColors.brand),
                            ),
                          ),
                        ),
                        if (!_leido)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(DS.s3, DS.s2, DS.s3, 0),
                            padding: const EdgeInsets.symmetric(horizontal: DS.s2, vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.10),
                              borderRadius: DSRadius.rSm,
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFFB45309)),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Leé el documento hasta el final para poder aceptarlo.',
                                    style: TextStyle(
                                        fontSize: 12.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(DS.s3, DS.s3, DS.s3, DS.s3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: DS.s1,
                                  runSpacing: DS.s1,
                                  children: [
                                    _DocChip(
                                      label: 'Términos y Condiciones',
                                      onTap: () => Navigator.push(context,
                                          MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'terminos'))),
                                    ),
                                    _DocChip(
                                      label: 'Privacidad',
                                      onTap: () => Navigator.push(context,
                                          MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'privacidad'))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: DS.s3),
                                DSCard(
                                  padding: const EdgeInsets.all(DS.s3),
                                  child: Text(_texto,
                                      style: const TextStyle(
                                          fontSize: 13.5, height: 1.7,
                                          color: DSColors.textStrong, fontWeight: FontWeight.w400)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Barra de acciones
                        Container(
                          padding: const EdgeInsets.fromLTRB(DS.s3, DS.s2, DS.s3, DS.s2),
                          decoration: const BoxDecoration(
                            color: DSColors.surface,
                            border: Border(top: BorderSide(color: DSColors.line)),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                Expanded(
                                  child: DSPressable(
                                    onTap: () => Navigator.pop(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(100),
                                        border: Border.all(color: DSColors.line, width: 1.4),
                                      ),
                                      child: const Center(
                                        child: Text('No acepto',
                                            style: TextStyle(
                                                color: DSColors.textMid, fontSize: 14, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DS.s1 + 4),
                                Expanded(
                                  flex: 2,
                                  child: _aceptando
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(vertical: 17),
                                          decoration: BoxDecoration(
                                            color: DSColors.mint,
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: const Center(
                                            child: SizedBox(width: 20, height: 20,
                                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                                          ),
                                        )
                                      : _leido
                                          ? DSButton(
                                              label: 'Acepto',
                                              icon: Icons.check_rounded,
                                              color: DSColors.mint,
                                              onTap: _aceptar,
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(vertical: 17),
                                              decoration: BoxDecoration(
                                                color: DSColors.line,
                                                borderRadius: BorderRadius.circular(100),
                                              ),
                                              child: const Center(
                                                child: Text('Leé hasta el final…',
                                                    style: TextStyle(
                                                        color: DSColors.textFaint,
                                                        fontSize: 14, fontWeight: FontWeight.w700)),
                                              ),
                                            ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
