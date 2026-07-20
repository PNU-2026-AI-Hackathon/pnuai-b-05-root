import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/gauge_bar.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';

/// 재배자가 담당한 묘목 한 건의 mock 데이터.
class _SeedlingSummary {
  const _SeedlingSummary({
    required this.name,
    required this.adopterName,
    required this.progress,
    required this.stage,
    required this.normal,
    this.anomalyNote,
  });

  final String name;
  final String adopterName;
  final double progress; // 0.0~1.0
  final int stage; // 0~5
  final bool normal;
  final String? anomalyNote;
}

/// 1r — 재배자 대시보드: 담당 묘목 현황 요약 + 목록. mock 데이터로 표시한다.
class GrowerDashboardScreen extends StatelessWidget {
  const GrowerDashboardScreen({super.key});

  static const _seedlings = [
    _SeedlingSummary(name: '무화과 #001', adopterName: '김입양', progress: 0.6, stage: 3, normal: true),
    _SeedlingSummary(name: '무화과 #002', adopterName: '이돌봄', progress: 0.8, stage: 4, normal: true),
    _SeedlingSummary(
      name: '무화과 #003',
      adopterName: '박관리',
      progress: 0.4,
      stage: 2,
      normal: false,
      anomalyNote: '습도 이상 ⚠️',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _StatCard(value: '12', valueColor: AppColors.badgeGreenText, label: '담당 묘목')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(value: '3', valueColor: AppColors.pink500, label: '완성 임박')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(value: '1', valueColor: AppColors.orange400, label: '이상 감지')),
              ],
            ),
            const SizedBox(height: 16),
            Text('담당 묘목 목록', style: AppTextStyles.title(fontSize: 17)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _seedlings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _SeedlingCard(seedling: _seedlings[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.valueColor, required this.label});

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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.title(fontSize: 22, color: valueColor).copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.body(fontSize: 12, color: AppColors.textMuted).copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SeedlingCard extends StatelessWidget {
  const _SeedlingCard({required this.seedling});

  final _SeedlingSummary seedling;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        border: seedling.normal ? null : Border.all(color: AppColors.pink100, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: seedling.normal ? AppColors.badgeGreenBg : const Color(0xFFFDEFF2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Opacity(
                  opacity: seedling.normal ? 1 : 0.75,
                  child: const FigTreeIllustration(width: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(seedling.name, style: AppTextStyles.title(fontSize: 15).copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      seedling.anomalyNote == null
                          ? '입양자: ${seedling.adopterName}'
                          : '입양자: ${seedling.adopterName} · ${seedling.anomalyNote}',
                      style: AppTextStyles.body(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: seedling.normal ? '정상' : '주의',
                background: seedling.normal ? AppColors.green500 : AppColors.pink100,
                textColor: seedling.normal ? Colors.white : AppColors.warningPink,
                pill: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: GaugeBar(value: seedling.progress, height: 8)),
              const SizedBox(width: 10),
              Text('${seedling.stage}/5', style: AppTextStyles.body(fontSize: 12, color: AppColors.textMuted).copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
