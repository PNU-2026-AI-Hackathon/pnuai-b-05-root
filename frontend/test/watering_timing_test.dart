import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/adopter/presentation/games/watering_timing/watering_timing_screen.dart';

/// 물주기 타이밍 게임의 라운드/점수 흐름을 검증한다.
/// 인디케이터가 `repeat()`로 무한 왕복하므로 pumpAndSettle 대신 명시적 pump로만
/// 프레임을 진행한다(반복 애니메이션 중 pumpAndSettle은 타임아웃됨).
void main() {
  /// 화면을 한 번 탭하고, 피드백 표시 → 다음 라운드 자동 전환(1.2초)까지 흘려보낸다.
  Future<void> tapRound(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300)); // 인디케이터 이동
    await tester.tap(find.byType(WateringTimingScreen));
    await tester.pump(); // 탭 결과(점수/피드백) 반영
    await tester.pump(const Duration(milliseconds: 1300)); // 다음 라운드 전환 타이머 경과
  }

  testWidgets('탭하면 점수가 계산되고 다음 라운드로 진행된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WateringTimingScreen()));
    await tester.pump();

    // 시작은 1라운드.
    expect(find.text('1 / 5 라운드'), findsOneWidget);

    // 한 번 탭하면 2라운드로 넘어간다(탭 → 채점 → 자동 전환).
    await tapRound(tester);
    expect(find.text('2 / 5 라운드'), findsOneWidget);
  });

  testWidgets('타겟 존 정중앙 안내선이 타겟 존 박스의 가로 중앙과 정확히 겹친다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WateringTimingScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 안내선: errorRed 색을 가진 DecoratedBox (이 색은 게임 화면에서 이 선에만 쓰임)
    final lineFinder = find.byWidgetPredicate((w) {
      if (w is! DecoratedBox) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.color == AppColors.errorRed;
    });
    // 타겟 존 박스: green500 테두리를 가진 Container
    final zoneFinder = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      if (d is! BoxDecoration) return false;
      final b = d.border;
      return b is Border && b.top.color == AppColors.green500;
    });

    expect(lineFinder, findsOneWidget);
    expect(zoneFinder, findsOneWidget);

    final lineRect = tester.getRect(lineFinder);
    final zoneRect = tester.getRect(zoneFinder);

    // 안내선의 가로 중앙 == 타겟 존 박스의 가로 중앙 (반올림 오차 내)
    expect(lineRect.center.dx, moreOrLessEquals(zoneRect.center.dx, epsilon: 0.5));
    // 안내선이 타겟 존 박스 안쪽에 완전히 들어와 있다
    expect(lineRect.left, greaterThan(zoneRect.left));
    expect(lineRect.right, lessThan(zoneRect.right));
    // 순수 시각 요소이므로 폭은 얇게(3px) 유지
    expect(lineRect.width, moreOrLessEquals(3.0, epsilon: 0.1));
  });

  testWidgets('5라운드를 마치면 결과 다이얼로그가 뜬다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WateringTimingScreen()));
    await tester.pump();

    for (var i = 0; i < 5; i++) {
      await tapRound(tester);
    }
    // 5라운드 종료 후 인디케이터가 멈춰 있으므로 안전하게 settle 가능.
    await tester.pumpAndSettle();

    // 결과 다이얼로그의 "확인" 버튼과 점수 표기가 노출된다.
    expect(find.widgetWithText(ElevatedButton, '확인'), findsOneWidget);
    expect(find.textContaining('점'), findsWidgets);
  });
}
