import 'package:shared_preferences/shared_preferences.dart';

/// 소비되는 케어 아이템 종류. 화면이 아직 없는 [pigFeed]도 저장 구조 자체는
/// 미리 대응해둔다.
enum CareItemType { water, nutrient, pigFeed }

/// 케어 아이템(물주기/영양제/돼지먹이) 보유 개수를 기기에 저장한다.
/// [InventoryStorage]와 동일하게 **계정(userId) 단위**로 분리해 저장한다.
/// [CareStorage]가 다루는 "마지막 완료 시각"(나무 방치 판정용)과는 목적이 달라
/// 별도 클래스로 분리했다 — 이쪽은 케어 화면(차감)과 게임 화면(충전) 양쪽에서 쓴다.
class CareInventoryStorage {
  CareInventoryStorage({required this.userId});

  final String userId;

  static const _countKeyPrefix = 'pigfig.care_inventory.count.';
  static const _grantedKeyPrefix = 'pigfig.care_inventory.granted.';

  /// 최초 지급 개수(물주기/영양제 각각).
  static const _initialGrantAmount = 2;

  /// 보유 개수를 반환한다. 저장된 적 없으면 0.
  Future<int> getCount(CareItemType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_countKeyPrefix${type.name}.$userId') ?? 0;
  }

  /// 개수가 있으면 1개 차감하고 true, 0이면 아무것도 하지 않고 false.
  Future<bool> consume(CareItemType type) async {
    final current = await getCount(type);
    if (current <= 0) return false;
    await _setCount(type, current - 1);
    return true;
  }

  /// 개수를 [amount]만큼 늘린다. 게임 보상 지급 시 `games_screen.dart`의
  /// `_saveEarnedItems()`가 `careItemTypeFor(item)`으로 변환한 타입에 대해 호출한다
  /// (`games/shared/game_items.dart` 참고).
  Future<void> grant(CareItemType type, {int amount = 1}) async {
    final current = await getCount(type);
    await _setCount(type, current + amount);
  }

  /// 이 계정에 물주기/영양제를 각 2개씩 최초 1회만 지급한다. 이미 지급했으면
  /// 아무것도 하지 않는다(멱등) — 로그인마다 재지급되면 횟수제 자체가 무의미해진다.
  Future<void> grantInitialIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final grantedKey = '$_grantedKeyPrefix$userId';
    if (prefs.getBool(grantedKey) ?? false) return;
    await grant(CareItemType.water, amount: _initialGrantAmount);
    await grant(CareItemType.nutrient, amount: _initialGrantAmount);
    await prefs.setBool(grantedKey, true);
  }

  Future<void> _setCount(CareItemType type, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_countKeyPrefix${type.name}.$userId', value);
  }
}
