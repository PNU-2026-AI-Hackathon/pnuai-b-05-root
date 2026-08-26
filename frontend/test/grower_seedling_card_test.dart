import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/grower/data/grower_repository.dart';
import 'package:frontend/features/grower/presentation/grower_seedling_overview.dart';

void main() {
  Seedling makeSeedling({
    bool adopterIsActive = true,
    String? adopterNickname,
  }) => Seedling(
    id: 1,
    adopterId: 7,
    status: SeedlingStatus.growing,
    startedAt: DateTime(2026, 8, 1),
    adopterIsActive: adopterIsActive,
    adopterNickname: adopterNickname,
  );

  Future<void> pump(WidgetTester tester, Seedling seedling) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GrowerSeedlingListCard(seedling: seedling, onTap: () {}),
      ),
    ),
  );

  testWidgets('활성 입양자면 닉네임을 보여주고 "탈퇴한 계정" 배지는 없다', (tester) async {
    await pump(tester, makeSeedling(adopterNickname: '단풍'));

    expect(find.text('입양자 단풍'), findsOneWidget);
    expect(find.text('탈퇴한 계정'), findsNothing);
  });

  testWidgets('탈퇴한 입양자면 "탈퇴한 계정" 배지가 보인다', (tester) async {
    await pump(
      tester,
      makeSeedling(adopterIsActive: false, adopterNickname: '단풍'),
    );

    expect(find.text('탈퇴한 계정'), findsOneWidget);
  });

  testWidgets('닉네임이 없으면 "입양자 #id"로 폴백한다', (tester) async {
    await pump(tester, makeSeedling());

    expect(find.text('입양자 #7'), findsOneWidget);
  });
}
