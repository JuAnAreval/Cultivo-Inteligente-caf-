import 'dart:convert';

import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/auth_service.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:http/http.dart' as http;

class HttpClient {
  static Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-workspace-id': ApiConfig.workspaceId,
      ...?extra,
    };

    final token = SessionService.token;
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Future<Map<String, dynamic>> get(String url) async {
    await _ensureToken();
    final response = await http.get(Uri.parse(url), headers: _headers());
    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retry = await http.get(Uri.parse(url), headers: _headers());
      return _handleResponse(retry);
    }
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    await _ensureToken();
    final response = await http.post(
      Uri.parse(url),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retry = await http.post(
        Uri.parse(url),
        headers: _headers(),
        body: jsonEncode(body),
      );
      return _handleResponse(retry);
    }
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> patch(
    String url,
    Map<String, dynamic> body,
  ) async {
    await _ensureToken();
    final response = await http.patch(
      Uri.parse(url),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retry = await http.patch(
        Uri.parse(url),
        headers: _headers(),
        body: jsonEncode(body),
      );
      return _handleResponse(retry);
    }
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(String url) async {
    await _ensureToken();
    final response = await http.delete(Uri.parse(url), headers: _headers());
    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retry = await http.delete(Uri.parse(url), headers: _headers());
      return _handleResponse(retry);
    }
    return _handleResponse(response);
  }

  static Future<void> _ensureToken() async {
    if (SessionService.hasRefreshToken && SessionService.isTokenExpired) {
      await AuthService.refreshSession();
    }
  }

  static Future<bool> _tryRefreshToken() async {
    final refreshed = await AuthService.refreshSession();
    return refreshed != null;
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final rawBody = response.body.trim();
    final decoded = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw Exception(
      decoded['message'] ??
          decoded['error'] ??
          'Error HTTP ${response.statusCode}',
    );
  }
}
