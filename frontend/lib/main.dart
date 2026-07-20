import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/adopter/presentation/adopter_shell.dart';
import 'features/adopter/presentation/care/nutrient_care_screen.dart';
import 'features/adopter/presentation/care/pruning_care_screen.dart';
import 'features/adopter/presentation/care/sunlight_care_screen.dart';
import 'features/adopter/presentation/care/water_care_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/grower/presentation/grower_complete_screen.dart';
import 'features/grower/presentation/grower_shell.dart';

void main() {
  runApp(const PigFigApp());
}

class PigFigApp extends StatelessWidget {
  const PigFigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pig.Fig.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/adopter': (context) => const AdopterShell(),
        '/grower': (context) => const GrowerShell(),
        '/grower/complete': (context) => const GrowerCompleteScreen(),
        '/adopter/care/water': (context) => const WaterCareScreen(),
        '/adopter/care/nutrient': (context) => const NutrientCareScreen(),
        '/adopter/care/sunlight': (context) => const SunlightCareScreen(),
        '/adopter/care/pruning': (context) => const PruningCareScreen(),
      },
    );
  }
}
