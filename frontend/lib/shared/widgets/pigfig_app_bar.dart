import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'pigfig_logo.dart';

/// Pig.Fig 로고 + 우측 액션(알림종 또는 "닫기" 텍스트)이 있는 공통 상단 바.
class PigFigAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PigFigAppBar({
    super.key,
    this.showNotificationBell = false,
    this.closeLabel,
    this.onClose,
  });

  final bool showNotificationBell;
  final String? closeLabel;
  final VoidCallback? onClose;

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const PigFigLogo(size: 30, variant: PigFigLogoVariant.symbol),
          const SizedBox(width: 8),
          Text('Pig.Fig.', style: AppTextStyles.display(fontSize: 20)),
          const Spacer(),
          if (showNotificationBell)
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications,
                  color: AppColors.pink500,
                  size: 22,
                ),
                Positioned(
                  top: 0,
                  right: -1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          if (closeLabel != null)
            GestureDetector(
              onTap: onClose ?? () => Navigator.of(context).maybePop(),
              child: Text(
                closeLabel!,
                style: AppTextStyles.body(color: const Color(0xFFB7B2A4)),
              ),
            ),
        ],
      ),
    );
  }
}
