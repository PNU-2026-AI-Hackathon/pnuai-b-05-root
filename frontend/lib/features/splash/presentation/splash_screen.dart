import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/pigfig_logo.dart';

/// 앱 최초 진입 시 잠깐 보여주는 스플래시 화면. 로고가 로그인 화면(74px)까지
/// Hero 애니메이션으로 자연스럽게 이어진다 — 태그('pigfig-logo')는 로그인
/// 화면과 반드시 동일해야 한다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beigeBg,
      body: Center(
        child: Hero(
          tag: 'pigfig-logo',
          child: PigFigLogo(size: 120, variant: PigFigLogoVariant.symbol),
        ),
      ),
    );
  }
}
