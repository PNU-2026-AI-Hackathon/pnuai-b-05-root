import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';

/// 성장 타임라인 카드 상세를 중앙 카드 모달로 띄운다 — 사진(또는 일러스트)을 카드
/// 상단에 크게 보고 날짜/내용 전문을 읽을 수 있다. 배경은 dim 처리되고, 바깥을
/// 탭하거나 우측 상단 닫기(X) 버튼으로 닫힌다(`showDialog`의 기본
/// `barrierDismissible`이 바깥 탭 닫기를 그대로 제공한다).
Future<void> showDiaryDetailDialog(
  BuildContext context, {
  required String content,
  required DateTime createdAt,
  String? photoUrl,
  String? illustrationUrl,
}) {
  // Gemini로 변환된 일러스트가 있으면 그것을, 없으면 원본 사진을 보여준다
  // (카드 목록과 동일한 우선순위).
  final imageUrl = illustrationUrl ?? photoUrl;

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (dialogContext) => Center(
      child: Container(
        width: MediaQuery.of(dialogContext).size.width * 0.82,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 220,
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
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(createdAt),
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          content,
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
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.'
    '${date.day.toString().padLeft(2, '0')}';

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
