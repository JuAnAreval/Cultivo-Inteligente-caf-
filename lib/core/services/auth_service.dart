import 'dart:convert';

import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/session_service.dart';
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
      final token = _extractToken(data);
      final userId = _extractUserId(data);
      if (token != null && token.trim().isNotEmpty) {
        await SessionService.saveSession(token: token, userId: userId);
      }

      return {
        'success': true,
        'data': data,
        'token': token,
        'userId': userId,
      };
    }

    return {
      'success': false,
      'message': data['message'] ?? 'Error en login',
    };
  }

  static String? _extractToken(dynamic data) {
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

  static int? _extractUserId(dynamic data) {
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
}
