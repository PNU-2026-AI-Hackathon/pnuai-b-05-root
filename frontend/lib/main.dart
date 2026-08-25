import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/adopter/presentation/adopt/adopt_screen.dart';
import 'features/adopter/presentation/adoption_history_screen.dart';
import 'features/adopter/presentation/adopter_shell.dart';
import 'features/adopter/presentation/care/nutrient_care_screen.dart';
import 'features/adopter/presentation/care/pig_feed_care_screen.dart';
import 'features/adopter/presentation/care/sunlight_care_screen.dart';
import 'features/adopter/presentation/care/water_care_screen.dart';
import 'features/adopter/presentation/chatbot_screen.dart';
import 'features/adopter/presentation/diary_detail_screen.dart';
import 'features/adopter/presentation/donation_certificate_list_screen.dart';
import 'features/adopter/presentation/donation_certificate_screen.dart';
import 'features/adopter/presentation/pickup_donate_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/grower/presentation/grower_activity_calendar_screen.dart';
import 'features/grower/presentation/grower_anomaly_summary_screen.dart';
import 'features/grower/presentation/grower_complete_screen.dart';
import 'features/grower/presentation/grower_diary_list_screen.dart';
import 'features/grower/presentation/grower_diary_write_screen.dart';
import 'features/grower/presentation/grower_faq_screen.dart';
import 'features/grower/presentation/grower_font_scale_scope.dart';
import 'features/grower/presentation/grower_seedling_analysis_screen.dart';
import 'features/grower/presentation/grower_shell.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // google-services.json이 Android에만 설정돼 있어, 다른 플랫폼(web/windows 등)에서
  // Firebase.initializeApp()을 호출하면 즉시 크래시한다.
  if (!kIsWeb && Platform.isAndroid) {
    await Firebase.initializeApp();
  }
  runApp(const PigFigApp(initialRoute: '/splash'));
}

class PigFigApp extends StatelessWidget {
  const PigFigApp({super.key, this.initialRoute = '/'});

  /// 항상 `/`(로그인)에서 시작한다. 온보딩은 입양자 로그인 성공 직후에만 보여준다.
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pig.Fig.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: initialRoute,
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/adopter': (context) => const AdopterShell(),
        '/adopter/adopt': (context) => const AdoptScreen(),
        // 재배자 화면은 전부 GrowerFontScaleScope로 감싸 저장된 글자 크기 배율을
        // 적용한다 — 이 프로젝트는 단일 루트 Navigator라(중첩 라우터 없음) push
        // 화면이 GrowerShell의 자손이 아니므로, GrowerShell 안에서만 MediaQuery를
        // 감싸면 나머지 /grower/* 화면에는 적용되지 않는다(grower_font_scale_scope.dart 참고).
        '/grower': (context) =>
            const GrowerFontScaleScope(child: GrowerShell()),
        '/grower/complete': (context) =>
            const GrowerFontScaleScope(child: GrowerCompleteScreen()),
        '/grower/diary-list': (context) =>
            const GrowerFontScaleScope(child: GrowerDiaryListScreen()),
        '/grower/diary-write': (context) =>
            const GrowerFontScaleScope(child: GrowerDiaryWriteScreen()),
        '/grower/seedling-analysis': (context) => const GrowerFontScaleScope(
          child: GrowerSeedlingAnalysisScreen(),
        ),
        '/grower/activity-calendar': (context) => const GrowerFontScaleScope(
          child: GrowerActivityCalendarScreen(),
        ),
        '/grower/anomaly-summary': (context) => const GrowerFontScaleScope(
          child: GrowerAnomalySummaryScreen(),
        ),
        '/grower/faq': (context) =>
            const GrowerFontScaleScope(child: GrowerFaqScreen()),
        '/adopter/care/water': (context) => const WaterCareScreen(),
        '/adopter/care/nutrient': (context) => const NutrientCareScreen(),
        '/adopter/care/sunlight': (context) => const SunlightCareScreen(),
        '/adopter/care/pig-feed': (context) => const PigFeedCareScreen(),
        '/adopter/pickup-donate': (context) => const PickupDonateScreen(),
        '/adopter/donation-certificate': (context) =>
            const DonationCertificateScreen(),
        '/adopter/donation-certificates': (context) =>
            const DonationCertificateListScreen(),
        '/adopter/chatbot': (context) => const ChatbotScreen(),
        '/adopter/diary-detail': (context) => const DiaryDetailScreen(),
        '/adopter/adoption-history': (context) => const AdoptionHistoryScreen(),
      },
    );
  }
}
