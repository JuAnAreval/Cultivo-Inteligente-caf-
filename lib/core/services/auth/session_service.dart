import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _tokenExpiresKey = 'auth_token_expires';
  static const String _userIdKey = 'auth_user_id';
  static const String _userNameKey = 'auth_user_name';
  static const String _userEmailKey = 'auth_user_email';
  static const String _roleNameKey = 'auth_role_name';
  static const String _companyNameKey = 'auth_company_name';

  static String? _token;
  static String? _refreshToken;
  static int? _tokenExpires;
  static int? _userId;
  static String? _userName;
  static String? _userEmail;
  static String? _roleName;
  static String? _companyName;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _tokenExpires = prefs.getInt(_tokenExpiresKey);
    _userId = prefs.getInt(_userIdKey);
    _userName = prefs.getString(_userNameKey);
    _userEmail = prefs.getString(_userEmailKey);
    _roleName = prefs.getString(_roleNameKey);
    _companyName = prefs.getString(_companyNameKey);
  }

  static String? get token => _token;
  static String? get refreshToken => _refreshToken;
  static int? get tokenExpires => _tokenExpires;
  static int? get userId => _userId;
  static String? get userName => _userName;
  static String? get userEmail => _userEmail;
  static String? get roleName => _roleName;
  static String? get companyName => _companyName;

  static bool get isAuthenticated =>
      _token != null && _token!.trim().isNotEmpty;

  static bool get hasRefreshToken =>
      _refreshToken != null && _refreshToken!.trim().isNotEmpty;

  static bool get canRestoreSession => isAuthenticated || hasRefreshToken;

  static bool get isTokenExpired {
    final expires = _tokenExpires;
    if (expires == null) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return now >= expires - 60000;
  }

  static Future<void> saveSession({
    required String token,
    String? refreshToken,
    int? tokenExpires,
    int? userId,
    String? userName,
    String? userEmail,
    String? roleName,
    String? companyName,
  }) async {
    _token = token;
    _refreshToken = refreshToken ?? _refreshToken;
    _tokenExpires = tokenExpires;
    _userId = userId;
    _userName = userName ?? _userName;
    _userEmail = userEmail ?? _userEmail;
    _roleName = roleName ?? _roleName;
    _companyName = companyName ?? _companyName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (_refreshToken != null && _refreshToken!.trim().isNotEmpty) {
      await prefs.setString(_refreshTokenKey, _refreshToken!);
    } else {
      await prefs.remove(_refreshTokenKey);
    }
    if (_tokenExpires != null) {
      await prefs.setInt(_tokenExpiresKey, _tokenExpires!);
    } else {
      await prefs.remove(_tokenExpiresKey);
    }
    if (userId != null) {
      await prefs.setInt(_userIdKey, userId);
    } else {
      await prefs.remove(_userIdKey);
    }
    if (_userName != null && _userName!.trim().isNotEmpty) {
      await prefs.setString(_userNameKey, _userName!);
    } else {
      await prefs.remove(_userNameKey);
    }
    if (_userEmail != null && _userEmail!.trim().isNotEmpty) {
      await prefs.setString(_userEmailKey, _userEmail!);
    } else {
      await prefs.remove(_userEmailKey);
    }
    if (_roleName != null && _roleName!.trim().isNotEmpty) {
      await prefs.setString(_roleNameKey, _roleName!);
    } else {
      await prefs.remove(_roleNameKey);
    }
    if (_companyName != null && _companyName!.trim().isNotEmpty) {
      await prefs.setString(_companyNameKey, _companyName!);
    } else {
      await prefs.remove(_companyNameKey);
    }
  }

  static Future<void> saveToken(String token) async {
    await saveSession(
      token: token,
      refreshToken: _refreshToken,
      tokenExpires: _tokenExpires,
      userId: _userId,
      userName: _userName,
      userEmail: _userEmail,
      roleName: _roleName,
      companyName: _companyName,
    );
  }

  static Future<void> markTokenExpired() async {
    _tokenExpires = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tokenExpiresKey, 0);
  }

  static Future<void> clear() async {
    _token = null;
    _refreshToken = null;
    _tokenExpires = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _roleName = null;
    _companyName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_tokenExpiresKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_roleNameKey);
    await prefs.remove(_companyNameKey);
  }
}
