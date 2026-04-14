import 'dart:convert';

import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
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
      if (token != null && token.trim().isNotEmpty) {
        await SessionService.saveSession(
          token: token,
          refreshToken: refreshToken,
          tokenExpires: tokenExpires,
          userId: userId,
          userName: userName,
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
      };
    }

    return {
      'success': false,
      'message': data['message'] ?? 'Error en login',
    };
  }

  static Future<bool> ensureValidSession() async {
    if (!SessionService.canRestoreSession) {
      return false;
    }

    if (SessionService.isAuthenticated && !SessionService.isTokenExpired) {
      return true;
    }

    final refreshed = await refreshSession();
    return refreshed != null;
  }

  static Future<Map<String, dynamic>?> refreshSession() async {
    final refreshToken = SessionService.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      return null;
    }

    final response = await http.post(
      Uri.parse(ApiConfig.refresh),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'refreshToken': refreshToken,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await SessionService.clear();
      return null;
    }

    final newToken = extractToken(data);
    if (newToken == null || newToken.trim().isEmpty) {
      await SessionService.clear();
      return null;
    }

    await SessionService.saveSession(
      token: newToken,
      refreshToken: extractRefreshToken(data) ?? refreshToken,
      tokenExpires: extractTokenExpires(data),
      userId: extractUserId(data) ?? SessionService.userId,
      userName: extractUserName(data) ?? SessionService.userName,
    );

    return {
      'token': newToken,
      'refreshToken': extractRefreshToken(data) ?? refreshToken,
      'tokenExpires': extractTokenExpires(data),
      'userId': extractUserId(data) ?? SessionService.userId,
      'userName': extractUserName(data) ?? SessionService.userName,
      'data': data,
    };
  }

  static String? extractToken(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData =
        data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : null;

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

    final nestedData =
        data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : null;

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

    final nestedData =
        data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : null;

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

    return null;
  }

  static int? extractUserId(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final nestedData =
        data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : null;
    final nestedUserData = nestedData?['user'];
    final nestedUser =
        nestedUserData is Map<String, dynamic> ? nestedUserData : null;
    final user =
        data['user'] is Map<String, dynamic> ? data['user'] as Map<String, dynamic> : null;

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

    final nestedData =
        data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : null;
    final nestedUserData = nestedData?['user'];
    final nestedUser =
        nestedUserData is Map<String, dynamic> ? nestedUserData : null;
    final user =
        data['user'] is Map<String, dynamic> ? data['user'] as Map<String, dynamic> : null;

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
}
