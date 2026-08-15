import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'pigfig_button.dart';

/// 사진 첨부 시 "카메라로 촬영 / 갤러리에서 선택" 중 하나를 고르는 다이얼로그.
///
/// `ImageSource`를 반환하면 호출부가 그 소스로 `ImagePicker`를 실행하고,
/// `null`(취소·바깥 탭)이면 아무것도 하지 않는다.
Future<ImageSource?> showPhotoSourceDialog(BuildContext context) {
  return showDialog<ImageSource>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '사진을 어떻게 추가할까요?',
            textAlign: TextAlign.center,
            style: AppTextStyles.title(fontSize: 18),
          ),
          const SizedBox(height: 22),
          PigFigButton.primary(
            label: '카메라로 촬영 📷',
            onPressed: () => Navigator.of(dialogContext).pop(ImageSource.camera),
          ),
          const SizedBox(height: 10),
          PigFigButton.outline(
            label: '갤러리에서 선택 🖼️',
            onPressed: () => Navigator.of(dialogContext).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '취소',
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    ),
  );
}
