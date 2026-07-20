import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/gauge_bar.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import 'donation_certificate_screen.dart';

/// 1n — 마이페이지: 프로필 카드 + 리스트 메뉴. mock 데이터로 표시한다.
class MypageScreen extends StatelessWidget {
  const MypageScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileCard(),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _MenuRow(
                    emoji: '📸',
                    iconBg: AppColors.pink100,
                    label: '성장 타임라인',
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/adopter/growth-timeline'),
                  ),
                  _MenuRow(
                    emoji: '🎁',
                    iconBg: AppColors.green500,
                    label: '수령 / 기부 선택',
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/adopter/pickup-donate'),
                  ),
                  _MenuRow(
                    emoji: '📜',
                    iconBg: AppColors.pink100,
                    label: '기부 인증서',
                    onTap: () => Navigator.of(context).pushNamed(
                      '/adopter/donation-certificate',
                      arguments: const DonationCertificateArgs(
                        seedlingName: '무화과 #001',
                        organizationName: '행복 지역아동센터',
                      ),
                    ),
                  ),
                  _MenuRow(
                    emoji: '🤖',
                    iconBg: AppColors.green500,
                    label: 'AI 챗봇 (무화과 Q&A)',
                    onTap: () => _showComingSoon(context),
                  ),
                  _MenuRow(
                    emoji: '🔔',
                    iconBg: AppColors.pink100,
                    label: '알림 설정',
                    onTap: () => _showComingSoon(context),
                  ),
                  _MenuRow(
                    emoji: '📋',
                    iconBg: AppColors.green500,
                    label: '입양 내역',
                    onTap: () => _showComingSoon(context),
                    showDivider: false,
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.pink100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            '김입양',
            style: AppTextStyles.title(
              fontSize: 18,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const StatusBadge(
            label: '입양 중: 1그루 🌱',
            background: AppColors.badgeGreenBg,
            textColor: AppColors.badgeGreenText,
            pill: false,
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F5EC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const FigTreeIllustration(width: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '무화과 #001',
                            style: AppTextStyles.body(
                              fontSize: 12,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '3/5단계 · 정상',
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.badgeGreenText,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const GaugeBar(value: 0.6, height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.emoji,
    required this.iconBg,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  final String emoji;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: Color(0xFFF3F1E9)))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 15,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Text(
              '›',
              style: TextStyle(fontSize: 18, color: AppColors.dotInactive),
            ),
          ],
        ),
      ),
    );
  }
}
