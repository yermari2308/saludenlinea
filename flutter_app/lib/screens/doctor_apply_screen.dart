import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
    'Medicina General',
    'Pediatría',
    'Cardiología',
    'Dermatología',
    'Psicología',
    'Ginecología',
    'Neurología',
    'Ortopedia',
    'Oftalmología',
    'Otra',
  ];

  final List<String> _paises = [
    'Costa Rica', 'México', 'Colombia', 'Argentina',
    'Chile', 'Perú', 'Venezuela', 'Ecuador', 'Guatemala', 'Otro',
  ];

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
      setState(() => _enviado = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Únete como médico'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: _enviado ? _successView() : _formView(),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              '¡Solicitud enviada!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Revisaremos tu información y nos pondremos en contacto contigo a ${_emailCtrl.text} o ${_telCtrl.text} en menos de 48 horas.',
              style: const TextStyle(fontSize: 15, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header motivacional
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF1976D2),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Llega a más pacientes',
                    style: TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'Únete a SaludEnLínea y ofrece consultas virtuales desde cualquier lugar. '
                  'Sin costos de infraestructura, solo tú y tus pacientes.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 16),
                Row(children: [
                  _Chip('✓ Sin inversión inicial'),
                  SizedBox(width: 8),
                  _Chip('✓ Horario flexible'),
                ]),
                SizedBox(height: 8),
                Row(children: [
                  _Chip('✓ Pagos seguros'),
                  SizedBox(width: 8),
                  _Chip('✓ Más pacientes'),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Tus datos de contacto',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      prefixIcon: Icon(Icons.person_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico *',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Correo inválido' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp / Teléfono *',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '+506 8888-8888',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: _pais,
                    decoration: const InputDecoration(
                      labelText: 'País *',
                      prefixIcon: Icon(Icons.public),
                      border: OutlineInputBorder(),
                    ),
                    items: _paises.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() => _pais = v!),
                  ),
                  const SizedBox(height: 24),

                  const Text('Tu perfil médico',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _especialidad,
                    decoration: const InputDecoration(
                      labelText: 'Especialidad *',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _especialidades
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _especialidad = v!),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _credCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cédula médica / Credenciales',
                      prefixIcon: Icon(Icons.badge_outlined),
                      hintText: 'Ej: Cédula 12345, Universidad Nacional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Años de experiencia
                  Row(
                    children: [
                      const Icon(Icons.work_outline, color: Colors.grey),
                      const SizedBox(width: 12),
                      const Text('Años de experiencia:',
                          style: TextStyle(fontSize: 15)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _anos > 1 ? () => setState(() => _anos--) : null,
                      ),
                      Text('$_anos', style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => _anos++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _mensajeCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Cuéntanos sobre ti (opcional)',
                      prefixIcon: Icon(Icons.chat_outlined),
                      hintText: '¿Por qué quieres unirte? ¿Qué te diferencia?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(_loading ? 'Enviando...' : 'Enviar solicitud',
                        style: const TextStyle(fontSize: 16)),
                    onPressed: _loading ? null : _enviar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Te contactaremos en menos de 48 horas para coordinar los detalles.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
