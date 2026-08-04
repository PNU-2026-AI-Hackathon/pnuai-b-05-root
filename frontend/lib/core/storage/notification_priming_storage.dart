import 'package:shared_preferences/shared_preferences.dart';

/// 알림 권한 "프라이밍" 다이얼로그 노출 여부 로컬 저장소.
/// [OnboardingStorage]와 동일한 패턴 — 계정이 아니라 기기 단위로 기록한다(Android의 실제
/// 알림 권한도 계정이 아니라 "이 기기의 이 앱" 단위이므로, 다른 계정으로 로그인해도 이미
/// 한 번 판단이 끝났다면 다시 물을 이유가 없다). 허용/나중에 어느 쪽을 선택했든 다시 묻지 않는다.
class NotificationPrimingStorage {
  static const _seenKey = 'pigfig.notification_priming_seen';

  Future<bool> hasSeenPriming() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
