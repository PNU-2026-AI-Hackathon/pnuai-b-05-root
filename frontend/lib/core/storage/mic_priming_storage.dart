import 'package:shared_preferences/shared_preferences.dart';

/// 마이크 권한 "프라이밍" 다이얼로그 노출 여부 로컬 저장소.
/// [NotificationPrimingStorage]와 동일한 패턴 — 계정이 아니라 기기 단위로 기록한다.
/// 허용/나중에 어느 쪽을 선택했든 다시 묻지 않는다.
class MicPrimingStorage {
  static const _seenKey = 'pigfig.mic_priming_seen';

  Future<bool> hasSeenPriming() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
