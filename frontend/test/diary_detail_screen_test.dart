import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/adopter/presentation/diary_detail_screen.dart';

void main() {
  Widget wrap(DiaryDetailArgs args) {
    return MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: RouteSettings(arguments: args),
          builder: (_) => const DiaryDetailScreen(),
        ),
      ),
    );
  }

  testWidgets('사진이 있으면 날짜/본문과 다운로드 버튼을 보여준다', (tester) async {
    await tester.pumpWidget(
      wrap(
        DiaryDetailArgs(
          diaryId: 1,
          content: '가지가 3개로 늘었어요!',
          createdAt: DateTime(2026, 7, 18),
          photoUrl: 'https://example.com/photo.jpg',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('가지가 3개로 늘었어요!'), findsOneWidget);
    expect(find.text('2026.07.18'), findsOneWidget);
    expect(find.text('저장 📥'), findsOneWidget);
  });

  testWidgets('사진/일러스트가 둘 다 없으면 다운로드 버튼 없이 placeholder만 보여준다', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        DiaryDetailArgs(
          diaryId: 2,
          content: '입양 첫날, 새싹 인사',
          createdAt: DateTime(2026, 6, 20),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('✨ 일러스트 변환'), findsOneWidget);
    expect(find.text('사진 저장하기 📥'), findsNothing);
  });

  test('buildDiaryImageFilename은 일지 id와 날짜로 파일명을 만든다', () {
    final filename = buildDiaryImageFilename(7, DateTime(2026, 7, 18));
    expect(filename, 'pigfig_diary_7_20260718.png');
  });
}
