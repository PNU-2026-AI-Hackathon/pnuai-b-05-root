import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 라운드형 게이지/프로그레스 바. [value]는 0.0~1.0.
class GaugeBar extends StatelessWidget {
  const GaugeBar({
    super.key,
    required this.value,
    this.height = 12,
    this.fillColor = AppColors.green500,
    this.trackColor = const Color(0xFFECEAE0),
    this.label,
    this.trailing,
  });

  final double value;
  final double height;
  final Color fillColor;
  final Color trackColor;
  final String? label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: trackColor,
        valueColor: AlwaysStoppedAnimation(fillColor),
      ),
    );

    if (label == null && trailing == null) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null || trailing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(label!, style: AppTextStyles.body(fontSize: 13, color: fillColor).copyWith(fontWeight: FontWeight.w700)),
                if (trailing != null)
                  Text(trailing!, style: AppTextStyles.body(fontSize: 13, color: fillColor).copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        bar,
      ],
    );
  }
}
