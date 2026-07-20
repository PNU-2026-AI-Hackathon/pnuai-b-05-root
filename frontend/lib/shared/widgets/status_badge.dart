import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 배지/스테이지 칩 (예: "정상", "잎 성장 중").
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.background = AppColors.green500,
    this.textColor = Colors.white,
    this.pill = true,
  });

  final String label;
  final Color background;
  final Color textColor;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pill ? 16 : 12, vertical: pill ? 8 : 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(pill ? 20 : 14),
      ),
      child: Text(
        label,
        style: AppTextStyles.body(fontSize: pill ? 13 : 12, color: textColor)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
