import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum _PigFigButtonVariant { primary, positive, outline }

/// 디자인 시스템 버튼 3종: Pink(주요) / Green(긍정) / Outline(보조).
class PigFigButton extends StatelessWidget {
  const PigFigButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  }) : _variant = _PigFigButtonVariant.primary;

  const PigFigButton.positive({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  }) : _variant = _PigFigButtonVariant.positive;

  const PigFigButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  }) : _variant = _PigFigButtonVariant.outline;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final _PigFigButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final isOutline = _variant == _PigFigButtonVariant.outline;
    final background = switch (_variant) {
      _PigFigButtonVariant.primary => AppColors.pink500,
      _PigFigButtonVariant.positive => AppColors.green500,
      _PigFigButtonVariant.outline => Colors.white,
    };
    final foreground = isOutline ? const Color(0xFF6B675C) : Colors.white;

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: foreground,
            ),
          )
        : Text(
            label,
            style: AppTextStyles.button(
              color: foreground,
              fontSize: isOutline ? 14 : 16,
            ),
          );

    return SizedBox(
      width: double.infinity,
      height: isOutline ? 44 : 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: StadiumBorder(
            side: isOutline
                ? const BorderSide(color: AppColors.outline, width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }
}
