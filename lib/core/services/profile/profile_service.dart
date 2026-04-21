import 'package:app_flutter_ai/core/config/api_config.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/shared/http_client.dart';

class ProfileService {
  static Future<Map<String, dynamic>> getProfile({
    bool remote = false,
  }) async {
    final fallback = _buildFallbackProfile();
    final userId = SessionService.userId;

    if (userId == null || !remote) {
      return fallback;
    }

    try {
      final response = await HttpClient.get(ApiConfig.userCompaniesUrl);
      final record = _findProfileRecord(response, userId);
      if (record == null) {
        return fallback;
      }

      return _mergeProfile(fallback, record);
    } catch (_) {
      return fallback;
    }
  }

  static Map<String, dynamic> _buildFallbackProfile() {
    final name = SessionService.userName?.trim();
    final company = SessionService.companyName?.trim();
    final role = SessionService.roleName?.trim();
    final email = SessionService.userEmail?.trim();

    return {
      'displayName': name?.isNotEmpty == true ? name : 'Usuario de campo',
      'roleName': role?.isNotEmpty == true ? role : 'Administrador de fincas',
      'companyName': company?.isNotEmpty == true ? company : 'Dato Rural',
      'email': email ?? '',
      'phone': '',
      'address': '',
      'identification': '',
      'socialMedia': '',
      'photoId': '',
    };
  }

  static Map<String, dynamic>? _findProfileRecord(
    Map<String, dynamic> response,
    int userId,
  ) {
    final raw = response['data'] ??
        response['items'] ??
        response['records'] ??
        response['results'] ??
        response;

    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final record = Map<String, dynamic>.from(item);
        if (_matchesUser(record, userId)) {
          return record;
        }
      }
      return null;
    }

    if (raw is Map<String, dynamic>) {
      return _matchesUser(raw, userId) ? raw : null;
    }

    return null;
  }

  static bool _matchesUser(Map<String, dynamic> record, int userId) {
    final user = record['user'];
    if (user is Map<String, dynamic>) {
      final id = user['id'];
      if (id is int) {
        return id == userId;
      }
      if (id is String) {
        return int.tryParse(id) == userId;
      }
    }

    final userProfile = record['userProfile'];
    if (userProfile is Map<String, dynamic>) {
      final nestedUser = userProfile['user'];
      if (nestedUser is Map<String, dynamic>) {
        final id = nestedUser['id'];
        if (id is int) {
          return id == userId;
        }
        if (id is String) {
          return int.tryParse(id) == userId;
        }
      }
    }

    return false;
  }

  static Map<String, dynamic> _mergeProfile(
    Map<String, dynamic> fallback,
    Map<String, dynamic> record,
  ) {
    final user = record['user'] is Map<String, dynamic>
        ? record['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final userProfile = record['userProfile'] is Map<String, dynamic>
        ? record['userProfile'] as Map<String, dynamic>
        : <String, dynamic>{};
    final company = record['company'] is Map<String, dynamic>
        ? record['company'] as Map<String, dynamic>
        : <String, dynamic>{};
    final role = user['role'] is Map<String, dynamic>
        ? user['role'] as Map<String, dynamic>
        : <String, dynamic>{};

    final firstName = (user['firstName'] ?? '').toString().trim();
    final lastName = (user['lastName'] ?? '').toString().trim();
    final fullName = [firstName, lastName]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();

    return {
      'displayName': fullName.isNotEmpty ? fullName : fallback['displayName'],
      'roleName': _pickFirstText([
            role['name'],
            fallback['roleName'],
          ]) ??
          fallback['roleName'],
      'companyName': _pickFirstText([
            company['name'],
            fallback['companyName'],
          ]) ??
          fallback['companyName'],
      'email': _pickFirstText([
            user['email'],
            fallback['email'],
          ]) ??
          '',
      'phone': _pickFirstText([
            userProfile['phone'],
            fallback['phone'],
          ]) ??
          '',
      'address': _pickFirstText([
            userProfile['address'],
            fallback['address'],
          ]) ??
          '',
      'identification': _pickFirstText([
            userProfile['identification'],
            fallback['identification'],
          ]) ??
          '',
      'socialMedia': _pickFirstText([
            userProfile['socialMedia'],
            fallback['socialMedia'],
          ]) ??
          '',
      'photoId': _extractPhotoId(user),
    };
  }

  static String? _pickFirstText(List<dynamic> candidates) {
    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _extractPhotoId(Map<String, dynamic> user) {
    final photo = user['photo'];
    if (photo is Map<String, dynamic>) {
      final id = photo['id'];
      if (id is String && id.trim().isNotEmpty) {
        return id.trim();
      }
    }
    return '';
  }
}
