import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/adopter/presentation/donation_certificate_screen.dart';

void main() {
  DonationCertificateArgs buildArgs({int? heightCm}) => DonationCertificateArgs(
    seedlingId: 3,
    seedlingName: '무화과 #3',
    organizationName: '앱 내 나눔 분양',
    startedAt: DateTime(2026, 6, 1),
    completedAt: DateTime(2026, 8, 20, 14, 32, 7),
    heightCm: heightCm,
  );

  Future<void> pumpCard(WidgetTester tester, DonationCertificateArgs args) async {
    // 실제 화면(DonationCertificateScreen)은 스크롤 없이 SafeArea에 바로 얹으므로
    // 넉넉한 기기 크기로 pump해 오버플로 없이 렌더되는지 함께 본다.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DonationCertificateCard(args: args, nickname: '테스트'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('인증서 카드는 콘텐츠와 이미지 저장/공유하기 버튼을 보여준다', (tester) async {
    await pumpCard(tester, buildArgs());

    expect(find.text('기부 인증서'), findsOneWidget);
    expect(find.text('이미지 저장'), findsOneWidget);
    expect(find.text('공유하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed_at이 있으면 계절 배지와 탄생 시간이 인증서에 실린다', (tester) async {
    await pumpCard(tester, buildArgs(heightCm: 34));

    expect(find.text('☀️ 한여름에 완성 · 34cm'), findsOneWidget);
    expect(find.text('🐣 2026. 08. 20 · 14:32:07'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('buildCertificateImageFilename은 묘목 id로 파일명을 만든다', () {
    expect(buildCertificateImageFilename(3), 'pigfig_certificate_3.png');
  });
}
