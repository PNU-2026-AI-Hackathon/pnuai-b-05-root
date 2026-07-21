import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../data/diary_repository.dart';
import '../data/seedling_repository.dart';

/// 1k — 성장 타임라인: `GET /api/diary/{seedling_id}/`와 실제 연동해 재배자 일지를
/// 시간 역순(최신이 먼저)으로 나열한다.
class GrowthTimelineScreen extends StatefulWidget {
  const GrowthTimelineScreen({super.key});

  @override
  State<GrowthTimelineScreen> createState() => _GrowthTimelineScreenState();
}

class _GrowthTimelineScreenState extends State<GrowthTimelineScreen> {
  final _seedlingRepository = SeedlingRepository();
  final _diaryRepository = DiaryRepository();

  bool _loading = true;
  String? _errorMessage;
  bool _hasSeedling = false;
  List<DiaryEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedlings = await _seedlingRepository.fetchSeedlings();
      final primary = pickPrimarySeedling(seedlings);
      if (primary == null) {
        setState(() {
          _hasSeedling = false;
          _entries = const [];
        });
      } else {
        final entries = await _diaryRepository.fetchDiaries(primary.id);
        setState(() {
          _hasSeedling = true;
          _entries = entries;
        });
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📸 성장 타임라인',
              style: AppTextStyles.title(
                fontSize: 20,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '재배자가 남긴 일지를 시간 순서로 볼 수 있어요',
              style: AppTextStyles.guide(
                fontSize: 14,
                color: AppColors.badgeGreenText,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
    }
    if (_errorMessage != null) {
      return _MessageState(
        emoji: '😢',
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    if (!_hasSeedling) {
      return const _MessageState(emoji: '🌱', message: '아직 입양한 무화과가 없어요');
    }
    if (_entries.isEmpty) {
      return const _MessageState(
        emoji: '📋',
        message: '아직 작성된 일지가 없어요\n재배자가 곧 소식을 전해드릴게요!',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _TimelineCard(entry: _entries[index]),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entry});

  final DiaryEntry entry;

  static String _formatDate(DateTime date) =>
      '${date.month}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.badgeGreenBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: entry.photoUrl != null
                      ? Image.network(
                          entry.photoUrl!,
                          fit: BoxFit.cover,
                          width: 78,
                          height: 78,
                          errorBuilder: (context, error, stackTrace) =>
                              const FigTreeIllustration(width: 32),
                        )
                      : const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: FigTreeIllustration(width: 32),
                        ),
                ),
                if (entry.photoUrl == null)
                  Positioned(
                    bottom: -7,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pink100,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '✨ 일러스트 변환',
                          style: AppTextStyles.body(
                            fontSize: 10,
                            color: AppColors.badgePinkText,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(entry.createdAt),
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: const Color(0xFFB7B2A4),
                      ),
                    ),
                    if (entry.yoloStatusTag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.badgeGreenBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          entry.yoloStatusTag!,
                          style: AppTextStyles.body(
                            fontSize: 11,
                            color: AppColors.badgeGreenText,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  entry.content,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.emoji,
    required this.message,
    this.onRetry,
  });

  final String emoji;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }
}
