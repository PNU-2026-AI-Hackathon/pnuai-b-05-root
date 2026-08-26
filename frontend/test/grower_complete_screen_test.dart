import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/grower/presentation/grower_complete_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            settings: const RouteSettings(
              arguments: GrowerCompleteArgs(
                seedlingId: 1,
                seedlingName: '무화과 #1',
                adopterName: '데모 입양자',
              ),
            ),
            builder: (_) => const GrowerCompleteScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('키 입력 필드와 사진 업로드(선택) 안내가 보이고, 잎/가지 체크리스트는 없다', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('완성된 키'), findsOneWidget);
    expect(find.text('cm'), findsOneWidget);
    expect(find.text('최종 사진 업로드 📷 (선택)'), findsOneWidget);
    expect(find.text('완성 신고하기 🎉'), findsOneWidget);

    // 제거된 하드코딩 체크리스트 항목
    expect(find.textContaining('잎 10장'), findsNothing);
    expect(find.textContaining('가지 3개'), findsNothing);
  });

  testWidgets('키가 30cm 미만이면 경고 문구가 나오고, 30 이상이면 사라진다', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '20');
    await tester.pump();
    expect(find.textContaining('30cm 미만이에요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '35');
    await tester.pump();
    expect(find.textContaining('30cm 미만이에요'), findsNothing);
  });

  testWidgets('키를 입력하지 않고 신고하면 안내 스낵바가 뜬다(네트워크 호출 없음)', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('완성 신고하기 🎉'));
    await tester.pump(); // 스낵바 프레임

    expect(find.text('완성된 키(cm)를 입력해주세요'), findsOneWidget);
  });
}
