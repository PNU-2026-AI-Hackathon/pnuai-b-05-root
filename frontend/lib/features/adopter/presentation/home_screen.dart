import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/care_action_button.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pig_character.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/speech_bubble.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/seedling_repository.dart';

/// 1f — 홈: 나의 무화과. 묘목 상태는 `GET /api/seedlings/`와 실제 연동하고,
/// 케어 게이지(물주기/영양제/햇빛/가지치기)는 여전히 로컬 mock이다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends RevalidatableState<HomeScreen> {
  final _repository = SeedlingRepository();

  bool _loading = true;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  Seedling? _seedling;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedlings = await _repository.fetchSeedlings();
      setState(() => _seedling = pickPrimarySeedling(seedlings));
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
      _hasLoadedOnce = true;
    }
  }

  /// `AdopterShell`이 홈 탭 재진입 시 호출한다. 완성 신고 등으로 묘목 상태가 바뀌었을
  /// 수 있으니 다시 불러오되, 기존 화면은 그대로 둔 채 응답이 오면 조용히 교체한다.
  @override
  Future<void> revalidate() async {
    if (!_hasLoadedOnce) return _load();
    try {
      final seedlings = await _repository.fetchSeedlings();
      if (mounted) setState(() => _seedling = pickPrimarySeedling(seedlings));
    } on ApiException {
      // 재조회 실패 시 기존 화면을 그대로 유지한다.
    }
  }

  Future<void> _goToAdopt() async {
    await Navigator.of(context).pushNamed('/adopter/adopt');
    // 입양 성공/실패와 무관하게 최신 상태를 다시 불러온다.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
    }
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _load);
    }
    if (_seedling == null) {
      return _EmptyState(onAdopt: _goToAdopt);
    }
    return _SeedlingHome(seedling: _seedling!);
  }
}

class _SeedlingHome extends StatelessWidget {
  const _SeedlingHome({required this.seedling});

  final Seedling seedling;

  @override
  Widget build(BuildContext context) {
    final isGrowing = seedling.status == SeedlingStatus.growing;
    final daysTogether =
        DateTime.now().difference(seedling.startedAt).inDays + 1;

    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.pink100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '3일 동안 자리를 비웠더니...',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.badgePinkText,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const FigTreeIllustration(width: 190),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SpeechBubble(text: '꿀꿀~ 내가 왔다!'),
                    const PigCharacter(width: 60),
                  ],
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
        Positioned(
          right: 14,
          top: 96,
          child: Column(
            children: [
              CareActionButton(
                emoji: '💧',
                label: '물주기',
                onTap: () =>
                    Navigator.of(context).pushNamed('/adopter/care/water'),
              ),
              const SizedBox(height: 16),
              CareActionButton(
                emoji: '🍃',
                label: '영양제',
                onTap: () =>
                    Navigator.of(context).pushNamed('/adopter/care/nutrient'),
              ),
              const SizedBox(height: 16),
              CareActionButton(
                emoji: '☀️',
                label: '햇빛',
                onTap: () =>
                    Navigator.of(context).pushNamed('/adopter/care/sunlight'),
              ),
              const SizedBox(height: 16),
              CareActionButton(
                emoji: '✂️',
                label: '가지치기',
                onTap: () =>
                    Navigator.of(context).pushNamed('/adopter/care/pruning'),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '나의 무화과 #${seedling.id} 🌱',
                      style: AppTextStyles.title(),
                    ),
                    StatusBadge(
                      label: isGrowing ? '재배중' : '완료',
                      background: isGrowing
                          ? AppColors.green500
                          : AppColors.pink100,
                      textColor: isGrowing
                          ? Colors.white
                          : AppColors.badgePinkText,
                      pill: false,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGrowing
                      ? '재배자가 정성껏 돌보고 있어요 · 함께한 지 $daysTogether일째'
                      : '무화과가 다 자랐어요! 마이페이지에서 수령/기부를 선택해보세요 🎉',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text('마지막 케어: 오늘', style: AppTextStyles.caption()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdopt});

  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FigTreeIllustration(width: 100),
            const SizedBox(height: 20),
            Text('아직 입양한 무화과가 없어요', style: AppTextStyles.title(fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              '무화과를 입양하면 재배자가 정성껏 키워드려요',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PigFigButton.primary(
                label: '무화과 입양하러 가기',
                onPressed: onAdopt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: PigFigButton.outline(label: '다시 시도', onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}
