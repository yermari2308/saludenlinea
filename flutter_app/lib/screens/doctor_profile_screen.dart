import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

/// Pestaña "Perfil" del panel médico: competencias, tarifa y datos editables.
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
        _tarifaCtrl.text =
            ((data['tarifa'] as num?)?.toDouble() ?? 15).toStringAsFixed(2);
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
      _snack('Ingresa una tarifa válida', error: true);
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
      backgroundColor: error ? AppColors.error : AppColors.accentDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _perfil?['nombre'] as String? ?? '';
    final iniciales = nombre.length >= 2
        ? nombre.substring(0, 2).toUpperCase()
        : nombre.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi perfil profesional',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cabecera ────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        GradientAvatar(initials: iniciales, radius: 40),
                        const SizedBox(height: 10),
                        Text('Dr. $nombre',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        Text(_perfil?['email'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${((_perfil?['calificacion'] as num?) ?? 5).toStringAsFixed(1)} de calificación',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Especialidad ────────────────────────────────────────
                  const _Label('Especialidad'),
                  const SizedBox(height: 6),
                  _Input(ctrl: _espCtrl, hint: 'Ej: Medicina General'),
                  const SizedBox(height: 16),
                  const _Label('Código médico (Colegio de Médicos CR)'),
                  const SizedBox(height: 4),
                  const Text(
                    'Aparece en tus recetas. Requerido para ejercer telemedicina en Costa Rica.',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 8),
                  _Input(ctrl: _codigoCtrl, hint: 'Ej: MED-12345'),
                  const SizedBox(height: 16),
                  // ── Competencias / credenciales ─────────────────────────
                  const _Label('Competencias y credenciales'),
                  const SizedBox(height: 4),
                  const Text(
                    'Describe tu formación, experiencia, código médico y áreas de competencia. '
                    'Los pacientes ven esta información en tu perfil.',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 8),
                  _Input(
                    ctrl: _credCtrl,
                    hint:
                        'Ej: Médico cirujano UCR, código 12345. 8 años de experiencia en…',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 16),
                  // ── Tarifa ──────────────────────────────────────────────
                  const _Label('Tarifa por consulta (USD)'),
                  const SizedBox(height: 6),
                  _Input(
                    ctrl: _tarifaCtrl,
                    hint: '15.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar cambios',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary));
}

class _Input extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Input({
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            borderSide:
                const BorderSide(color: AppColors.primaryLight, width: 1.5),
          ),
        ),
      );
}
