import 'package:shared_preferences/shared_preferences.dart';

/// 알림 종류. 서버에는 이 값으로 실제 발송을 필터링하는 로직이 아직 없어(위치는
/// UI 안내문 참고), 지금은 "표시 여부"에 대한 사용자 의사만 로컬에 남겨둔다.
enum NotificationPreferenceType { seedlingAlert, growthDiary, harvestDelivery }

/// 알림 종류별 on/off 설정을 기기에 저장한다. [CareInventoryStorage]와 동일하게
/// **계정(userId) 단위**로 분리해 저장한다. [TokenStorage.readUserId]로 얻은 값을
/// 그대로 넘겨 생성한다.
class NotificationPreferenceStorage {
  NotificationPreferenceStorage({required this.userId});

  final String userId;

  static const _keyPrefix = 'pigfig.notification_preference.';

  /// 저장된 적 없으면 기본값 true(전부 켜짐)로 취급한다.
  Future<bool> isEnabled(NotificationPreferenceType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix${type.name}.$userId') ?? true;
  }

  Future<void> setEnabled(NotificationPreferenceType type, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix${type.name}.$userId', value);
  }
}
