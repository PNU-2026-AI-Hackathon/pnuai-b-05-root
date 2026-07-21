import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 홈 화면 우측에 세로로 나열되는 원형 케어 액션 버튼 (물주기/영양제/햇빛/가지치기).
class CareActionButton extends StatelessWidget {
  const CareActionButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.size = 54,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: TextStyle(fontSize: size * 0.4)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 13,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
