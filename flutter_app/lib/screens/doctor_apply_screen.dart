import 'package:flutter/material.dart';
import '../design_system.dart';
import '../services/api_service.dart';

/// Postulación de médicos — Design System 2.0. Propuesta de valor en tinta,
/// formulario agrupado por secciones sobre lienzo.
class DoctorApplyScreen extends StatefulWidget {
  const DoctorApplyScreen({super.key});

  @override
  State<DoctorApplyScreen> createState() => _DoctorApplyScreenState();
}

class _DoctorApplyScreenState extends State<DoctorApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _enviado = false;

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _credCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();

  String _especialidad = 'Medicina General';
  String _pais = 'Costa Rica';
  int _anos = 1;

  final List<String> _especialidades = [
    'Medicina General', 'Pediatría', 'Cardiología', 'Dermatología',
    'Psicología', 'Ginecología', 'Neurología', 'Ortopedia',
    'Oftalmología', 'Otra',
  ];

  final List<String> _paises = [
    'Costa Rica', 'México', 'Colombia', 'Argentina',
    'Chile', 'Perú', 'Venezuela', 'Ecuador', 'Guatemala', 'Otro',
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _credCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.submitDoctorLead(
        nombre: _nombreCtrl.text.trim(),
        especialidad: _especialidad,
        email: _emailCtrl.text.trim(),
        telefono: _telCtrl.text.trim(),
        pais: _pais,
        credenciales: _credCtrl.text.trim(),
        anosExperiencia: _anos,
        mensaje: _mensajeCtrl.text.trim(),
      );
      if (mounted) setState(() => _enviado = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: DSColors.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DSScreen(
        title: _enviado ? 'Solicitud enviada' : 'Unite como médico',
        subtitle: _enviado
            ? 'Te contactamos pronto'
            : 'Atendé pacientes desde donde estés',
        child: _enviado ? _vistaExito() : _vistaFormulario(),
      );

  // ── Éxito ──────────────────────────────────────────────────────────────
  Widget _vistaExito() => DSEmpty(
        icon: Icons.verified_rounded,
        color: DSColors.mint,
        title: '¡Solicitud enviada!',
        message: 'Revisaremos tu información y te contactamos a '
            '${_emailCtrl.text.trim()} o al ${_telCtrl.text.trim()} '
            'en menos de 48 horas.',
        action: DSButton(
          label: 'Volver al inicio',
          icon: Icons.arrow_back_rounded,
          color: DSColors.mint,
          onTap: () => Navigator.pop(context),
        ),
      );

  // ── Formulario ─────────────────────────────────────────────────────────
  Widget _vistaFormulario() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Propuesta de valor
            DSInkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Llegá a más pacientes',
                      style: TextStyle(
                          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  const SizedBox(height: DS.s1),
                  Text(
                    'Ofrecé consultas virtuales sin costos de infraestructura. '
                    'Vos ponés el horario, nosotros los pacientes.',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: DS.s2),
                  Wrap(
                    spacing: DS.s1,
                    runSpacing: DS.s1,
                    children: const [
                      _Beneficio('Sin inversión inicial'),
                      _Beneficio('Horario flexible'),
                      _Beneficio('Pagos seguros'),
                      _Beneficio('Más pacientes'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DS.s4),

            const DSSectionHeader(title: 'Datos de contacto'),
            DSField(
              controller: _nombreCtrl,
              label: 'Nombre completo *',
              icon: Icons.person_outline_rounded,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: DS.s2),
            DSField(
              controller: _emailCtrl,
              label: 'Correo electrónico *',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || !v.contains('@') ? 'Correo inválido' : null,
            ),
            const SizedBox(height: DS.s2),
            DSField(
              controller: _telCtrl,
              label: 'WhatsApp / Teléfono *',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              helper: 'Ej: +506 8888-8888',
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: DS.s2),
            _Selector(
              label: 'País',
              icon: Icons.public_rounded,
              value: _pais,
              options: _paises,
              onChanged: (v) => setState(() => _pais = v),
            ),
            const SizedBox(height: DS.s4),

            const DSSectionHeader(title: 'Perfil médico'),
            _Selector(
              label: 'Especialidad',
              icon: Icons.medical_services_outlined,
              value: _especialidad,
              options: _especialidades,
              onChanged: (v) => setState(() => _especialidad = v),
            ),
            const SizedBox(height: DS.s2),
            DSField(
              controller: _credCtrl,
              label: 'Código médico / Credenciales',
              icon: Icons.badge_outlined,
              helper: 'Ej: Código 12345, Colegio de Médicos CR',
            ),
            const SizedBox(height: DS.s2),
            // Contador de años
            DSCard(
              child: Row(
                children: [
                  const Icon(Icons.work_outline_rounded, color: DSColors.textMid, size: 21),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Años de experiencia',
                        style: TextStyle(fontSize: 14.5, color: DSColors.textStrong, fontWeight: FontWeight.w600)),
                  ),
                  _Stepper(
                    icon: Icons.remove_rounded,
                    onTap: _anos > 1 ? () => setState(() => _anos--) : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('$_anos',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800,
                            color: DSColors.textStrong,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                  _Stepper(
                    icon: Icons.add_rounded,
                    onTap: () => setState(() => _anos++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DS.s2),
            DSField(
              controller: _mensajeCtrl,
              label: 'Contanos sobre vos (opcional)',
              icon: Icons.chat_bubble_outline_rounded,
              maxLines: 4,
              helper: '¿Por qué querés unirte? ¿Qué te diferencia?',
            ),
            const SizedBox(height: DS.s4),

            _loading
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: DSColors.mint,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: DSElevation.glow(DSColors.mint),
                    ),
                    child: const Center(
                      child: SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                    ),
                  )
                : DSButton(
                    label: 'Enviar solicitud',
                    icon: Icons.send_rounded,
                    color: DSColors.mint,
                    onTap: _enviar,
                  ),
            const SizedBox(height: DS.s2),
            Text('Te contactamos en menos de 48 horas para coordinar los detalles.',
                textAlign: TextAlign.center,
                style: DSText.body.copyWith(fontSize: 12, color: DSColors.textFaint)),
          ],
        ),
      );
}

/// Píldora de beneficio sobre tinta.
class _Beneficio extends StatelessWidget {
  final String label;
  const _Beneficio(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: DSColors.mint.withOpacity(0.16),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 13, color: DSColors.mint),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(color: DSColors.mint, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// Botón redondo de incremento/decremento (44px táctil).
class _Stepper extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _Stepper({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final activo = onTap != null;
    return DSPressable(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: activo ? DSColors.brandSoft : DSColors.canvas,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 19, color: activo ? DSColors.brand : DSColors.textFaint),
      ),
    );
  }
}

/// Selector desplegable con estilo de campo del sistema.
class _Selector extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _Selector({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: 1.4),
        );
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, color: DSColors.textMid),
      style: const TextStyle(fontSize: 15, color: DSColors.textStrong, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: DSColors.textMid, fontSize: 14, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: DSColors.brand, fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: DSColors.textMid, size: 21),
        filled: true,
        fillColor: DSColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
        enabledBorder: border(DSColors.line),
        focusedBorder: border(DSColors.brand),
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}
