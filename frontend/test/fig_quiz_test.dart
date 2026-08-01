import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/adopter/presentation/games/fig_quiz/fig_quiz_questions.dart';
import 'package:frontend/features/adopter/presentation/games/fig_quiz/fig_quiz_screen.dart';

void main() {
  testWidgets('정답을 고르면 초록 체크(정답) 아이콘이 표시된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FigQuizScreen()));
    await tester.pumpAndSettle();

    final first = figQuizQuestions.first;
    // 첫 문항의 정답 보기를 탭한다.
    await tester.tap(find.text(first.options[first.correctIndex]));
    await tester.pump();

    // 정답 하이라이트로 체크 아이콘이 나타난다.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // 1.5초 자동 전환 타이머를 흘려보내 테스트 종료 시 대기 중 타이머가 남지 않게 한다.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('10문항을 모두 맞히면 만점(100점) 결과 다이얼로그가 뜬다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FigQuizScreen()));
    await tester.pumpAndSettle();

    for (final question in figQuizQuestions) {
      await tester.tap(find.text(question.options[question.correctIndex]));
      await tester.pump(); // 선택 반영
      // 1.5초 자동 전환 타이머 경과 → 다음 문항 또는 종료
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();

    // 결과 다이얼로그에 만점 점수와 "확인" 버튼이 노출된다.
    expect(find.text('100점'), findsOneWidget);
    expect(find.text('🎉 성공!'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '확인'), findsOneWidget);
  });
}
