import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => message;
}

class ToviApi {
  ToviApi({required this.base, required this.token, this.onUnauthorized});

  final String base;
  final String token;
  final void Function()? onUnauthorized;

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);

  Future<dynamic> put(String path, Object body) => _send('PUT', path, body);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$base$path'));
    if (token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 204) return null;
    final data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final map = data is Map ? data : const {};
      if (response.statusCode == 401) onUnauthorized?.call();
      throw ApiException(response.statusCode, '${map['error'] ?? 'error'}', '${map['message'] ?? 'Request failed'}');
    }
    return data;
  }
}
