import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/pigfig_button.dart';
import '../models/game_item.dart';
import '../models/game_result.dart';
import '../models/reward_grade.dart';
import 'game_items.dart';

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
  /// 골드 등급(클리어 성공 시에만 가능)은 즉시 아이템을 보여주는 대신
  /// [_GoldRewardDialog]로 분기해 사용자가 직접 아이템을 고르게 한다 — 그 경우
  /// [result]의 `itemsEarned`는 각 게임 화면이 항상 빈 리스트로 넘기므로(위
  /// `game_items.dart`의 `pickRewardItems` 문서 참고), 여기서 사용자가 고른
  /// 아이템으로 채운 새 [GameResult]를 만들어 게임 화면에 돌려준다.
  ///
  /// [context]는 게임 화면(다이얼로그 라우트 아래)의 컨텍스트여야 한다.
  static Future<void> showResultDialog(
    BuildContext context,
    GameResult result,
  ) {
    final grade = result.grade;
    if (result.cleared && grade == RewardGrade.gold) {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GoldRewardDialog(gameContext: context, result: result),
      );
    }

    final items = result.itemsEarned;
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

/// 골드 등급 결과에서 사용자가 직접 아이템을 고르는 다이얼로그.
///
/// [gameContext]는 [GameScaffold.showResultDialog]가 받은 게임 화면(다이얼로그
/// 라우트 아래)의 컨텍스트다 — "확인"이 활성화되면 이 컨텍스트의 Navigator로
/// 게임 화면을 (사용자가 고른 아이템이 채워진) 새 [GameResult]와 함께 종료한다.
/// 선택 현황(아이템별 선택 횟수)은 다이얼로그 자체의 상태라 [StatefulWidget]으로
/// 분리했다 — [showResultDialog]의 나머지 부분은 상태가 없는 `builder` 하나로
/// 충분하지만, 이 갈래만 탭할 때마다 다시 그려야 하는 로컬 상태가 필요하다.
class _GoldRewardDialog extends StatefulWidget {
  const _GoldRewardDialog({required this.gameContext, required this.result});

  final BuildContext gameContext;
  final GameResult result;

  @override
  State<_GoldRewardDialog> createState() => _GoldRewardDialogState();
}

class _GoldRewardDialogState extends State<_GoldRewardDialog> {
  late final int _targetCount = rewardCountFor(
    widget.result.gameType,
    RewardGrade.gold,
  );

  /// 아이템 id → 선택 횟수. 같은 아이템을 여러 번 고를 수 있어(중복 허용)
  /// 리스트가 아니라 개수로 센다.
  final Map<String, int> _selectedCounts = {};

  int get _totalSelected =>
      _selectedCounts.values.fold(0, (sum, count) => sum + count);

  void _selectItem(GameItem item) {
    if (_totalSelected >= _targetCount) return;
    setState(() {
      _selectedCounts.update(
        item.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    });
  }

  void _confirm() {
    if (_totalSelected < _targetCount) return;
    final selectedItems = <GameItem>[
      for (final item in rewardItems)
        for (var i = 0; i < (_selectedCounts[item.id] ?? 0); i++) item,
    ];
    final finalResult = GameResult(
      score: widget.result.score,
      cleared: widget.result.cleared,
      gameType: widget.result.gameType,
      itemsEarned: selectedItems,
      grade: widget.result.grade,
    );
    // 다이얼로그를 먼저 닫고, 게임 화면을 확정된 결과와 함께 종료한다.
    Navigator.of(context).pop();
    Navigator.of(widget.gameContext).pop(finalResult);
  }

  @override
  Widget build(BuildContext context) {
    final complete = _totalSelected >= _targetCount;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      // 아이템 3종 카드 + 안내문까지 합치면 작은 화면에서 다이얼로그 기본 높이를
      // 넘길 수 있어(다른 결과 다이얼로그보다 내용이 많음), 넘치는 대신 스크롤되게 한다.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎉 성공!', style: AppTextStyles.display(fontSize: 26)),
          const SizedBox(height: 10),
          const _GradeBadge(grade: RewardGrade.gold),
          const SizedBox(height: 12),
          Text(
            '${widget.result.score}점',
            style: AppTextStyles.title(fontSize: 34, color: AppColors.pink500),
          ),
          const SizedBox(height: 16),
          Text(
            '원하는 아이템을 직접 골라보세요',
            style: AppTextStyles.body(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '$_totalSelected/$_targetCount 선택됨',
            style: AppTextStyles.title(fontSize: 16, color: AppColors.pink500),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final item in rewardItems)
                _SelectableItemCard(
                  item: item,
                  count: _selectedCounts[item.id] ?? 0,
                  onTap: complete ? null : () => _selectItem(item),
                ),
            ],
          ),
          const SizedBox(height: 22),
          PigFigButton.primary(
            label: '확인',
            onPressed: complete ? _confirm : null,
          ),
        ],
      ),
    );
  }
}

/// 골드 선택 다이얼로그의 아이템 카드 하나. 탭할 때마다 [count]가 1씩 늘고,
/// 우상단의 작은 배지("×N")로 지금까지 이 아이템을 몇 번 골랐는지 보여준다.
/// 목표 개수를 다 채우면([onTap]이 null로 넘어옴) 탭이 막힌다.
class _SelectableItemCard extends StatelessWidget {
  const _SelectableItemCard({
    required this.item,
    required this.count,
    required this.onTap,
  });

  final GameItem item;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.badgeGreenBg : AppColors.beigeBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.green500 : AppColors.outline,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(
                    fontSize: 11,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pink500,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '×$count',
                  style: AppTextStyles.caption(
                    fontSize: 11,
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
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
