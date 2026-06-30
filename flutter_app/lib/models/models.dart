class Doctor {
  final int id;
  final String nombre;
  final String especialidad;
  final String fotoUrl;
  final String credenciales;
  final double tarifa;
  final double calificacion;

  Doctor({
    required this.id,
    required this.nombre,
    required this.especialidad,
    required this.fotoUrl,
    required this.credenciales,
    required this.tarifa,
    required this.calificacion,
  });

  factory Doctor.fromJson(Map<String, dynamic> j) => Doctor(
        id: j['id'],
        nombre: j['nombre'],
        especialidad: j['especialidad'],
        fotoUrl: j['foto_url'] ?? '',
        credenciales: j['credenciales'] ?? '',
        tarifa: (j['tarifa'] as num).toDouble(),
        calificacion: (j['calificacion'] as num).toDouble(),
      );
}

class Appointment {
  final int id;
  final int pacienteId;
  final int doctorId;
  final DateTime fechaHora;
  final String estado;
  final String notas;
  final String receta;
  final String recetaArchivoNombre;

  Appointment({
    required this.id,
    required this.pacienteId,
    required this.doctorId,
    required this.fechaHora,
    required this.estado,
    required this.notas,
    required this.receta,
    this.recetaArchivoNombre = '',
  });

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'],
        pacienteId: j['paciente_id'],
        doctorId: j['doctor_id'],
        fechaHora: DateTime.parse(j['fecha_hora']),
        estado: j['estado'],
        notas: j['notas_texto'] ?? '',
        receta: j['receta_texto'] ?? '',
        recetaArchivoNombre: j['receta_archivo_nombre'] ?? '',
      );
}

class Patient {
  final int id;
  final String nombre;
  final String email;
  final String telefono;
  final String historial;

  Patient({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.historial,
  });

  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
        id: j['id'],
        nombre: j['nombre'],
        email: j['email'],
        telefono: j['telefono'] ?? '',
        historial: j['historial_texto'] ?? '',
      );
}
