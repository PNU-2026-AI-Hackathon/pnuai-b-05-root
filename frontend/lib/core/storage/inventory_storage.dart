import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/adopter/presentation/games/models/game_item.dart';

/// 게임에서 획득한 보유 아이템 로컬 저장소.
/// [OnboardingStorage] / [TokenStorage]와 동일하게 SharedPreferences를 감싸며,
/// 아이템 목록은 JSON 문자열 하나로 인코딩해 저장한다.
class InventoryStorage {
  static const _itemsKey = 'pigfig.inventory_items';

  /// 저장된 보유 아이템 전체를 반환한다. 저장값이 없거나 파싱에 실패하면 빈 목록.
  Future<List<GameItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_itemsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => GameItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      // 저장 포맷이 깨진 경우 빈 목록으로 폴백한다.
      return [];
    }
  }

  /// 아이템 하나를 목록 끝에 추가해 저장한다.
  Future<void> addItem(GameItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getItems();
    items.add(item);
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_itemsKey, encoded);
  }
}
