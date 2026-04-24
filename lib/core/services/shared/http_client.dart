import 'dart:convert';
import 'dart:io';

import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/auth_service.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HttpClient {
  static Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'accept': '*/*',
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
    final headers = _headers();
    _logRequest(method: 'GET', url: url, headers: headers);

    final response = await _guardRequest(
      () => http.get(Uri.parse(url), headers: headers),
    );
    _logResponse(method: 'GET', url: url, response: response);

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retryHeaders = _headers();
      _logRequest(
        method: 'GET',
        url: url,
        headers: retryHeaders,
        isRetry: true,
      );
      final retry = await _guardRequest(
        () => http.get(Uri.parse(url), headers: retryHeaders),
      );
      _logResponse(
        method: 'GET',
        url: url,
        response: retry,
        isRetry: true,
      );
      return _handleResponse(
        retry,
        method: 'GET',
        url: url,
      );
    }

    return _handleResponse(
      response,
      method: 'GET',
      url: url,
    );
  }

  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    await _ensureToken();
    final headers = _headers();
    _logRequest(
      method: 'POST',
      url: url,
      headers: headers,
      body: body,
    );

    final response = await _guardRequest(
      () => http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
    _logResponse(
      method: 'POST',
      url: url,
      response: response,
      body: body,
    );

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retryHeaders = _headers();
      _logRequest(
        method: 'POST',
        url: url,
        headers: retryHeaders,
        body: body,
        isRetry: true,
      );
      final retry = await _guardRequest(
        () => http.post(
          Uri.parse(url),
          headers: retryHeaders,
          body: jsonEncode(body),
        ),
      );
      _logResponse(
        method: 'POST',
        url: url,
        response: retry,
        body: body,
        isRetry: true,
      );
      return _handleResponse(
        retry,
        method: 'POST',
        url: url,
        requestBody: body,
      );
    }

    return _handleResponse(
      response,
      method: 'POST',
      url: url,
      requestBody: body,
    );
  }

  static Future<Map<String, dynamic>> patch(
    String url,
    Map<String, dynamic> body,
  ) async {
    await _ensureToken();
    final headers = _headers();
    _logRequest(
      method: 'PATCH',
      url: url,
      headers: headers,
      body: body,
    );

    final response = await _guardRequest(
      () => http.patch(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
    _logResponse(
      method: 'PATCH',
      url: url,
      response: response,
      body: body,
    );

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retryHeaders = _headers();
      _logRequest(
        method: 'PATCH',
        url: url,
        headers: retryHeaders,
        body: body,
        isRetry: true,
      );
      final retry = await _guardRequest(
        () => http.patch(
          Uri.parse(url),
          headers: retryHeaders,
          body: jsonEncode(body),
        ),
      );
      _logResponse(
        method: 'PATCH',
        url: url,
        response: retry,
        body: body,
        isRetry: true,
      );
      return _handleResponse(
        retry,
        method: 'PATCH',
        url: url,
        requestBody: body,
      );
    }

    return _handleResponse(
      response,
      method: 'PATCH',
      url: url,
      requestBody: body,
    );
  }

  static Future<Map<String, dynamic>> put(
    String url,
    Map<String, dynamic> body,
  ) async {
    await _ensureToken();
    final headers = _headers();
    _logRequest(
      method: 'PUT',
      url: url,
      headers: headers,
      body: body,
    );

    final response = await _guardRequest(
      () => http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
    _logResponse(
      method: 'PUT',
      url: url,
      response: response,
      body: body,
    );

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retryHeaders = _headers();
      _logRequest(
        method: 'PUT',
        url: url,
        headers: retryHeaders,
        body: body,
        isRetry: true,
      );
      final retry = await _guardRequest(
        () => http.put(
          Uri.parse(url),
          headers: retryHeaders,
          body: jsonEncode(body),
        ),
      );
      _logResponse(
        method: 'PUT',
        url: url,
        response: retry,
        body: body,
        isRetry: true,
      );
      return _handleResponse(
        retry,
        method: 'PUT',
        url: url,
        requestBody: body,
      );
    }

    return _handleResponse(
      response,
      method: 'PUT',
      url: url,
      requestBody: body,
    );
  }

  static Future<Map<String, dynamic>> delete(String url) async {
    await _ensureToken();
    final headers = _headers();
    _logRequest(method: 'DELETE', url: url, headers: headers);

    final response = await _guardRequest(
      () => http.delete(Uri.parse(url), headers: headers),
    );
    _logResponse(method: 'DELETE', url: url, response: response);

    if (response.statusCode == 401 && await _tryRefreshToken()) {
      final retryHeaders = _headers();
      _logRequest(
        method: 'DELETE',
        url: url,
        headers: retryHeaders,
        isRetry: true,
      );
      final retry = await _guardRequest(
        () => http.delete(Uri.parse(url), headers: retryHeaders),
      );
      _logResponse(
        method: 'DELETE',
        url: url,
        response: retry,
        isRetry: true,
      );
      return _handleResponse(
        retry,
        method: 'DELETE',
        url: url,
      );
    }

    return _handleResponse(
      response,
      method: 'DELETE',
      url: url,
    );
  }

  static Future<void> _ensureToken() async {
    final token = SessionService.token;
    final shouldRefresh =
        token == null || token.trim().isEmpty || SessionService.isTokenExpired;

    if (!shouldRefresh) {
      return;
    }

    if (!SessionService.hasRefreshToken) {
      throw SessionUnavailableException(
        'La sesión venció y no hay refresh token disponible. Tus datos siguen guardados localmente.',
      );
    }

    final refreshed = await AuthService.refreshSession(force: true);
    if (refreshed == null) {
      final reason = AuthService.lastRefreshFailureMessage;
      throw SessionUnavailableException(
        reason == null || reason.trim().isEmpty
            ? 'No se pudo renovar la sesión para sincronizar. Tus datos siguen guardados localmente.'
            : 'No se pudo renovar la sesión para sincronizar: $reason',
      );
    }
  }

  static Future<bool> _tryRefreshToken() async {
    await SessionService.markTokenExpired();
    final refreshed = await AuthService.refreshSession(force: true);
    return refreshed != null;
  }

  static Future<http.Response> _guardRequest(
    Future<http.Response> Function() action,
  ) async {
    try {
      return await action();
    } catch (error) {
      if (_isNoConnectionError(error)) {
        throw NoConnectionException('En este momento no tienes conexión.');
      }
      rethrow;
    }
  }

  static Map<String, dynamic> _handleResponse(
    http.Response response, {
    required String method,
    required String url,
    Map<String, dynamic>? requestBody,
  }) {
    final rawBody = response.body.trim();
    final decoded = _decodeResponseBody(rawBody);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {
        'data': decoded,
      };
    }

    throw ApiRequestException(
      method: method,
      url: url,
      statusCode: response.statusCode,
      requestBody: requestBody,
      responseBody: rawBody,
      message: _extractErrorMessage(decoded, response.statusCode),
    );
  }

  static dynamic _decodeResponseBody(String rawBody) {
    if (rawBody.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return rawBody;
    }
  }

  static String _extractErrorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      final message =
          decoded['message'] ?? decoded['error'] ?? decoded['detail'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }

    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded;
    }

    return 'Error HTTP $statusCode';
  }

  static void _logRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[HTTP ${isRetry ? 'RETRY ' : ''}REQUEST] $method $url\n'
      'headers: ${_sanitizeHeaders(headers)}\n'
      'body: ${body == null ? '-' : jsonEncode(body)}',
    );
  }

  static void _logResponse({
    required String method,
    required String url,
    required http.Response response,
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[HTTP ${isRetry ? 'RETRY ' : ''}RESPONSE] $method $url\n'
      'status: ${response.statusCode}\n'
      'requestBody: ${body == null ? '-' : jsonEncode(body)}\n'
      'responseBody: ${response.body}',
    );
  }

  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final safe = Map<String, String>.from(headers);
    if (safe.containsKey('Authorization')) {
      safe['Authorization'] = 'Bearer ***';
    }
    return safe;
  }

  static bool _isNoConnectionError(Object error) {
    if (error is SocketException) {
      return true;
    }

    if (error is http.ClientException) {
      final message = error.message.toLowerCase();
      return message.contains('socketexception') ||
          message.contains('failed host lookup') ||
          message.contains('connection refused') ||
          message.contains('network is unreachable') ||
          message.contains('connection closed before full header was received');
    }

    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('network is unreachable');
  }
}

class ApiRequestException implements Exception {
  ApiRequestException({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.message,
    this.requestBody,
    this.responseBody,
  });

  final String method;
  final String url;
  final int statusCode;
  final String message;
  final Map<String, dynamic>? requestBody;
  final String? responseBody;

  @override
  String toString() {
    final requestBodyText = requestBody == null ? '-' : jsonEncode(requestBody);
    final responseText = responseBody == null || responseBody!.trim().isEmpty
        ? '-'
        : responseBody!;
    return 'ApiRequestException('
        'method: $method, '
        'statusCode: $statusCode, '
        'url: $url, '
        'message: $message, '
        'requestBody: $requestBodyText, '
        'responseBody: $responseText'
        ')';
  }
}

class SessionUnavailableException implements Exception {
  SessionUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'SessionUnavailableException(message: $message)';
}

class NoConnectionException implements Exception {
  NoConnectionException(this.message);

  final String message;

  @override
  String toString() => 'NoConnectionException(message: $message)';
}
