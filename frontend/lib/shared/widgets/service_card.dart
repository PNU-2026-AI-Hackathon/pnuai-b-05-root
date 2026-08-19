import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 아이콘 원 + 제목 + 짧은 설명으로 구성된 2x2 서비스 카드 그리드용 카드.
/// 흰 배경/radius 22/그림자는 [games_screen.dart]의 `_GameCard`와 동일한 톤이며,
/// 입양자 마이페이지·재배자 마이페이지가 함께 쓰는 공용 위젯이다.
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.emoji,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String emoji;
  final Color iconBg;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.body(
                fontSize: 14,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textMuted,
              ).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
