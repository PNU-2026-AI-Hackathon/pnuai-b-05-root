import 'package:shared_preferences/shared_preferences.dart';

/// 알림 권한 "프라이밍" 다이얼로그 노출 여부 로컬 저장소.
/// [CareInventoryStorage]/[InventoryStorage]와 동일하게 **계정(userId) 단위**로
/// 분리해 저장한다. "허용"이든 "나중에"든 응답과 무관하게, 한 번 판단이 끝난
/// 계정에는 다시 묻지 않는다.
class NotificationPrimingStorage {
  NotificationPrimingStorage({required this.userId});

  final String userId;

  static const _seenKeyPrefix = 'pigfig.notification_priming_seen.';

  Future<bool> hasSeenPriming() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_seenKeyPrefix$userId') ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenKeyPrefix$userId', true);
  }
}
