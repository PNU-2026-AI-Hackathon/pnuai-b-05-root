import 'package:shared_preferences/shared_preferences.dart';

/// 케어 게이지(물주기/영양제) 완료 시각을 기기에 저장한다.
/// [InventoryStorage]/[OnboardingStorage]와 동일하게 SharedPreferences를 감싼다.
/// 게이지 %가 아니라 "마지막으로 완료한 시각"만 저장한다 — 완료 여부 판정(오늘/7일)은
/// 화면마다 기준이 달라 저장소가 아니라 각 화면에서 계산한다. 햇빛은 완료 개념이 없는
/// 연속 슬라이더라 대상에서 제외한다.
enum CareType { water, nutrient }

/// [InventoryStorage]와 동일하게 **계정(userId) 단위**로 분리해 저장한다 — 같은 기기에서
/// 다른 계정으로 로그인해도 이전 계정의 케어 완료 기록이 보이면 안 된다.
/// [TokenStorage.readUserId]로 얻은 값을 그대로 넘겨 생성한다.
class CareStorage {
  CareStorage({required this.userId});

  final String userId;

  static const _keyPrefix = 'pigfig.care_last_completed.';
  static const _pigFedKeyPrefix = 'pigfig.care_last_pig_fed.';

  /// 마지막 완료 시각을 반환한다. 저장된 적 없거나 값이 손상됐으면 null.
  Future<DateTime?> getLastCompleted(CareType type) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix${type.name}.$userId');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// 지금 시각을 해당 케어 타입의 마지막 완료 시각으로 기록한다.
  Future<void> markCompleted(CareType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix${type.name}.$userId',
      DateTime.now().toIso8601String(),
    );
  }

  /// 물주기/영양제 중 더 최근에 완료된 시각을 반환한다. 둘 다 기록이 없으면 null.
  /// 나무 방치 상태([FigTreeIllustration]의 `TreeStatus`) 계산이 "어떤 케어가
  /// 반영 대상인지"를 이 메서드 하나로 알 수 있게 캡슐화한다.
  Future<DateTime?> mostRecentCompletion() async {
    final water = await getLastCompleted(CareType.water);
    final nutrient = await getLastCompleted(CareType.nutrient);
    if (water == null) return nutrient;
    if (nutrient == null) return water;
    return water.isAfter(nutrient) ? water : nutrient;
  }

  /// 돼지 먹이 주기 완료 시각을 기록한다. 나무 방치 판정([mostRecentCompletion])과는
  /// 무관한 별도 트래킹이라 [CareType]에 얹지 않고 전용 메서드로 분리했다 — 돼지는
  /// 나무를 "돌보는" 케어가 아니라 나타난 돼지를 쫓아내는 이벤트성 상호작용이다.
  Future<void> markPigFed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_pigFedKeyPrefix$userId',
      DateTime.now().toIso8601String(),
    );
  }

  /// 가장 최근 돼지 먹이 주기가 12시간 이내면 true.
  Future<bool> isPigFedRecently() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_pigFedKeyPrefix$userId');
    if (raw == null) return false;
    final last = DateTime.tryParse(raw);
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(hours: 12);
  }
}
