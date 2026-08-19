import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/adopter/presentation/adopt/adopt_screen.dart';
import 'features/adopter/presentation/adopter_shell.dart';
import 'features/adopter/presentation/care/nutrient_care_screen.dart';
import 'features/adopter/presentation/care/pig_feed_care_screen.dart';
import 'features/adopter/presentation/care/sunlight_care_screen.dart';
import 'features/adopter/presentation/care/water_care_screen.dart';
import 'features/adopter/presentation/chatbot_screen.dart';
import 'features/adopter/presentation/diary_detail_screen.dart';
import 'features/adopter/presentation/donation_certificate_screen.dart';
import 'features/adopter/presentation/pickup_donate_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/grower/presentation/grower_activity_calendar_screen.dart';
import 'features/grower/presentation/grower_anomaly_summary_screen.dart';
import 'features/grower/presentation/grower_complete_screen.dart';
import 'features/grower/presentation/grower_faq_screen.dart';
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
        '/grower': (context) => const GrowerShell(),
        '/grower/complete': (context) => const GrowerCompleteScreen(),
        '/grower/activity-calendar': (context) =>
            const GrowerActivityCalendarScreen(),
        '/grower/anomaly-summary': (context) =>
            const GrowerAnomalySummaryScreen(),
        '/grower/faq': (context) => const GrowerFaqScreen(),
        '/adopter/care/water': (context) => const WaterCareScreen(),
        '/adopter/care/nutrient': (context) => const NutrientCareScreen(),
        '/adopter/care/sunlight': (context) => const SunlightCareScreen(),
        '/adopter/care/pig-feed': (context) => const PigFeedCareScreen(),
        '/adopter/pickup-donate': (context) => const PickupDonateScreen(),
        '/adopter/donation-certificate': (context) =>
            const DonationCertificateScreen(),
        '/adopter/chatbot': (context) => const ChatbotScreen(),
        '/adopter/diary-detail': (context) => const DiaryDetailScreen(),
      },
    );
  }
}
