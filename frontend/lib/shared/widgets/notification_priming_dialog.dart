import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'pigfig_button.dart';

/// Android OS의 알림 권한(`POST_NOTIFICATIONS`) 요청 다이얼로그는 디자인을 바꿀 수 없어,
/// 그 앞에 먼저 보여주는 Pig.Fig. 브랜드 톤의 커스텀 "프라이밍" 다이얼로그.
///
/// `true`(허용할게요)를 반환하면 호출부가 그때 실제 OS 권한 요청을 트리거하고,
/// `false`/`null`(나중에·바깥 탭)이면 OS 권한 요청 자체를 건너뛴다.
Future<bool?> showNotificationPrimingDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(
            'Pig.Fig.에서 알림을 받으시겠어요?',
            textAlign: TextAlign.center,
            style: AppTextStyles.title(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '무화과가 다 자랐을 때 알려드려요!',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 22),
          PigFigButton.primary(
            label: '허용할게요 🔔',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '나중에',
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    ),
  );
}
