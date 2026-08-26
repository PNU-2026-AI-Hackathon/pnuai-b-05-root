import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/adopter/presentation/adopt/adopt_screen.dart';
import 'package:frontend/features/adopter/presentation/diary_detail_screen.dart';
import 'package:frontend/features/grower/presentation/grower_complete_screen.dart';
import 'package:frontend/features/grower/presentation/grower_diary_write_screen.dart';

/// push 화면(탭바 없는 전체화면)들이 `Scaffold.body`를 `SafeArea`로 감싸, 하단
/// 콘텐츠(고정 버튼 등)가 시스템 내비게이션 바 인셋 안쪽에 머무는지 검증한다.
/// `grower_diary_write`는 키보드가 올라와도 스크롤로 입력창/버튼에 닿는지도 함께 본다.
void main() {
  const navBarInset = 48.0;

  /// 하단에 [navBarInset]짜리 시스템 인셋이 있는 실제 크기(≈Pixel)의 기기를 흉내내
  /// [screen]을 pump한다.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Object? args,
    double keyboardInset = 0,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(bottom: navBarInset),
              viewPadding: const EdgeInsets.only(bottom: navBarInset),
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                settings: RouteSettings(arguments: args),
                builder: (_) => screen,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double screenHeight(WidgetTester tester) =>
      tester.getSize(find.byType(MaterialApp)).height;

  /// body를 감싼 `SafeArea`(하단 인셋을 소비하는 것 — `PigFigAppBar` 안의
  /// `SafeArea(bottom: false)`는 제외)가 존재하는지 확인한다.
  void expectBodySafeArea(WidgetTester tester) {
    final bodySafeAreas = tester
        .widgetList<SafeArea>(find.byType(SafeArea))
        .where((s) => s.bottom)
        .toList();
    expect(bodySafeAreas, isNotEmpty, reason: 'body가 SafeArea로 감싸져야 한다');
  }

  testWidgets('AdoptScreen: SafeArea로 감싸지고 결제하기 버튼이 하단 인셋 위에 있다', (
    tester,
  ) async {
    await pumpScreen(tester, const AdoptScreen());

    expect(tester.takeException(), isNull);
    expectBodySafeArea(tester);
    final buttonBottom = tester.getRect(find.text('결제하기')).bottom;
    expect(buttonBottom, lessThanOrEqualTo(screenHeight(tester) - navBarInset));
  });

  testWidgets('GrowerCompleteScreen: SafeArea로 감싸지고 스크롤 끝의 완성 신고 버튼이 하단 인셋 위에 있다', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const GrowerCompleteScreen(),
      args: const GrowerCompleteArgs(
        seedlingId: 1,
        seedlingName: '무화과 #1',
        adopterName: '데모 입양자',
      ),
    );

    expect(tester.takeException(), isNull);
    expectBodySafeArea(tester);
    // 키 입력 필드가 생겨 body가 스크롤 구조로 바뀌었다(grower_diary_write와 동일).
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('완성 신고하기 🎉'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final buttonBottom = tester.getRect(find.text('완성 신고하기 🎉')).bottom;
    expect(buttonBottom, lessThanOrEqualTo(screenHeight(tester) - navBarInset));
  });

  testWidgets('DiaryDetailScreen: SafeArea로 감싸지고 스크롤 끝의 저장 버튼이 하단 인셋 위에 있다', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const DiaryDetailScreen(),
      args: DiaryDetailArgs(
        diaryId: 1,
        content: '가지가 3개로 늘었어요! ' * 30,
        createdAt: DateTime(2026, 8, 20),
        photoUrl: 'https://example.com/p.jpg',
      ),
    );

    expect(tester.takeException(), isNull);
    expectBodySafeArea(tester);

    await tester.scrollUntilVisible(
      find.text('저장 📥'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final buttonBottom = tester.getRect(find.text('저장 📥')).bottom;
    expect(buttonBottom, lessThanOrEqualTo(screenHeight(tester) - navBarInset));
  });

  testWidgets('GrowerDiaryWriteScreen: 하단 인셋 + 키보드에서 스크롤되고 오버플로가 없다', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const GrowerDiaryWriteScreen(),
      args: const GrowerDiaryWriteArgs(seedlingId: 1),
      keyboardInset: 320,
    );

    expect(tester.takeException(), isNull);
    expectBodySafeArea(tester);
    // 본문이 스크롤 가능한 구조여야 한다(예전엔 Padding>Column이라 스크롤 불가).
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // 긴 텍스트를 입력해도 오버플로가 나지 않고, 제출 버튼까지 스크롤로 닿는다.
    await tester.enterText(find.byType(TextField), '오늘의 기록입니다. ' * 40);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('입양자에게 전달하기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final buttonBottom = tester.getRect(find.text('입양자에게 전달하기')).bottom;
    expect(buttonBottom, lessThanOrEqualTo(screenHeight(tester) - navBarInset));
  });
}
