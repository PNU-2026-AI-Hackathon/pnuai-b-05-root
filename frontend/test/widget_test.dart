import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('로그인 화면이 기본 라우트로 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const PigFigApp());
    await tester.pump();

    expect(find.text('Pig.Fig.'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, '로그인'), findsOneWidget);
  });
}
