import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/storage/care_inventory_storage.dart';

/// [CareInventoryStorage]가 계정(userId)별로 보유 개수를 정확히 분리하는지,
/// 소비/지급이 올바르게 동작하는지, 최초 지급([grantInitialIfNeeded])이
/// 정확히 1회만 이뤄지는지 검증한다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('저장된 적 없으면 개수는 0이다', () async {
    final storage = CareInventoryStorage(userId: 'user-a');

    expect(await storage.getCount(CareItemType.water), 0);
  });

  group('grant / consume', () {
    test('grant()는 개수를 누적 증가시킨다', () async {
      final storage = CareInventoryStorage(userId: 'user-a');

      await storage.grant(CareItemType.water, amount: 2);
      await storage.grant(CareItemType.water, amount: 1);

      expect(await storage.getCount(CareItemType.water), 3);
    });

    test('개수가 있으면 consume()은 1개 차감하고 true를 반환한다', () async {
      final storage = CareInventoryStorage(userId: 'user-a');
      await storage.grant(CareItemType.nutrient, amount: 2);

      final result = await storage.consume(CareItemType.nutrient);

      expect(result, isTrue);
      expect(await storage.getCount(CareItemType.nutrient), 1);
    });

    test('개수가 0이면 consume()은 차감 없이 false를 반환한다', () async {
      final storage = CareInventoryStorage(userId: 'user-a');

      final result = await storage.consume(CareItemType.water);

      expect(result, isFalse);
      expect(await storage.getCount(CareItemType.water), 0);
    });
  });

  test('userId가 다르면 서로의 보유 개수가 보이지 않는다', () async {
    final storageA = CareInventoryStorage(userId: 'user-a');
    final storageB = CareInventoryStorage(userId: 'user-b');

    await storageA.grant(CareItemType.water, amount: 5);

    expect(await storageA.getCount(CareItemType.water), 5);
    expect(await storageB.getCount(CareItemType.water), 0);
  });

  group('grantInitialIfNeeded', () {
    test('최초 호출 시 물주기/영양제 각 2개씩 채워진다', () async {
      final storage = CareInventoryStorage(userId: 'user-a');

      await storage.grantInitialIfNeeded();

      expect(await storage.getCount(CareItemType.water), 2);
      expect(await storage.getCount(CareItemType.nutrient), 2);
      expect(await storage.getCount(CareItemType.pigFeed), 0);
    });

    test('두 번째 호출은 아무 변화도 주지 않는다(멱등)', () async {
      final storage = CareInventoryStorage(userId: 'user-a');
      await storage.grantInitialIfNeeded();
      await storage.consume(CareItemType.water); // 사용자가 하나 소비했다고 가정

      await storage.grantInitialIfNeeded();

      // 재지급되지 않았으므로 소비한 만큼 그대로 1개여야 한다(2로 되돌아가지 않음).
      expect(await storage.getCount(CareItemType.water), 1);
      expect(await storage.getCount(CareItemType.nutrient), 2);
    });
  });
}
