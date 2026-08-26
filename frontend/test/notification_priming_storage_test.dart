import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/storage/notification_priming_storage.dart';

/// [NotificationPrimingStorage]가 알림 프라이밍 노출 여부를 계정(userId)별로
/// 정확히 분리해 기록하는지 검증한다. 같은 기기에서 계정을 바꿔가며 로그인하는
/// 시나리오(A 계정 프라이밍 응답 → 로그아웃 → B 계정 로그인)에서 B 계정에도
/// 프라이밍이 한 번은 떠야 한다는 것이 이 테스트의 핵심 관심사다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('기록된 적 없으면 hasSeenPriming()은 false다', () async {
    final storage = NotificationPrimingStorage(userId: 'user-a');
    expect(await storage.hasSeenPriming(), isFalse);
  });

  test('markSeen() 후 같은 계정의 hasSeenPriming()은 true다', () async {
    final storage = NotificationPrimingStorage(userId: 'user-a');

    await storage.markSeen();

    expect(await storage.hasSeenPriming(), isTrue);
  });

  test('userId가 다르면 서로의 프라이밍 기록이 보이지 않는다', () async {
    final storageA = NotificationPrimingStorage(userId: 'user-a');
    final storageB = NotificationPrimingStorage(userId: 'user-b');

    await storageA.markSeen();

    expect(await storageA.hasSeenPriming(), isTrue);
    expect(await storageB.hasSeenPriming(), isFalse);
  });
}
