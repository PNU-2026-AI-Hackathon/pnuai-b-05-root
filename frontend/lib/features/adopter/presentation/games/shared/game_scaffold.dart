import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/pigfig_button.dart';
import '../models/game_result.dart';
import '../models/reward_grade.dart';

/// 게임 화면 공통 셸. 각 게임 화면(무화과 퀴즈, 해충 잡기 등)이 자신의 게임 본문을
/// 이 위젯으로 감싸 상단 헤더(제목 + 점수 + 닫기)를 공유한다.
///
/// 게임 종료 결과 다이얼로그도 이 클래스의 [showResultDialog]로 통일해 재사용한다.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.score,
    required this.child,
  });

  final String title;
  final int score;
  final Widget child;

  /// 게임 종료 결과 다이얼로그를 띄운다. "확인"을 누르면 다이얼로그를 닫고
  /// `Navigator.pop(context, result)`로 게임 화면 자체를 종료해 결과를 돌려준다.
  ///
  /// [context]는 게임 화면(다이얼로그 라우트 아래)의 컨텍스트여야 한다.
  static Future<void> showResultDialog(
    BuildContext context,
    GameResult result,
  ) {
    final items = result.itemsEarned;
    final grade = result.grade;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.cleared ? '🎉 성공!' : '아쉬워요',
                style: AppTextStyles.display(fontSize: 26),
              ),
              // 등급 배지를 점수보다 먼저 보여줘 "아이템을 왜 여러 개 받았는지"가
              // 개수를 보기 전에 등급으로 먼저 설명되도록 한다.
              if (grade != null) ...[
                const SizedBox(height: 10),
                _GradeBadge(grade: grade),
              ],
              const SizedBox(height: 12),
              Text(
                '${result.score}점',
                style: AppTextStyles.title(
                  fontSize: 34,
                  color: AppColors.pink500,
                ),
              ),
              const SizedBox(height: 14),
              if (items.isNotEmpty)
                Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _EarnedItemBox(
                        emoji: items[i].emoji,
                        name: items[i].name,
                        description: items[i].description,
                      ),
                    ],
                  ],
                )
              else if (grade == RewardGrade.gold)
                // TODO(game-reward-grade-choice): 골드는 다음 브랜치에서 직접 선택
                // UI로 아이템을 채운다. 그 전까지는 안내 문구만 보여준다.
                Text(
                  '골드 등급이에요! 곧 아이템을 직접 골라보실 수 있어요 🎁',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.guide(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ).copyWith(height: 1.5),
                )
              else
                Text(
                  '다음엔 50점 이상 도전해서\n아이템을 획득해 보세요!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.guide(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ).copyWith(height: 1.5),
                ),
              const SizedBox(height: 22),
              PigFigButton.primary(
                label: '확인',
                onPressed: () {
                  // 다이얼로그를 먼저 닫고, 게임 화면을 결과와 함께 종료한다.
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(result);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beigeBg,
      body: SafeArea(
        child: Column(
          children: [
            _GameHeader(title: title, score: score),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// 게임 상단 헤더: 제목 + 현재 점수 + 닫기 버튼.
class _GameHeader extends StatelessWidget {
  const _GameHeader({required this.title, required this.score});

  final String title;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            // 게임 도중 닫으면 결과 없이(null) 종료한다.
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title(fontSize: 17),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.badgeGreenBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '점수 $score',
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.badgeGreenText,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 결과 다이얼로그 상단에서 획득 등급을 보여주는 배지.
class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});

  final RewardGrade grade;

  static const _labels = {
    RewardGrade.bronze: '브론즈 🥉',
    RewardGrade.silver: '실버 🥈',
    RewardGrade.gold: '골드 🥇',
  };

  static const _backgrounds = {
    RewardGrade.bronze: Color(0xFFF1E1D3),
    RewardGrade.silver: Color(0xFFE7E7EA),
    RewardGrade.gold: Color(0xFFFCEBC7),
  };

  static const _textColors = {
    RewardGrade.bronze: AppColors.brown600,
    RewardGrade.silver: Color(0xFF6B6B73),
    RewardGrade.gold: Color(0xFFB8791A),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _backgrounds[grade],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _labels[grade]!,
        style: AppTextStyles.body(
          fontSize: 13,
          color: _textColors[grade]!,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 결과 다이얼로그 안에서 획득 아이템을 보여주는 박스.
class _EarnedItemBox extends StatelessWidget {
  const _EarnedItemBox({
    required this.emoji,
    required this.name,
    required this.description,
  });

  final String emoji;
  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.badgeGreenBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '아이템 획득!',
            style: AppTextStyles.caption(
              fontSize: 12,
              color: AppColors.badgeGreenText,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTextStyles.title(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(
              fontSize: 12,
              color: AppColors.textMuted,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
