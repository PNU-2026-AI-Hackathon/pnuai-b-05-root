import 'package:shared_preferences/shared_preferences.dart';

/// JWT access/refresh 토큰 로컬 저장소.
class TokenStorage {
  static const _accessKey = 'pigfig.access_token';
  static const _refreshKey = 'pigfig.refresh_token';

  Future<void> save({required String access, required String refresh}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}
