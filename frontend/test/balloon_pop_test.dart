import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/adopter/presentation/games/balloon_pop/balloon_pop_screen.dart';

/// 돼지 풍선 터뜨리기 게임 검증. 단일 AnimationController가 프레임을 구동하므로
/// 진행 중에는 pumpAndSettle 대신 명시적 pump로만 프레임을 진행하고, 게임이 끝나
/// 컨트롤러가 멈춘 뒤에만 settle한다. 풍선이 화면 밖으로 밀려나 hit-test가 실패하지
/// 않도록 뷰포트를 넉넉히 키운다(pest_catch_test에서 겪은 문제 예방).
void main() {
  void enlargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('풍선을 탭하면 점수가 오른다', (tester) async {
    enlargeViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: BalloonPopScreen()));
    await tester.pump();

    // 시작 점수 0.
    expect(find.text('점수 0'), findsOneWidget);

    // 첫 스폰 간격(1200ms)이 지나 첫 풍선(id 0)이 바닥에 떠오른다.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.byKey(const ValueKey('balloon_0')), findsOneWidget);

    // 풍선을 탭해 터뜨리면 +10점.
    await tester.tap(find.byKey(const ValueKey('balloon_0')));
    await tester.pump();
    expect(find.text('점수 10'), findsOneWidget);
  });

  testWidgets('30초가 지나면 결과 다이얼로그가 뜬다', (tester) async {
    enlargeViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: BalloonPopScreen()));
    await tester.pump();

    // 30초 경과 시 컨트롤러가 완료되어 _finish가 호출되고 모든 애니메이션이 멈춘다.
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, '확인'), findsOneWidget);
    expect(find.textContaining('점'), findsWidgets);
  });
}
