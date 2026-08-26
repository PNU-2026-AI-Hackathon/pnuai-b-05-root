import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/adopter/presentation/home_screen.dart';
import 'package:frontend/shared/widgets/ground_illustration.dart';

void main() {
  /// [GroundIllustration]을 폭 400으로 고정하고, 세로는 자기 크기대로 두어
  /// (Align이 loose 제약을 줌) 실제 렌더 높이를 잴 수 있게 감싼다. 화면 높이는
  /// 주입한 [MediaQuery]로 제어한다.
  Widget wrap({required double screenHeight, GroundIllustration child = const GroundIllustration()}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(400, screenHeight)),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, child: child),
        ),
      ),
    );
  }

  testWidgets('기본값은 화면 높이의 17.5%를 흙 높이로 쓴다', (tester) async {
    await tester.pumpWidget(wrap(screenHeight: 914));
    expect(
      tester.getSize(find.byType(GroundIllustration)).height,
      closeTo(914 * 0.175, 0.5),
    );
  });

  testWidgets('화면이 커지면 흙도 같은 비율로 커진다', (tester) async {
    await tester.pumpWidget(wrap(screenHeight: 640));
    final small = tester.getSize(find.byType(GroundIllustration)).height;
    await tester.pumpWidget(wrap(screenHeight: 1280));
    final large = tester.getSize(find.byType(GroundIllustration)).height;
    expect(small, closeTo(640 * 0.175, 0.5));
    expect(large, closeTo(1280 * 0.175, 0.5));
    expect(large / small, closeTo(2.0, 0.01));
  });

  testWidgets('height를 명시하면 화면 높이와 무관하게 그 값을 쓴다', (tester) async {
    await tester.pumpWidget(
      wrap(screenHeight: 914, child: const GroundIllustration(height: 200)),
    );
    expect(tester.getSize(find.byType(GroundIllustration)).height, 200);
  });

  test('formatLastCare는 케어 기록이 없으면 null, 있으면 문구를 반환한다', () {
    expect(formatLastCare(null), isNull);
    expect(formatLastCare(DateTime.now()), '마지막 케어: 오늘');
    expect(
      formatLastCare(DateTime.now().subtract(const Duration(days: 1))),
      '마지막 케어: 어제',
    );
    expect(
      formatLastCare(DateTime.now().subtract(const Duration(days: 5))),
      '마지막 케어: 5일 전',
    );
  });
}
