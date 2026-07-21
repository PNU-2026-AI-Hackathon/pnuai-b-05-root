import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';

/// `/adopter/diary-detail` route argument: 성장 타임라인 카드에서 탭한 일지 정보.
class DiaryDetailArgs {
  const DiaryDetailArgs({
    required this.content,
    required this.createdAt,
    this.photoUrl,
    this.illustrationUrl,
  });

  final String content;
  final DateTime createdAt;
  final String? photoUrl;
  final String? illustrationUrl;
}

/// 성장 타임라인 카드 상세: 사진(또는 일러스트)을 화면 너비 꽉 채워 크게 보고
/// 일지 전문을 읽는다. `push`되는 상세 화면이라 탭 화면들과 달리 "닫기"로 pop한다.
class DiaryDetailScreen extends StatelessWidget {
  const DiaryDetailScreen({super.key});

  static String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as DiaryDetailArgs;
    // Gemini로 변환된 일러스트가 있으면 그것을, 없으면 원본 사진을 보여준다
    // (카드 목록과 동일한 우선순위).
    final imageUrl = args.illustrationUrl ?? args.photoUrl;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 320,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _ImagePlaceholder(),
                    )
                  : const _ImagePlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(args.createdAt),
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    args.content,
                    style: AppTextStyles.body(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ).copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.badgeGreenBg,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FigTreeIllustration(width: 96),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.pink100,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '✨ 일러스트 변환',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.badgePinkText,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
