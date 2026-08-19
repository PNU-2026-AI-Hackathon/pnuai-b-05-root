import 'package:shared_preferences/shared_preferences.dart';

/// JWT access/refresh 토큰 로컬 저장소.
class TokenStorage {
  static const _accessKey = 'pigfig.access_token';
  static const _refreshKey = 'pigfig.refresh_token';
  static const _emailKey = 'pigfig.email';
  static const _userIdKey = 'pigfig.user_id';
  static const _nicknameKey = 'pigfig.nickname';

  Future<void> save({
    required String access,
    required String refresh,
    String? email,
    String? userId,
    String? nickname,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
    if (email != null) await prefs.setString(_emailKey, email);
    if (userId != null) await prefs.setString(_userIdKey, userId);
    if (nickname != null) await prefs.setString(_nicknameKey, nickname);
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

  /// 로그인한 사용자의 서버 id(문자열). [core/storage/inventory_storage.dart]처럼
  /// 계정별로 로컬 데이터를 분리해야 할 때 이 값을 키에 사용한다.
  Future<String?> readUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// 로그인 응답의 닉네임. 서버에서 빈 문자열(`''`)로 내려올 수 있다(회원가입 시
  /// 선택 입력이라 미입력 계정이 있을 수 있음) — 빈 값 처리는 호출부 책임이다.
  Future<String?> readNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nicknameKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nicknameKey);
  }
}
