import 'package:flutter/material.dart';

import '../../../core/storage/onboarding_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/step_indicator.dart';

/// 1b~1c — 온보딩: 서비스 소개 / 시니어 재배자. 최초 실행 시 1회만 노출된다.
/// (디자인 문서에는 온보딩 3 "앱으로 케어"도 있으나 이번 범위는 2장으로 한정)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 2;

  final _controller = PageController();
  final _storage = OnboardingStorage();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _storage.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [
                  _OnboardingPage(
                    illustration: _ShopIllustration(),
                    title: '도심 빈 상가에서\n무화과가 자라요',
                    subtitle: '비어 있던 동네 상가가\n작은 무화과 농장이 됩니다.',
                  ),
                  _OnboardingPage(
                    illustration: _SeniorGrowerIllustration(),
                    title: '시니어 재배자가\n정성껏 돌봐드려요',
                    subtitle: '경험 많은 시니어 재배자가\n내 묘목을 매일 보살피고 기록해요.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
              child: Column(
                children: [
                  DotProgressIndicator(current: _page, total: _pageCount),
                  const SizedBox(height: 20),
                  isLastPage
                      ? PigFigButton.positive(
                          label: '시작하기 🌱',
                          onPressed: _finish,
                        )
                      : PigFigButton.primary(label: '다음', onPressed: _next),
                  const SizedBox(height: 20),
                  Visibility(
                    visible: !isLastPage,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: GestureDetector(
                      onTap: _finish,
                      child: Text(
                        '건너뛰기',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: const Color(0xFFB7B2A4),
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.illustration,
    required this.title,
    required this.subtitle,
  });

  final Widget illustration;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          illustration,
          const SizedBox(height: 26),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: 30).copyWith(height: 1.35),
          ),
          const SizedBox(height: 26),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 15,
              color: AppColors.textMuted,
            ).copyWith(height: 1.7),
          ),
        ],
      ),
    );
  }
}

/// 온보딩 1 일러스트: 상가 건물 + 미니 무화과나무.
class _ShopIllustration extends StatelessWidget {
  const _ShopIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 130,
      child: Stack(
        children: [
          const Positioned(
            bottom: 0,
            left: 0,
            child: _RoundedBox(
              width: 150,
              height: 86,
              color: Colors.white,
              radius: 14,
            ),
          ),
          const Positioned(
            bottom: 70,
            left: -5,
            child: _RoundedBox(
              width: 160,
              height: 26,
              color: AppColors.pink500,
              radius: 8,
            ),
          ),
          Positioned(
            bottom: 96,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Pig.Fig. 상점',
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.pink500,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 22,
            child: Container(
              width: 34,
              height: 54,
              decoration: const BoxDecoration(
                color: AppColors.pink100,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 26,
            child: SizedBox(
              width: 60,
              height: 44,
              child: Stack(
                children: [
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: _RoundedBox(
                      width: 8,
                      height: 22,
                      color: AppColors.brown600,
                      radius: 3,
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    left: 8,
                    child: _Circle(size: 26, color: AppColors.green800),
                  ),
                  Positioned(
                    top: 3,
                    right: 8,
                    child: const _Circle(size: 24, color: Color(0xFF456B3A)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 온보딩 2 일러스트: 시니어 재배자(할머니) + 케어 아이콘.
class _SeniorGrowerIllustration extends StatelessWidget {
  const _SeniorGrowerIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text('👵', style: TextStyle(fontSize: 46)),
          ),
          const Positioned(
            right: 6,
            bottom: 2,
            child: _EmojiBadge(
              size: 44,
              background: AppColors.badgeGreenBg,
              emoji: '🌱',
              fontSize: 22,
            ),
          ),
          const Positioned(
            left: 0,
            top: 2,
            child: _EmojiBadge(
              size: 40,
              background: AppColors.pink100,
              emoji: '💧',
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedBox extends StatelessWidget {
  const _RoundedBox({
    required this.width,
    required this.height,
    required this.color,
    required this.radius,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({
    required this.size,
    required this.background,
    required this.emoji,
    required this.fontSize,
  });

  final double size;
  final Color background;
  final String emoji;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(emoji, style: TextStyle(fontSize: fontSize)),
    );
  }
}
