import 'package:shared_preferences/shared_preferences.dart';

/// 마이크 권한 "프라이밍" 다이얼로그 노출 여부 로컬 저장소.
/// `SharedPreferences` 래퍼로 기기 단위로 기록한다. "허용"이든 "나중에"든
/// 응답과 무관하게 다시 묻지 않는다.
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
