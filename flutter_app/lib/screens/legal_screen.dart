import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';

/// Visor genérico de documentos legales (términos, privacidad, consentimiento).
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_titulo.isEmpty ? 'Documento legal' : _titulo,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [AppTheme.cardShadow],
                ),
                child: Text(
                  _texto,
                  style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.65,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
    );
  }
}

class _DocChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DocChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_rounded,
                  size: 13, color: AppColors.primaryLight),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight)),
            ],
          ),
        ),
      );
}

/// Pantalla de consentimiento informado con botón de aceptación.
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
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      if (!_leido &&
          _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 60) {
        setState(() => _leido = true);
      }
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
          content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _aceptando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Consentimiento informado',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFEF3C7),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: Color(0xFF92400E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Leé el documento completo para poder aceptarlo.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _DocChip(
                              label: 'Términos y Condiciones',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const LegalScreen(doc: 'terminos'))),
                            ),
                            const SizedBox(width: 8),
                            _DocChip(
                              label: 'Privacidad',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const LegalScreen(doc: 'privacidad'))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _texto,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.65,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('No acepto'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed:
                                (_leido && !_aceptando) ? _aceptar : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentDark,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.cardBorder,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _aceptando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(
                                    _leido
                                        ? 'Acepto el consentimiento'
                                        : 'Leé hasta el final…',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
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
