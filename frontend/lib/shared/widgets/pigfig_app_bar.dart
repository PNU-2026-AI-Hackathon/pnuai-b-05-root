import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'pigfig_logo.dart';

/// Pig.Fig 로고 + (선택적으로) 우측 "닫기" 텍스트가 있는 공통 상단 바.
class PigFigAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PigFigAppBar({
    super.key,
    this.closeLabel,
    this.onClose,
  });

  final String? closeLabel;
  final VoidCallback? onClose;

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    // Scaffold는 앱바 슬롯에 상태바 높이만큼 여유 공간을 미리 확보해주지만, 그 안에서
    // 실제로 내용을 밀어내는 건 위젯 몫이다(진짜 AppBar도 내부적으로 이렇게 처리한다).
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const PigFigLogo(size: 30, variant: PigFigLogoVariant.symbol),
              const SizedBox(width: 8),
              Text('Pig.Fig.', style: AppTextStyles.display(fontSize: 20)),
              const Spacer(),
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
        ),
      ),
    );
  }
}
