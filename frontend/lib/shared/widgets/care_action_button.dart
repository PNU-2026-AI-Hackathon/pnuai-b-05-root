import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 홈 화면 우측에 세로로 나열되는 원형 케어 액션 버튼 (물주기/영양제/햇빛).
class CareActionButton extends StatelessWidget {
  const CareActionButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.size = 54,
    this.count,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final double size;

  /// 보유 개수 배지. null이면(예: 햇빛) 배지를 아예 그리지 않는다 — 기존 호출부는
  /// 이 파라미터를 넘기지 않는 한 겉모습이 그대로다.
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
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
              if (count != null)
                Positioned(top: -4, right: -4, child: _CountBadge(count!)),
            ],
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

/// 보유 개수 배지. 0보다 크면 포인트 컬러로 눈에 띄게, 0이면 톤다운해서
/// "지금은 없음"을 은은하게 신호한다(버튼 자체는 비활성화하지 않음).
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.pink500 : AppColors.textMuted,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '$count',
        style: AppTextStyles.caption(
          fontSize: 11,
          color: Colors.white,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
