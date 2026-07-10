import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

/// Perfil profesional del médico — Design System 2.0. Hero de tinta con
/// identidad, formulario agrupado en tarjetas por sección.
class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Map<String, dynamic>? _perfil;
  bool _loading = true;
  bool _guardando = false;

  final _credCtrl = TextEditingController();
  final _tarifaCtrl = TextEditingController();
  final _espCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _credCtrl.dispose();
    _tarifaCtrl.dispose();
    _espCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getDoctorProfile();
      if (!mounted) return;
      setState(() {
        _perfil = data;
        _credCtrl.text = data['credenciales'] as String? ?? '';
        _tarifaCtrl.text = ((data['tarifa'] as num?)?.toDouble() ?? 15).toStringAsFixed(2);
        _espCtrl.text = data['especialidad'] as String? ?? '';
        _codigoCtrl.text = data['codigo_medico'] as String? ?? '';
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guardar() async {
    final tarifa = double.tryParse(_tarifaCtrl.text.trim());
    if (tarifa == null || tarifa <= 0) {
      _snack('Ingresá una tarifa válida', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await ApiService.updateDoctorProfile({
        'especialidad': _espCtrl.text.trim(),
        'credenciales': _credCtrl.text.trim(),
        'tarifa': tarifa,
        'codigo_medico': _codigoCtrl.text.trim(),
      });
      if (!mounted) return;
      _snack('Perfil actualizado correctamente');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? DSColors.coral : DSColors.mint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _perfil?['nombre'] as String? ?? '';
    final iniciales = nombre.length >= 2 ? nombre.substring(0, 2).toUpperCase() : nombre.toUpperCase();

    return Scaffold(
      backgroundColor: DSColors.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: DSColors.brand))
            : ListView(
                padding: const EdgeInsets.fromLTRB(DS.s2, DS.s2, DS.s2, 100),
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Perfil profesional', style: DSText.title)),
                      DSPressable(
                        onTap: _logout,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: DSColors.surface, shape: BoxShape.circle, boxShadow: DSElevation.rest),
                          child: const Icon(Icons.logout_rounded, size: 18, color: DSColors.coral),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DS.s2),
                  // ── Hero de identidad ─────────────────────────────────────
                  DSInkCard(
                    padding: const EdgeInsets.all(DS.s3),
                    child: Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [DSColors.mint, Color(0xFF059669)]),
                            shape: BoxShape.circle,
                            boxShadow: DSElevation.glow(DSColors.mint),
                          ),
                          child: Center(child: Text(iniciales, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                        ),
                        const SizedBox(width: DS.s2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dr. $nombre', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(_perfil?['email'] as String? ?? '', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                const SizedBox(width: 4),
                                Text('${((_perfil?['calificacion'] as num?) ?? 5).toStringAsFixed(1)} de calificación',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DS.s3),
                  const DSSectionHeader(title: 'Especialidad'),
                  DSCard(child: _Field(ctrl: _espCtrl, hint: 'Ej: Medicina General')),
                  const SizedBox(height: DS.s2),
                  const DSSectionHeader(title: 'Código médico (Colegio de Médicos CR)'),
                  DSCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field(ctrl: _codigoCtrl, hint: 'Ej: MED-12345'),
                        const SizedBox(height: 6),
                        const Text('Aparece en tus recetas. Requerido para ejercer telemedicina en Costa Rica.',
                            style: TextStyle(fontSize: 11, color: DSColors.textFaint)),
                      ],
                    ),
                  ),
                  const SizedBox(height: DS.s2),
                  const DSSectionHeader(title: 'Competencias y credenciales'),
                  DSCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field(ctrl: _credCtrl, hint: 'Ej: Médico cirujano UCR, código 12345. 8 años de experiencia en…', maxLines: 6),
                        const SizedBox(height: 6),
                        const Text('Los pacientes ven esta información en tu perfil.',
                            style: TextStyle(fontSize: 11, color: DSColors.textFaint)),
                      ],
                    ),
                  ),
                  const SizedBox(height: DS.s2),
                  const DSSectionHeader(title: 'Tarifa por consulta (USD)'),
                  DSCard(
                    child: _Field(ctrl: _tarifaCtrl, hint: '15.00', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  ),
                  const SizedBox(height: DS.s4),
                  DSButton(
                    label: _guardando ? 'Guardando…' : 'Guardar cambios',
                    icon: _guardando ? null : Icons.check_rounded,
                    color: DSColors.mint,
                    onTap: _guardando ? null : _guardar,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({required this.ctrl, required this.hint, this.maxLines = 1, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14.5, color: DSColors.textStrong, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: DSColors.textFaint, fontSize: 13.5, fontWeight: FontWeight.w400),
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      );
}
