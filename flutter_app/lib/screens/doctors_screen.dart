import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/doctor_card.dart';
import 'doctor_detail_screen.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  List<Doctor> _doctors = [];
  bool _loading = true;
  String? _filtro;
  final _searchCtrl = TextEditingController();

  final List<String> _especialidades = [
    'Todas',
    'Medicina General',
    'Pediatría',
    'Cardiología',
    'Dermatología',
    'Psicología',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? esp]) async {
    setState(() => _loading = true);
    try {
      final doctors = await ApiService.getDoctors(especialidad: esp == 'Todas' ? null : esp);
      setState(() => _doctors = doctors);
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
        title: const Text('SaludEnLínea', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load(_filtro)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1976D2),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por especialidad…',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white24,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
              ),
              onSubmitted: (v) => _load(v.isEmpty ? null : v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _especialidades.length,
              itemBuilder: (_, i) {
                final esp = _especialidades[i];
                final selected = _filtro == esp || (esp == 'Todas' && _filtro == null);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(esp),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _filtro = esp == 'Todas' ? null : esp);
                      _load(esp == 'Todas' ? null : esp);
                    },
                    selectedColor: const Color(0xFF1976D2).withOpacity(0.2),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _doctors.isEmpty
                    ? const Center(child: Text('No se encontraron médicos'))
                    : ListView.builder(
                        itemCount: _doctors.length,
                        itemBuilder: (_, i) => DoctorCard(
                          doctor: _doctors[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DoctorDetailScreen(doctor: _doctors[i])),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
