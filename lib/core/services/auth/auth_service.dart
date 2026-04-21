import 'dart:convert';
import 'dart:io';

import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const Duration _refreshFailureCooldown = Duration(seconds: 30);
  static Future<Map<String, dynamic>?>? _activeRefresh;
  static DateTime? _lastRefreshFailureAt;
  static String? _lastRefreshFailureMessage;
  static int? _lastRefreshFailureStatusCode;

  static String? get lastRefreshFailureMessage => _lastRefreshFailureMessage;
  static bool get hasInvalidSession => _lastRefreshFailureStatusCode == 401;

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'domain': 'https://asprounion.datorural.com',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = extractToken(data);
        final refreshToken = extractRefreshToken(data);
        final tokenExpires = extractTokenExpires(data);
        final userId = extractUserId(data);
        final userName = extractUserName(data);
        final userEmail = extractUserEmail(data);
        final roleName = extractRoleName(data);
        final companyName = extractCompanyName(data);
        if (token != null && token.trim().isNotEmpty) {
          await SessionService.saveSession(
            token: token,
            refreshToken: refreshToken,
            tokenExpires: tokenExpires,
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            roleName: roleName,
            companyName: companyName,
          );
        }

        return {
          'success': true,
          'data': data,
          'token': token,
          'refreshToken': refreshToken,
          'tokenExpires': tokenExpires,
          'userId': userId,
          'userName': userName,
          'userEmail': userEmail,
          'roleName': roleName,
          'companyName': companyName,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Error en login',
      };
    } catch (error) {
      return {
        'success': false,
        'message': _isNoConnectionError(error)
            ? 'En este momento no tienes conexion.'
            : 'No fue posible iniciar sesion.',
      };
    }
  }

  static Future<bool> ensureValidSession() async {
    if (!SessionService.canRestoreSession) {
      return false;
    }

    if (SessionService.isAuthenticated && !SessionService.isTokenExpired) {
      return true;
    }

    final refreshed = await refreshSession(force: true);
    return refreshed != null;
  }

  static Future<void> restoreSessionOnLaunch() async {
    if (!SessionService.hasRefreshToken) {
      return;
    }

    final token = SessionService.token;
    final shouldRefresh =
        token == null || token.trim().isEmpty || SessionService.isTokenExpired;

    if (!shouldRefresh) {
      return;
    }

    try {
      await refreshSession(force: true);
    } catch (_) {
      // Si no hay internet o el refresh falla, dejamos que la app siga
      // arrancando para mantener el flujo offline.
    }
  }

  static Future<Map<String, dynamic>?> refreshSession({
    bool force = false,
  }) async {
    if (_activeRefresh != null) {
      return _activeRefresh;
    }

    final lastFailureAt = _lastRefreshFailureAt;
    if (!force &&
        lastFailureAt != null &&
        DateTime.now().difference(lastFailureAt) < _refreshFailureCooldown) {
      return null;
    }

    final future = _performRefreshSession();
    _activeRefresh = future;

    try {
      return await future;
    } finally {
      if (identical(_activeRefresh, future)) {
        _activeRefresh = null;
      }
    }
  }

  static Future<Map<String, dynamic>?> _performRefreshSession() async {
    final refreshToken = SessionService.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      _registerRefreshFailure('No hay refresh token disponible.');
      return null;
    }

    try {
      final response = await _sendRefreshRequest(refreshToken);
      final dynamic data = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) {
          await _invalidateSession(
              'El backend rechazo el refresh token actual.');
        }
        _registerRefreshFailure(
          _extractFailureMessage(data, response.statusCode),
          statusCode: response.statusCode,
        );
        return null;
      }

      final newToken = extractToken(data);
      if (newToken == null || newToken.trim().isEmpty) {
        _registerRefreshFailure('El refresh respondio sin token nuevo.');
        return null;
      }

      _clearRefreshFailure();

      await SessionService.saveSession(
        token: newToken,
        refreshToken: extractRefreshToken(data) ?? refreshToken,
        tokenExpires: extractTokenExpires(data),
        userId: extractUserId(data) ?? SessionService.userId,
        userName: extractUserName(data) ?? SessionService.userName,
        userEmail: extractUserEmail(data) ?? SessionService.userEmail,
        roleName: extractRoleName(data) ?? SessionService.roleName,
        companyName: extractCompanyName(data) ?? SessionService.companyName,
      );

      return {
        'token': newToken,
        'refreshToken': extractRefreshToken(data) ?? refreshToken,
        'tokenExpires': extractTokenExpires(data),
        'userId': extractUserId(data) ?? SessionService.userId,
        'userName': extractUserName(data) ?? SessionService.userName,
        'userEmail': extractUserEmail(data) ?? SessionService.userEmail,
        'roleName': extractRoleName(data) ?? SessionService.roleName,
        'companyName': extractCompanyName(data) ?? SessionService.companyName,
        'data': data,
      };
    } catch (error) {
      _registerRefreshFailure(
        _isNoConnectionError(error)
            ? 'En este momento no tienes conexion.'
            : 'No se pudo renovar la sesion: $error',
        useCooldown: !_isNoConnectionError(error),
      );
      return null;
    }
  }

  static Future<http.Response> _sendRefreshRequest(String refreshToken) async {
    final accessToken = SessionService.token;
    final attempts = <Map<String, dynamic>>[
      {
        'label': 'bearer-refresh-token-no-body',
        'headers': _buildRefreshHeaders(
          authorizationToken: refreshToken,
        ),
      },
      {
        'label': 'bearer-refresh-token-empty-json',
        'headers': _buildRefreshHeaders(
          authorizationToken: refreshToken,
        ),
        'body': <String, dynamic>{},
      },
      {
        'label': 'bearer-refresh-token-body-refresh-token',
        'headers': _buildRefreshHeaders(
          authorizationToken: refreshToken,
        ),
        'body': {
          'refreshToken': refreshToken,
        },
      },
      {
        'label': 'body-refresh-token',
        'headers': _buildRefreshHeaders(),
        'body': {
          'refreshToken': refreshToken,
        },
      },
      {
        'label': 'body-refresh-token-with-bearer',
        'headers': _buildRefreshHeaders(
          authorizationToken: accessToken,
        ),
        'body': {
          'refreshToken': refreshToken,
        },
      },
      {
        'label': 'body-token-field',
        'headers': _buildRefreshHeaders(
          authorizationToken: accessToken,
        ),
        'body': {
          'token': refreshToken,
        },
      },
      {
        'label': 'body-refresh-token-and-access-token',
        'headers': _buildRefreshHeaders(
          authorizationToken: accessToken,
        ),
        'body': {
          'refreshToken': refreshToken,
          if (accessToken != null && accessToken.trim().isNotEmpty)
            'token': accessToken,
        },
      },
    ];

    http.Response? lastResponse;

    for (final attempt in attempts) {
      final headers =
          Map<String, String>.from(attempt['headers'] as Map<String, String>);
      final rawBody = attempt['body'];
      final Map<String, dynamic>? body = rawBody is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawBody)
          : null;

      if (kDebugMode) {
        debugPrint(
          '[AUTH REFRESH REQUEST] ${attempt['label']} ${ApiConfig.refresh}\n'
          'headers: ${_sanitizeHeaders(headers)}\n'
          'body: ${body == null ? '-' : jsonEncode(_sanitizeRefreshBody(body))}',
        );
      }

      final response = body == null
          ? await http.post(
              Uri.parse(ApiConfig.refresh),
              headers: headers,
            )
          : await http.post(
              Uri.parse(ApiConfig.refresh),
              headers: headers,
              body: jsonEncode(body),
            );

      if (kDebugMode) {
        debugPrint(
          '[AUTH REFRESH RESPONSE] ${attempt['label']} ${ApiConfig.refresh}\n'
          'status: ${response.statusCode}\n'
          'body: ${response.body}',
        );
      }

      lastResponse = response;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      if (response.statusCode != 401) {
        return response;
      }
    }

    return lastResponse ??
        http.Response(
          jsonEncode({'message': 'No se pudo ejecutar el refresh.'}),
          500,
        );
  }

  static Map<String, String> _buildRefreshHeaders({
    String? authorizationToken,
  }) {
    final headers = <String, String>{
      'accept': '*/*',
      'Content-Type': 'application/json',
    };

    final token = authorizationToken;
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final safe = Map<String, String>.from(headers);
    if (safe.containsKey('Authorization')) {
      safe['Authorization'] = 'Bearer ***';
    }
    return safe;
  }

  static Map<String, dynamic> _sanitizeRefreshBody(Map<String, dynamic> body) {
    final safe = Map<String, dynamic>.from(body);
    if (safe.containsKey('refreshToken')) {
      safe['refreshToken'] = '***';
    }
    if (safe.containsKey('token')) {
      safe['token'] = '***';
    }
    return safe;
  }

  static String _extractFailureMessage(dynamic data, int statusCode) {
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return 'Refresh fallido con estado HTTP $statusCode.';
  }

  static void _registerRefreshFailure(
    String message, {
    bool useCooldown = true,
    int? statusCode,
  }) {
    _lastRefreshFailureAt = useCooldown ? DateTime.now() : null;
    _lastRefreshFailureMessage = message;
    _lastRefreshFailureStatusCode = statusCode;
    if (kDebugMode) {
      debugPrint('[AUTH REFRESH FAIL] $message');
    }
  }

  static void _clearRefreshFailure() {
    _lastRefreshFailureAt = null;
    _lastRefreshFailureMessage = null;
    _lastRefreshFailureStatusCode = null;
  }

  static Future<void> _invalidateSession(String reason) async {
    if (kDebugMode) {
      debugPrint('[AUTH INVALIDATE] $reason');
    }
    await SessionService.clear();
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

  static String? extractToken(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : null;

    final candidates = [
      data['token'],
      data['accessToken'],
      data['access_token'],
      data['jwt'],
      data['authToken'],
      nestedData?['token'],
      nestedData?['accessToken'],
      nestedData?['access_token'],
    ];

    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  static String? extractRefreshToken(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : null;

    final candidates = [
      data['refreshToken'],
      data['refresh_token'],
      nestedData?['refreshToken'],
      nestedData?['refresh_token'],
    ];

    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  static int? extractTokenExpires(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : null;

    final candidates = [
      data['tokenExpires'],
      data['token_expires'],
      data['expiresAt'],
      nestedData?['tokenExpires'],
      nestedData?['token_expires'],
      nestedData?['expiresAt'],
    ];

    for (final value in candidates) {
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    final token = extractToken(data);
    if (token != null) {
      return _extractJwtExpiry(token);
    }

    return null;
  }

  static int? _extractJwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final normalized = base64.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final exp = decoded['exp'];
      if (exp is int) {
        return exp * 1000;
      }
      if (exp is String) {
        final parsed = int.tryParse(exp);
        if (parsed != null) {
          return parsed * 1000;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static int? extractUserId(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : null;
    final nestedUserData = nestedData?['user'];
    final nestedUser =
        nestedUserData is Map<String, dynamic> ? nestedUserData : null;
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : null;

    final candidates = [
      user?['id'],
      nestedUser?['id'],
      data['userId'],
      nestedData?['userId'],
    ];

    for (final value in candidates) {
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  static String? extractUserName(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : null;
    final nestedUserData = nestedData?['user'];
    final nestedUser =
        nestedUserData is Map<String, dynamic> ? nestedUserData : null;
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : null;

    final candidates = [
      user?['fullName'],
      user?['name'],
      user?['firstName'],
      user?['username'],
      nestedUser?['fullName'],
      nestedUser?['name'],
      nestedUser?['firstName'],
      nestedUser?['username'],
      data['userName'],
      nestedData?['userName'],
    ];

    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static String? extractUserEmail(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : null;
    final nestedUserData = nestedData?['user'];
    final nestedUser =
        nestedUserData is Map<String, dynamic> ? nestedUserData : null;
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : null;

    final candidates = [
      user?['email'],
      nestedUser?['email'],
      data['email'],
      nestedData?['email'],
    ];

    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static String? extractRoleName(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : null;
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : null;
    final nestedUserData = nestedData?['user'];
    final nestedUser =
        nestedUserData is Map<String, dynamic> ? nestedUserData : null;

    final roleCandidates = [
      user?['role'],
      nestedUser?['role'],
      data['role'],
      nestedData?['role'],
    ];

    for (final role in roleCandidates) {
      if (role is Map<String, dynamic>) {
        final name = role['name'];
        if (name is String && name.trim().isNotEmpty) {
          return name.trim();
        }
      }
    }

    return null;
  }

  static String? extractCompanyName(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : null;
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : null;
    final nestedUserData = nestedData?['user'];
    final nestedUser =
        nestedUserData is Map<String, dynamic> ? nestedUserData : null;

    final roleCandidates = [
      user?['role'],
      nestedUser?['role'],
      data['role'],
      nestedData?['role'],
    ];

    for (final role in roleCandidates) {
      if (role is Map<String, dynamic>) {
        final company = role['company'];
        if (company is Map<String, dynamic>) {
          final name = company['name'];
          if (name is String && name.trim().isNotEmpty) {
            return name.trim();
          }
        }
      }
    }

    final companyCandidates = [
      data['company'],
      nestedData?['company'],
    ];

    for (final company in companyCandidates) {
      if (company is Map<String, dynamic>) {
        final name = company['name'];
        if (name is String && name.trim().isNotEmpty) {
          return name.trim();
        }
      }
    }

    return null;
  }
}
