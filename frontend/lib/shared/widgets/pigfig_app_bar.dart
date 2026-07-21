import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Pig.Fig 로고 + 우측 액션(알림종 또는 "닫기" 텍스트)이 있는 공통 상단 바.
class PigFigAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PigFigAppBar({
    super.key,
    this.showNotificationBell = false,
    this.closeLabel,
    this.onClose,
    this.onProfileTap,
  });

  final bool showNotificationBell;
  final String? closeLabel;
  final VoidCallback? onClose;

  /// 재배자 대시보드처럼 마이페이지 탭이 따로 없는 화면에서 로그아웃/회원탈퇴
  /// 메뉴로 들어가는 진입점이 필요할 때만 지정한다. 지정하면 벨 아이콘 옆에
  /// 사람 아이콘 버튼이 표시된다.
  final VoidCallback? onProfileTap;

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
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.pink500,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text('Pig.Fig.', style: AppTextStyles.display(fontSize: 20)),
          const Spacer(),
          if (onProfileTap != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: onProfileTap,
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.pink500,
                  size: 22,
                ),
              ),
            ),
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
