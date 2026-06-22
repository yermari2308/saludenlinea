import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'https://side-variations-suggest-reservations.trycloudflare.com';

  // ── Token ────────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token, String role, {int userId = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', role);
    await prefs.setInt('user_id', userId);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('user_id');
  }

  static Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'role': prefs.getString('role') ?? 'paciente',
      'id': prefs.getInt('user_id') ?? 0,
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
    final res = await http.post(
      Uri.parse('$baseUrl/api/register/patient'),
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
    final res = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  // ── Doctors ───────────────────────────────────────────────────────────────

  static Future<List<Doctor>> getDoctors({String? especialidad}) async {
    final params = especialidad != null ? '?especialidad=$especialidad' : '';
    final res = await http.get(
      Uri.parse('$baseUrl/api/doctors$params'),
      headers: await _headers(),
    );
    final data = _parse(res) as List;
    return data.map((e) => Doctor.fromJson(e)).toList();
  }

  static Future<Doctor> getDoctor(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/doctors/$id'),
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
    final res = await http.post(
      Uri.parse('$baseUrl/api/appointments'),
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
    final res = await http.get(
      Uri.parse('$baseUrl/api/appointments'),
      headers: await _headers(),
    );
    final data = _parse(res) as List;
    return data.map((e) => Appointment.fromJson(e)).toList();
  }

  static Future<void> cancelAppointment(int id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/cancel/$id'),
      headers: await _headers(),
    );
    _parse(res);
  }

  static Future<Map<String, dynamic>> getConsultSession(int appointmentId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/consultation/$appointmentId'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getReceta(int appointmentId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/receta/$appointmentId'),
      headers: await _headers(),
    );
    return _parse(res);
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
    final res = await http.post(
      Uri.parse('$baseUrl/api/leads'),
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
    final res = await http.post(
      Uri.parse('$baseUrl/api/payments/preference'),
      headers: await _headers(),
      body: jsonEncode({'appointment_id': appointmentId}),
    );
    return _parse(res);
  }

  // ── Patient ───────────────────────────────────────────────────────────────

  static Future<Patient> getMyProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/patients/me'),
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
