import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/grower_repository.dart';
import 'deactivated_adopter_badge.dart';

/// 담당 묘목 통계 3칸(담당 묘목/재배중/완료). 원래는 홈 탭(대시보드)과 일지 탭이 동일한
/// 디자인을 공유하기 위해 뽑은 위젯인데, 홈 탭이 "선반 뷰"(`GrowerShelfScreen`)로 바뀌면서
/// 지금은 `GrowerDiaryTabScreen`(일지 탭)만 사용한다.
class GrowerSeedlingStatsRow extends StatelessWidget {
  const GrowerSeedlingStatsRow({super.key, required this.seedlings});

  final List<Seedling> seedlings;

  @override
  Widget build(BuildContext context) {
    final total = seedlings.length;
    final growing = seedlings
        .where((s) => s.status == SeedlingStatus.growing)
        .length;
    final completed = total - growing;

    return Row(
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

/// 담당 묘목 목록 카드 한 건. `onTap`은 화면마다 다른 동작(완성 신고 화면 이동 vs 일지
/// 리스트 화면 이동)을 연결하기 위해 호출부가 직접 정한다 — 카드 자체의 시각적 표현(재배중/
/// 완료 배지, 흐림 처리)은 두 화면 모두 동일하다.
class GrowerSeedlingListCard extends StatelessWidget {
  const GrowerSeedlingListCard({
    super.key,
    required this.seedling,
    required this.onTap,
  });

  final Seedling seedling;
  final VoidCallback? onTap;

  static String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  /// 입양자 표시 이름 — 닉네임이 있으면 "입양자 {닉네임}", 없으면 "입양자 #{id}"로 폴백.
  String get _adopterLabel {
    final nickname = seedling.adopterNickname;
    return nickname != null && nickname.isNotEmpty
        ? '입양자 $nickname'
        : '입양자 #${seedling.adopterId}';
  }

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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _adopterLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (!seedling.adopterIsActive) ...[
                          const SizedBox(width: 6),
                          const DeactivatedAdopterBadge(),
                        ],
                      ],
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
                textColor: isGrowing ? Colors.white : AppColors.badgePinkText,
                pill: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
