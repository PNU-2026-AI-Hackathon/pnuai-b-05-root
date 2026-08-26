import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/util/season_badge.dart';
import 'package:frontend/features/adopter/presentation/donation_certificate_screen.dart';

void main() {
  group('seasonBadgeFor', () {
    test('월별로 계절을 정한다', () {
      expect(seasonBadgeFor(DateTime(2026, 4, 10)).label, '봄');
      expect(seasonBadgeFor(DateTime(2026, 6, 10)).label, '초여름');
      expect(seasonBadgeFor(DateTime(2026, 8, 20)).label, '한여름');
      expect(seasonBadgeFor(DateTime(2026, 10, 1)).label, '가을');
      expect(seasonBadgeFor(DateTime(2026, 1, 5)).label, '겨울');
      expect(seasonBadgeFor(DateTime(2026, 12, 31)).label, '겨울');
    });

    test('UTC 입력도 로컬로 변환해 판정한다', () {
      // 함수가 toLocal()을 거치는지 — 같은 순간을 UTC로 넣어도 예외 없이 동작해야 한다.
      final badge = seasonBadgeFor(DateTime.utc(2026, 8, 20, 5, 32, 7));
      expect(badge.label, isNotEmpty);
      expect(badge.emoji, isNotEmpty);
    });
  });

  test('seasonCompletionPhrase는 "…에 완성됐어요 이모지" 문구를 만든다', () {
    expect(
      seasonCompletionPhrase(DateTime(2026, 8, 20)),
      '한여름에 완성됐어요 ☀️',
    );
  });

  group('formatSeasonLine', () {
    test('completed_at이 없으면 null', () {
      expect(formatSeasonLine(null, 34), isNull);
    });

    test('키가 있으면 " · 34cm"를 덧붙인다', () {
      expect(formatSeasonLine(DateTime(2026, 8, 20), 34), '☀️ 한여름에 완성 · 34cm');
    });

    test('키가 없으면 계절만', () {
      expect(formatSeasonLine(DateTime(2026, 8, 20), null), '☀️ 한여름에 완성');
    });
  });

  group('formatBirthMoment', () {
    test('completed_at이 없으면 null', () {
      expect(formatBirthMoment(null), isNull);
    });

    test('초 단위까지 0-패딩해 포맷한다', () {
      expect(
        formatBirthMoment(DateTime(2026, 8, 5, 9, 3, 7)),
        '🐣 2026. 08. 05 · 09:03:07',
      );
    });
  });
}
