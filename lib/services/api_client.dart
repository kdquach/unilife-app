import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Automatically select base URL suitable for the environment:
  ///   - Web (Chrome)        → http://localhost:5000/api/v1
  ///   - Android Emulator    → http://10.0.2.2:5000/api/v1
  ///   - Can be overridden via --dart-define=API_BASE_URL=...
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return kIsWeb
        ? 'http://localhost:5000/api/v1'
        : 'http://10.0.2.2:5000/api/v1';
  }

  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body, {String? token}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body, {String? token}) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadFile(
    String path,
    String fieldName,
    String filePath, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    final extension = filePath.split('.').last.toLowerCase();
    MediaType contentType;
    if (extension == 'png') {
      contentType = MediaType('image', 'png');
    } else if (extension == 'webp') {
      contentType = MediaType('image', 'webp');
    } else if (extension == 'gif') {
      contentType = MediaType('image', 'gif');
    } else {
      contentType = MediaType('image', 'jpeg');
    }

    final file = await http.MultipartFile.fromPath(
      fieldName,
      filePath,
      contentType: contentType,
    );
    request.files.add(file);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);
    if (response.statusCode >= 400) {
      throw ApiException(
        statusCode: response.statusCode,
        message: decoded is Map<String, dynamic> ? (decoded['message']?.toString() ?? 'Request failed') : 'Request failed',
      );
    }
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
