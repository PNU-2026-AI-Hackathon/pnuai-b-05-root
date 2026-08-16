import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/grower_repository.dart';
import 'grower_complete_screen.dart';

/// 1r — 재배자 대시보드: 담당 묘목 현황 요약 + 목록. `GET /api/seedlings/`와 실제 연동한다.
class GrowerDashboardScreen extends StatefulWidget {
  const GrowerDashboardScreen({super.key});

  @override
  State<GrowerDashboardScreen> createState() => _GrowerDashboardScreenState();
}

class _GrowerDashboardScreenState
    extends RevalidatableState<GrowerDashboardScreen> {
  final _repository = GrowerRepository();

  bool _loading = true;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  List<Seedling> _seedlings = const [];

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
      setState(() => _seedlings = seedlings);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
      _hasLoadedOnce = true;
    }
  }

  /// `GrowerShell`이 홈 탭 재진입 시 호출한다. 일지/환경점검 탭에 다녀오는 동안
  /// 통계가 바뀌었을 수 있으니 다시 불러오되, 기존 목록은 그대로 둔 채 응답이 오면
  /// 조용히 교체한다.
  @override
  Future<void> revalidate() async {
    if (!_hasLoadedOnce) return _load();
    try {
      final seedlings = await _repository.fetchSeedlings();
      if (mounted) setState(() => _seedlings = seedlings);
    } on ApiException {
      // 재조회 실패 시 기존 목록을 그대로 유지한다.
    }
  }

  Future<void> _openComplete(Seedling seedling) async {
    await Navigator.of(context).pushNamed(
      '/grower/complete',
      arguments: GrowerCompleteArgs(
        seedlingId: seedling.id,
        seedlingName: '무화과 #${seedling.id}',
        adopterName: '입양자 #${seedling.adopterId}',
      ),
    );
    // 완성 신고를 마치고 돌아오면(또는 그냥 닫아도) 최신 상태를 다시 불러온다.
    if (mounted) _load();
  }

  void _showAlreadyCompletedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이미 완성된 묘목이에요 🎉')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: _buildBody(),
      ),
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
    if (_seedlings.isEmpty) {
      return const _EmptyState();
    }

    final total = _seedlings.length;
    final growing = _seedlings
        .where((s) => s.status == SeedlingStatus.growing)
        .length;
    final completed = total - growing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '$total',
                valueColor: AppColors.badgeGreenText,
                label: '담당 묘목',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '$growing',
                valueColor: AppColors.orange400,
                label: '재배중',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '$completed',
                valueColor: AppColors.pink500,
                label: '완료',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('담당 묘목 목록', style: AppTextStyles.title(fontSize: 17)),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _seedlings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final seedling = _seedlings[index];
                return _SeedlingCard(
                  seedling: seedling,
                  onTap: seedling.status == SeedlingStatus.growing
                      ? () => _openComplete(seedling)
                      : _showAlreadyCompletedMessage,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.valueColor,
    required this.label,
  });

  final String value;
  final Color valueColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.title(
              fontSize: 22,
              color: valueColor,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _SeedlingCard extends StatelessWidget {
  const _SeedlingCard({required this.seedling, required this.onTap});

  final Seedling seedling;
  final VoidCallback? onTap;

  static String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isGrowing = seedling.status == SeedlingStatus.growing;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isGrowing ? 1.0 : 0.65,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isGrowing
                      ? AppColors.badgeGreenBg
                      : AppColors.dotInactive,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const FigTreeIllustration(width: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '무화과 #${seedling.id}',
                      style: AppTextStyles.title(
                        fontSize: 15,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '입양자 #${seedling.adopterId}',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGrowing
                          ? '시작일 ${_formatDate(seedling.startedAt)}'
                          : '완료일 ${_formatDate(seedling.completedAt!)}',
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: const Color(0xFFB7B2A4),
                      ),
                    ),
                  ],
                ),
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
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FigTreeIllustration(width: 64),
          const SizedBox(height: 16),
          Text(
            '아직 담당하는 묘목이 없어요',
            style: AppTextStyles.body(
              fontSize: 15,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '묘목이 배정되면 여기에 표시돼요',
            style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
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
            Text('😢', style: const TextStyle(fontSize: 40)),
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
