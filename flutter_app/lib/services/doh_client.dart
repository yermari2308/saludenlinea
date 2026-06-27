import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Cliente HTTP que resuelve DNS via Google DoH (HTTPS) para evitar
/// bloqueos de ISP/operadores que interceptan DNS estándar.
class DohClient {
  static const String _hostname = 'saludenlinea-production.up.railway.app';
  static String? _cachedIp;

  // Resuelve el hostname usando DNS-over-HTTPS de Google (puerto 443, imposible de bloquear sin romper Google)
  static Future<String?> _resolveIp() async {
    if (_cachedIp != null) return _cachedIp;
    final dohProviders = [
      'https://dns.google/resolve?name=$_hostname&type=A',
      'https://1.1.1.1/dns-query?name=$_hostname&type=A',
    ];
    for (final url in dohProviders) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/dns-json'},
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final answers = data['Answer'] as List?;
          if (answers != null) {
            for (final a in answers) {
              if (a['type'] == 1) {
                _cachedIp = a['data'] as String;
                return _cachedIp;
              }
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static http.Client _buildClient() {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) => true;
    httpClient.connectionTimeout = const Duration(seconds: 15);
    return IOClient(httpClient);
  }

  static Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    final ip = await _resolveIp();
    if (ip != null) {
      final uri = Uri.parse(url.replaceFirst(_hostname, ip));
      final h = {'Host': _hostname, 'Connection': 'keep-alive', ...?headers};
      try {
        return await _buildClient().get(uri, headers: h).timeout(const Duration(seconds: 20));
      } catch (_) {}
    }
    return await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));
  }

  static Future<http.Response> post(String url, {Map<String, String>? headers, Object? body}) async {
    final ip = await _resolveIp();
    if (ip != null) {
      final uri = Uri.parse(url.replaceFirst(_hostname, ip));
      final h = {'Host': _hostname, 'Connection': 'keep-alive', ...?headers};
      try {
        return await _buildClient().post(uri, headers: h, body: body).timeout(const Duration(seconds: 20));
      } catch (_) {}
    }
    return await http.post(Uri.parse(url), headers: headers, body: body).timeout(const Duration(seconds: 20));
  }

  static Future<http.Response> put(String url, {Map<String, String>? headers, Object? body}) async {
    final ip = await _resolveIp();
    if (ip != null) {
      final uri = Uri.parse(url.replaceFirst(_hostname, ip));
      final h = {'Host': _hostname, 'Connection': 'keep-alive', ...?headers};
      try {
        return await _buildClient().put(uri, headers: h, body: body).timeout(const Duration(seconds: 20));
      } catch (_) {}
    }
    return await http.put(Uri.parse(url), headers: headers, body: body).timeout(const Duration(seconds: 20));
  }

  static Future<http.Response> delete(String url, {Map<String, String>? headers}) async {
    final ip = await _resolveIp();
    if (ip != null) {
      final uri = Uri.parse(url.replaceFirst(_hostname, ip));
      final h = {'Host': _hostname, 'Connection': 'keep-alive', ...?headers};
      try {
        return await _buildClient().delete(uri, headers: h).timeout(const Duration(seconds: 20));
      } catch (_) {}
    }
    return await http.delete(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));
  }

  // Para WebSocket: resuelve IP y devuelve URI con IP para conectarse
  static Future<Uri> resolveWsUri(Uri wsUri) async {
    final ip = await _resolveIp();
    if (ip != null) {
      return wsUri.replace(host: ip);
    }
    return wsUri;
  }
}
