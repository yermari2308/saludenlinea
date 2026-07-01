import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'doh_client.dart';

class ApiService {
  static const String baseUrl = 'https://saludenlinea-production.up.railway.app';

  // ── Token ────────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token, String role,
      {int userId = 0, String nombre = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', role);
    await prefs.setInt('user_id', userId);
    if (nombre.isNotEmpty) await prefs.setString('nombre', nombre);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('user_id');
    await prefs.remove('nombre');
  }

  static Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'role': prefs.getString('role') ?? 'paciente',
      'id': prefs.getInt('user_id') ?? 0,
      'nombre': prefs.getString('nombre') ?? '',
    };
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> registerPatient({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    final res = await DohClient.post(
      '$baseUrl/api/register/patient',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'email': email,
        'password': password,
        if (telefono != null) 'telefono': telefono,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await DohClient.post(
      '$baseUrl/api/login',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  static Future<void> forgotPassword(String email) async {
    final res = await DohClient.post(
      '$baseUrl/api/auth/forgot-password',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    _parse(res);
  }

  static Future<void> resetPassword({required String token, required String newPassword}) async {
    final res = await DohClient.post(
      '$baseUrl/api/auth/reset-password',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> loginWithGoogleToken(String idToken) async {
    final res = await DohClient.post(
      '$baseUrl/api/auth/google/mobile',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    return _parse(res);
  }

  // ── Doctors ───────────────────────────────────────────────────────────────

  static Future<List<Doctor>> getDoctors({String? especialidad}) async {
    final params = especialidad != null ? '?especialidad=$especialidad' : '';
    final res = await DohClient.get(
      '$baseUrl/api/doctors$params',
      headers: await _headers(),
    );
    final data = _parse(res) as List;
    return data.map((e) => Doctor.fromJson(e)).toList();
  }

  static Future<Doctor> getDoctor(int id) async {
    final res = await DohClient.get(
      '$baseUrl/api/doctors/$id',
      headers: await _headers(),
    );
    return Doctor.fromJson(_parse(res));
  }

  // ── Appointments ──────────────────────────────────────────────────────────

  static Future<Appointment> createAppointment({
    required int doctorId,
    required DateTime fechaHora,
    String metodoPago = 'tarjeta',
  }) async {
    final res = await DohClient.post(
      '$baseUrl/api/appointments',
      headers: await _headers(),
      body: jsonEncode({
        'doctor_id': doctorId,
        'fecha_hora': fechaHora.toIso8601String(),
        'metodo_pago': metodoPago,
      }),
    );
    return Appointment.fromJson(_parse(res));
  }

  static Future<List<Appointment>> getAppointments() async {
    final res = await DohClient.get(
      '$baseUrl/api/appointments',
      headers: await _headers(),
    );
    final data = _parse(res) as List;
    return data.map((e) => Appointment.fromJson(e)).toList();
  }

  static Future<void> cancelAppointment(int id) async {
    final res = await DohClient.post(
      '$baseUrl/api/cancel/$id',
      headers: await _headers(),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> getConsultSession(int appointmentId) async {
    final res = await DohClient.get(
      '$baseUrl/api/consultation/$appointmentId',
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getReceta(int appointmentId) async {
    final res = await DohClient.get(
      '$baseUrl/api/receta/$appointmentId',
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<void> finalizarCita(int appointmentId) async {
    final res = await DohClient.post(
      '$baseUrl/api/appointments/$appointmentId/finalizar',
      headers: await _headers(),
    );
    _parse(res);
  }

  static Future<Appointment> reagendarCita(int appointmentId, DateTime nuevaFecha) async {
    final res = await DohClient.put(
      '$baseUrl/api/appointments/$appointmentId/reagendar',
      headers: await _headers(),
      body: jsonEncode({'fecha_hora': nuevaFecha.toIso8601String()}),
    );
    return Appointment.fromJson(_parse(res));
  }

  static Future<void> subirRecetaArchivo(int appointmentId, Uint8List bytes, String nombre) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/api/appointments/$appointmentId/receta-archivo');
    final req = http.MultipartRequest('POST', uri);
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('archivo', bytes, filename: nombre));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _parse(res);
  }

  static Future<Uint8List> descargarRecetaArchivo(int appointmentId) async {
    final res = await DohClient.get(
      '$baseUrl/api/appointments/$appointmentId/receta-archivo',
      headers: await _headers(),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw ApiException(body['detail'] ?? 'Error', res.statusCode);
    }
    return res.bodyBytes;
  }

  // ── Doctor Leads ─────────────────────────────────────────────────────────

  static Future<void> submitDoctorLead({
    required String nombre,
    required String especialidad,
    required String email,
    required String telefono,
    required String pais,
    required String credenciales,
    required int anosExperiencia,
    required String mensaje,
  }) async {
    final res = await DohClient.post(
      '$baseUrl/api/leads',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'especialidad': especialidad,
        'email': email,
        'telefono': telefono,
        'pais': pais,
        'credenciales': credenciales,
        'anos_experiencia': anosExperiencia,
        'mensaje': mensaje,
      }),
    );
    _parse(res);
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createPaymentPreference(int appointmentId) async {
    final res = await DohClient.post(
      '$baseUrl/api/payments/preference',
      headers: await _headers(),
      body: jsonEncode({'appointment_id': appointmentId}),
    );
    return _parse(res);
  }

  // ── Urgent Queue (Botón Rojo) ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> joinUrgentQueue({
    String especialidad = 'medicina_general',
  }) async {
    final res = await DohClient.post(
      '$baseUrl/api/urgent/join',
      headers: await _headers(),
      body: jsonEncode({'especialidad': especialidad}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getUrgentStatus() async {
    final res = await DohClient.get(
      '$baseUrl/api/urgent/status',
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<void> cancelUrgentQueue() async {
    final res = await DohClient.post(
      '$baseUrl/api/urgent/cancel',
      headers: await _headers(),
    );
    _parse(res);
  }

  static Future<List<Map<String, dynamic>>> getUrgentQueue() async {
    final res = await DohClient.get(
      '$baseUrl/api/urgent/queue',
      headers: await _headers(),
    );
    final data = _parse(res) as List;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> takeUrgentPatient(int queueId) async {
    final res = await DohClient.post(
      '$baseUrl/api/urgent/take/$queueId',
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<void> toggleDisponibleUrgente(bool disponible) async {
    final res = await DohClient.post(
      '$baseUrl/api/urgent/toggle-disponible',
      headers: await _headers(),
      body: jsonEncode({'disponible': disponible}),
    );
    _parse(res);
  }

  static Future<bool> getDisponibleUrgente() async {
    final res = await DohClient.get(
      '$baseUrl/api/urgent/my-status',
      headers: await _headers(),
    );
    final data = _parse(res);
    return data['disponible_urgente'] as bool;
  }

  // ── HRA — Evaluación de salud ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> submitHra({
    double? pesoKg,
    double? alturaM,
    double? suenoHoras,
    String? tabaco,
    String? alcohol,
    String? ejercicio,
    double? saturacionPct,
  }) async {
    final res = await DohClient.post(
      '$baseUrl/api/hra',
      headers: await _headers(),
      body: jsonEncode({
        if (pesoKg != null) 'peso_kg': pesoKg,
        if (alturaM != null) 'altura_m': alturaM,
        if (suenoHoras != null) 'sueno_horas': suenoHoras,
        if (tabaco != null) 'tabaco': tabaco,
        if (alcohol != null) 'alcohol': alcohol,
        if (ejercicio != null) 'ejercicio': ejercicio,
        if (saturacionPct != null) 'saturacion_pct': saturacionPct,
      }),
    );
    return _parse(res);
  }

  static Future<List<Map<String, dynamic>>> getHraHistory() async {
    final res = await DohClient.get(
      '$baseUrl/api/hra/history',
      headers: await _headers(),
    );
    final data = _parse(res) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ── Expediente Clínico ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMedicalRecord() async {
    final res = await DohClient.get(
      '$baseUrl/api/medical-record/me',
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateMedicalSection({
    required String seccion,
    required dynamic datos,
  }) async {
    final res = await DohClient.put(
      '$baseUrl/api/medical-record/me',
      headers: await _headers(),
      body: jsonEncode({'seccion': seccion, 'datos': datos}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getPatientMedicalRecord(int pacienteId) async {
    final res = await DohClient.get(
      '$baseUrl/api/medical-record/patient/$pacienteId',
      headers: await _headers(),
    );
    return _parse(res);
  }

  // ── Patient ───────────────────────────────────────────────────────────────

  static Future<Patient> getMyProfile() async {
    final res = await DohClient.get(
      '$baseUrl/api/patients/me',
      headers: await _headers(),
    );
    return Patient.fromJson(_parse(res));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static dynamic _parse(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      throw ApiException(body['detail'] ?? 'Error desconocido', res.statusCode);
    }
    return body;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
