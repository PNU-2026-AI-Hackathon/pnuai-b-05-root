import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/storage/inventory_storage.dart';
import 'package:frontend/features/adopter/presentation/games/models/game_item.dart';

/// [InventoryStorage]가 계정(userId)별로 데이터를 정확히 분리하는지, 그리고
/// [InventoryStorage.clear]가 다른 계정의 데이터에 영향을 주지 않고 해당 계정
/// 것만 지우는지 검증한다. 같은 기기에서 계정을 바꿔가며 로그인하는 시나리오
/// (A 계정 게임 → 로그아웃 → B 계정 로그인)에서 아이템이 뒤섞이지 않는지가
/// 이 테스트의 핵심 관심사다.
void main() {
  const item = GameItem(
    id: 'leaf',
    name: '무화과 잎',
    emoji: '🍃',
    description: '테스트용 아이템',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('아이템을 추가하면 해당 userId로만 저장된다', () async {
    final storage = InventoryStorage(userId: 'user-a');

    await storage.addItem(item);
    final items = await storage.getItems();

    expect(items, hasLength(1));
    expect(items.first.id, 'leaf');
  });

  test('userId가 다르면 서로의 아이템이 보이지 않는다', () async {
    final storageA = InventoryStorage(userId: 'user-a');
    final storageB = InventoryStorage(userId: 'user-b');

    await storageA.addItem(item);

    // A 계정으로 게임해서 아이템을 얻어도, 같은 기기에서 B 계정으로 조회하면
    // 빈 목록이어야 한다(계정 뒤섞임 버그 재현/회귀 방지).
    expect(await storageA.getItems(), hasLength(1));
    expect(await storageB.getItems(), isEmpty);
  });

  test('clear()는 해당 userId의 아이템만 지우고 다른 계정 데이터는 유지한다', () async {
    final storageA = InventoryStorage(userId: 'user-a');
    final storageB = InventoryStorage(userId: 'user-b');
    await storageA.addItem(item);
    await storageB.addItem(item);

    await storageA.clear();

    expect(await storageA.getItems(), isEmpty);
    expect(await storageB.getItems(), hasLength(1));
  });
}
