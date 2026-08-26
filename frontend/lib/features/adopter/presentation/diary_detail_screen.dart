import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/download/image_downloader.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/status_badge.dart';
import 'photo_frame_carousel.dart';

/// `/adopter/diary-detail` route argument.
class DiaryDetailArgs {
  const DiaryDetailArgs({
    required this.diaryId,
    required this.content,
    required this.createdAt,
    this.photoUrl,
    this.illustrationUrl,
  });

  final int diaryId;
  final String content;
  final DateTime createdAt;
  final String? photoUrl;
  final String? illustrationUrl;
}

/// 일지 상세를 다운로드 가능한 사진 저장용 파일명으로 변환한다(순수 함수라 단독 테스트 가능).
String buildDiaryImageFilename(int diaryId, DateTime createdAt) {
  final y = createdAt.year.toString().padLeft(4, '0');
  final m = createdAt.month.toString().padLeft(2, '0');
  final d = createdAt.day.toString().padLeft(2, '0');
  return 'pigfig_diary_${diaryId}_$y$m$d.png';
}

/// 성장 타임라인 카드 상세를 풀스크린으로 보여준다 — 사진(또는 일러스트)이 세로로 길거나
/// 가로로 길어도 `BoxFit.contain`이라 잘리지 않고, `InteractiveViewer`로 확대해서 볼 수
/// 있다. 화면에 표시된 이미지(일러스트 우선, 없으면 원본 사진)를 그대로 기기에 저장하는
/// 다운로드 버튼도 제공한다. 예전에는 이 화면이 실제로 이 라우트로 존재했다가 "탭 목록
/// 위에 살짝 띄우는 느낌"을 위해 모달로 바뀐 적이 있는데, 이번에 사진 크롭 문제와 다운로드
/// 요구사항 때문에 다시 풀스크린 라우트로 되돌렸다.
class DiaryDetailScreen extends StatefulWidget {
  const DiaryDetailScreen({super.key});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  bool _downloading = false;
  bool _sharing = false;
  final _carouselKey = GlobalKey<PhotoFrameCarouselState>();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as DiaryDetailArgs;
    // Gemini로 변환된 일러스트가 있으면 그것을, 없으면 원본 사진을 보여준다(카드 목록과
    // 동일한 우선순위) — 다운로드도 이 화면에 실제로 표시된 이미지를 대상으로 한다.
    final imageUrl = args.illustrationUrl ?? args.photoUrl;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🌱', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text('무화과 이야기', style: AppTextStyles.title(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.pink500,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              imageUrl != null
                  ? PhotoFrameCarousel(key: _carouselKey, imageUrl: imageUrl)
                  : SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.48,
                      child: const _ImagePlaceholder(),
                    ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(
                      label: _formatDate(args.createdAt),
                      background: AppColors.badgeGreenBg,
                      textColor: AppColors.badgeGreenText,
                      pill: false,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.outline, height: 1),
                    const SizedBox(height: 14),
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
              if (imageUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: PigFigButton.outline(
                          label: '저장 📥',
                          loading: _downloading,
                          onPressed: _sharing ? null : () => _download(args),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PigFigButton.outline(
                          label: '공유 📤',
                          loading: _sharing,
                          onPressed: _downloading ? null : () => _share(args),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _download(DiaryDetailArgs args) async {
    setState(() => _downloading = true);
    try {
      final bytes = await _carouselKey.currentState?.captureCurrentFrame();
      if (bytes == null) {
        throw Exception('이미지를 불러오지 못했어요.');
      }
      await saveImageBytes(
        bytes,
        buildDiaryImageFilename(args.diaryId, args.createdAt),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진을 저장했어요 📥')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _share(DiaryDetailArgs args) async {
    setState(() => _sharing = true);
    try {
      final bytes = await _carouselKey.currentState?.captureCurrentFrame();
      if (bytes == null) {
        throw Exception('이미지를 불러오지 못했어요.');
      }
      final filename = buildDiaryImageFilename(args.diaryId, args.createdAt);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: filename)],
          fileNameOverrides: [filename],
        ),
      );
      // 사용자가 공유 시트를 취소한 것은 실패가 아니므로 에러로 안내하지 않는다.
      if (result.status == ShareResultStatus.dismissed) {
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공유에 실패했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
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
