import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

/// 로그아웃/회원탈퇴 확인 다이얼로그 + 후속 처리. 입양자 마이페이지와 재배자
/// 대시보드 메뉴 양쪽에서 동일하게 사용한다.

Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('로그아웃', style: AppTextStyles.title(fontSize: 17)),
      content: Text(
        '정말 로그아웃 하시겠어요?',
        style: AppTextStyles.body(fontSize: 14, color: AppColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            '취소',
            style: AppTextStyles.body(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            '로그아웃',
            style: AppTextStyles.body(
              color: AppColors.pink500,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await AuthRepository().logout();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}

Future<void> confirmDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '회원탈퇴',
        style: AppTextStyles.title(fontSize: 17, color: AppColors.errorRed),
      ),
      content: Text(
        '모든 데이터에 접근할 수 없게 됩니다. 정말 탈퇴하시겠어요?',
        style: AppTextStyles.body(fontSize: 14, color: AppColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            '취소',
            style: AppTextStyles.body(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            '탈퇴하기',
            style: AppTextStyles.body(
              color: AppColors.errorRed,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await AuthRepository().deleteAccount();
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
