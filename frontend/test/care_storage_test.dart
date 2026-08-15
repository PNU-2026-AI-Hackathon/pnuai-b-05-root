import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/storage/care_storage.dart';

/// [CareStorage]가 계정(userId)별로 케어 완료 시각을 정확히 분리하는지, 그리고
/// [CareStorage.mostRecentCompletion]이 물주기/영양제 중 더 최근 시각을 올바르게
/// 골라내는지 검증한다. 계정 분리는 [InventoryStorage]가 이미 검증하는
/// "같은 기기, 다른 계정" 시나리오와 동일한 관심사다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('완료 기록은 해당 userId로만 저장된다', () async {
    final storage = CareStorage(userId: 'user-a');

    await storage.markCompleted(CareType.water);
    final last = await storage.getLastCompleted(CareType.water);

    expect(last, isNotNull);
  });

  test('userId가 다르면 서로의 케어 완료 기록이 보이지 않는다', () async {
    final storageA = CareStorage(userId: 'user-a');
    final storageB = CareStorage(userId: 'user-b');

    await storageA.markCompleted(CareType.water);

    expect(await storageA.getLastCompleted(CareType.water), isNotNull);
    expect(await storageB.getLastCompleted(CareType.water), isNull);
  });

  group('mostRecentCompletion', () {
    test('둘 다 기록이 없으면 null을 반환한다', () async {
      final storage = CareStorage(userId: 'user-a');

      expect(await storage.mostRecentCompletion(), isNull);
    });

    test('한쪽만 기록이 있으면 그 값을 반환한다', () async {
      final storage = CareStorage(userId: 'user-a');
      await storage.markCompleted(CareType.nutrient);

      final result = await storage.mostRecentCompletion();

      expect(result, isNotNull);
      expect(await storage.getLastCompleted(CareType.nutrient), result);
    });

    test('둘 다 있으면 더 최근 시각을 반환한다', () async {
      final storage = CareStorage(userId: 'user-a');
      final prefs = await SharedPreferences.getInstance();
      final older = DateTime.now().subtract(const Duration(days: 5));
      final newer = DateTime.now().subtract(const Duration(days: 1));

      // 시각을 직접 통제하기 위해 markCompleted() 대신 저장 포맷 그대로 넣는다
      // (markCompleted()는 항상 DateTime.now()만 기록하므로 순서를 재현할 수 없음).
      await prefs.setString(
        'pigfig.care_last_completed.water.user-a',
        older.toIso8601String(),
      );
      await prefs.setString(
        'pigfig.care_last_completed.nutrient.user-a',
        newer.toIso8601String(),
      );

      final result = await storage.mostRecentCompletion();

      expect(result, newer);
    });
  });
}
