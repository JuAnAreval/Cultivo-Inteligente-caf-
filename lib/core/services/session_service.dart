import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';

  static String? _token;
  static int? _userId;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _userId = prefs.getInt(_userIdKey);
  }

  static String? get token => _token;
  static int? get userId => _userId;

  static bool get isAuthenticated =>
      _token != null && _token!.trim().isNotEmpty;

  static Future<void> saveSession({
    required String token,
    int? userId,
  }) async {
    _token = token;
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (userId != null) {
      await prefs.setInt(_userIdKey, userId);
    } else {
      await prefs.remove(_userIdKey);
    }
  }

  static Future<void> saveToken(String token) async {
    await saveSession(token: token, userId: _userId);
  }

  static Future<void> clear() async {
    _token = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }
}
