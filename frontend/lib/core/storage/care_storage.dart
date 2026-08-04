import 'package:shared_preferences/shared_preferences.dart';

/// 케어 게이지(물주기/영양제/가지치기) 완료 시각을 기기에 저장한다.
/// [InventoryStorage]/[OnboardingStorage]와 동일하게 SharedPreferences를 감싼다.
/// 게이지 %가 아니라 "마지막으로 완료한 시각"만 저장한다 — 완료 여부 판정(오늘/7일/영구)은
/// 화면마다 기준이 달라 저장소가 아니라 각 화면에서 계산한다. 햇빛은 완료 개념이 없는
/// 연속 슬라이더라 대상에서 제외한다.
enum CareType { water, nutrient, pruning }

class CareStorage {
  static const _keyPrefix = 'pigfig.care_last_completed.';

  /// 마지막 완료 시각을 반환한다. 저장된 적 없거나 값이 손상됐으면 null.
  Future<DateTime?> getLastCompleted(CareType type) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix${type.name}');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// 지금 시각을 해당 케어 타입의 마지막 완료 시각으로 기록한다.
  Future<void> markCompleted(CareType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix${type.name}',
      DateTime.now().toIso8601String(),
    );
  }
}
