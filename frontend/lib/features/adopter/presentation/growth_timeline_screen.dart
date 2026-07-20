import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';

class _GrowerComment {
  const _GrowerComment({required this.growerName, required this.text});

  final String growerName;
  final String text;
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.illustration,
    required this.stageLabel,
    required this.stageHighlighted,
    required this.date,
    required this.title,
    required this.detail,
    this.comment,
  });

  final Widget illustration;
  final String stageLabel;
  final bool stageHighlighted;
  final String date;
  final String title;
  final String detail;
  final _GrowerComment? comment;
}

/// 1k — 성장 타임라인: 재배자 일지를 시간 역순으로 나열. mock 데이터(diary API 미연동).
class GrowthTimelineScreen extends StatelessWidget {
  const GrowthTimelineScreen({super.key});

  static const _entries = [
    _TimelineEntry(
      illustration: FigTreeIllustration(width: 32),
      stageLabel: '3단계 · 가지 발달',
      stageHighlighted: true,
      date: '7.18',
      title: '가지가 3개로 늘었어요!',
      detail: '키 24cm · 잎 9장',
      comment: _GrowerComment(
        growerName: '박영자 재배자님의 일지',
        text: '"오늘 새 가지에 힘이 붙었어요. 물은 아침에 흠뻑 줬습니다."',
      ),
    ),
    _TimelineEntry(
      illustration: FigTreeIllustration(width: 22),
      stageLabel: '2단계 · 잎 성장',
      stageHighlighted: false,
      date: '7.02',
      title: '첫 잎이 활짝 펴졌어요',
      detail: '키 12cm · 잎 4장',
    ),
    _TimelineEntry(
      illustration: Text('🌱', style: TextStyle(fontSize: 24)),
      stageLabel: '1단계 · 뿌리 내림',
      stageHighlighted: false,
      date: '6.20',
      title: '입양 첫날, 새싹 인사 🌱',
      detail: '키 4cm · 떡잎 2장',
    ),
  ];

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
              '재배자의 사진이 귀여운 일러스트로 변해요',
              style: AppTextStyles.guide(
                fontSize: 14,
                color: AppColors.badgeGreenText,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _entries.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  if (entry.comment == null) return _TimelineCard(entry: entry);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TimelineCard(entry: entry),
                      _GrowerCommentBubble(comment: entry.comment!),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entry});

  final _TimelineEntry entry;

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
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.badgeGreenBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: entry.illustration,
                ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: entry.stageHighlighted
                            ? AppColors.green500
                            : AppColors.badgeGreenBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.stageLabel,
                        style: AppTextStyles.body(
                          fontSize: 11,
                          color: entry.stageHighlighted
                              ? Colors.white
                              : AppColors.badgeGreenText,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      entry.date,
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: const Color(0xFFB7B2A4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  entry.title,
                  style: AppTextStyles.body(
                    fontSize: 14,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.detail,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textMuted,
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

class _GrowerCommentBubble extends StatelessWidget {
  const _GrowerCommentBubble({required this.comment});

  final _GrowerComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(26, 0, 0, 0),
      transform: Matrix4.translationValues(0, -4, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEFF2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Text('👵', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.growerName,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.badgePinkText,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: const Color(0xFF6B675C),
                  ).copyWith(height: 1.55),
                ),
                Text(
                  '일지 전체보기 ›',
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.warningPink,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
