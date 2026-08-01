import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/adopter/presentation/games/pest_catch/pest_catch_screen.dart';

/// 해충 잡기 게임 검증. 스폰/카운트다운이 Timer.periodic 기반이라 pumpAndSettle은
/// 게임 종료(모든 타이머 정리) 이후에만 안전하다. 진행 중에는 명시적 pump만 사용한다.
/// 또한 테스트 종료 시 대기 중 타이머가 남지 않도록 각 테스트를 30초까지 진행시켜
/// 게임을 끝낸다.
void main() {
  testWidgets('노출된 해충 칸을 탭하면 점수가 오른다', (tester) async {
    // 기본 테스트 뷰포트(800x600)에서는 3x3 격자의 마지막 줄이 세로 범위 밖으로
    // 밀려나 그 칸의 탭이 hit-test에 걸리지 않는다. 9칸을 모두 탭하는 이 테스트를
    // 위해 뷰포트를 충분히 크게 잡아 격자 전체가 화면 안에 들어오게 한다.
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PestCatchScreen()));
    await tester.pump();

    // 시작 점수 0.
    expect(find.text('점수 0'), findsOneWidget);

    // 첫 스폰(900ms)이 지나 해충 한 칸이 노출된 상태로 만든다.
    await tester.pump(const Duration(milliseconds: 950));

    // 어느 칸에 나타났는지 알 수 없으므로 9칸을 모두 탭한다.
    // 빈 칸 탭은 무시되고, 노출된 칸만 +10점 처리된다.
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byKey(ValueKey('pest_cell_$i')));
    }
    await tester.pump();

    // 스폰 1회(동시 1칸)만 지났으므로 정확히 10점.
    expect(find.text('점수 10'), findsOneWidget);

    // 남은 시간을 모두 흘려보내 게임을 끝내고 타이머를 정리한다.
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, '확인'), findsOneWidget);
  });

  testWidgets('30초가 지나면 결과 다이얼로그가 뜬다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PestCatchScreen()));
    await tester.pump();

    // 30초 카운트다운이 끝나면 _finish가 호출되고 타이머가 모두 취소된다.
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, '확인'), findsOneWidget);
    expect(find.textContaining('점'), findsWidgets);
  });
}
