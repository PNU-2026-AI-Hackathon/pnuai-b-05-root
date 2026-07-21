import 'package:shared_preferences/shared_preferences.dart';

/// JWT access/refresh 토큰 로컬 저장소.
class TokenStorage {
  static const _accessKey = 'pigfig.access_token';
  static const _refreshKey = 'pigfig.refresh_token';
  static const _emailKey = 'pigfig.email';

  Future<void> save({
    required String access,
    required String refresh,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
    if (email != null) await prefs.setString(_emailKey, email);
  }

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  /// 로그인 시 입력한 이메일. 프로필 화면처럼 로그인한 계정을 표시해야 할 때 쓴다
  /// (백엔드에 프로필 조회 API가 따로 없어, 로그인 시점에 이미 알고 있는 값을 저장해둔다).
  Future<String?> readEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_emailKey);
  }
}
