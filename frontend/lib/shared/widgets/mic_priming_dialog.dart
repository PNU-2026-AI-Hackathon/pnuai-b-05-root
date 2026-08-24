import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'pigfig_button.dart';

/// OS/브라우저의 마이크 권한 요청 다이얼로그는 디자인을 바꿀 수 없어,
/// 그 앞에 먼저 보여주는 Pig.Fig. 브랜드 톤의 커스텀 "프라이밍" 다이얼로그.
///
/// `true`(허용할게요)를 반환하면 호출부가 그때 실제 음성 인식 초기화(권한 요청)를
/// 트리거하고, `false`/`null`(나중에·바깥 탭)이면 그 요청 자체를 건너뛴다.
Future<bool?> showMicPrimingDialog(BuildContext context) {
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
          const Text('🎤', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(
            'Pig.Fig.가 마이크를 사용해도 될까요?',
            textAlign: TextAlign.center,
            style: AppTextStyles.title(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '음성으로 일지를 편하게 입력할 수 있어요!',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 22),
          PigFigButton.primary(
            label: '허용할게요 🎤',
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
