import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../models/game_item.dart';
import '../models/game_result.dart';
import '../models/reward_grade.dart';
import '../shared/game_items.dart';
import '../shared/game_scaffold.dart';
import 'fig_quiz_questions.dart';

/// 무화과 퀴즈 게임. 10문항(4지선다 + O/X 혼합)을 풀고 정답 개수로 점수를 낸다.
/// 문항당 10점, 50점 이상이면 아이템 1개를 랜덤 획득한다.
class FigQuizScreen extends StatefulWidget {
  const FigQuizScreen({super.key});

  @override
  State<FigQuizScreen> createState() => _FigQuizScreenState();
}

class _FigQuizScreenState extends State<FigQuizScreen> {
  /// 목표 점수(이 이상이면 cleared + 아이템 획득).
  static const _clearScore = 50;

  int _index = 0;
  int _correctCount = 0;
  int? _selected;
  bool _answered = false;
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _onOptionTap(int index) {
    if (_answered) return;
    final question = figQuizQuestions[_index];
    setState(() {
      _selected = index;
      _answered = true;
      if (index == question.correctIndex) _correctCount++;
    });
    // 정답/오답을 1.5초 보여준 뒤 자동으로 다음 문항(또는 종료)으로 넘어간다.
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1500), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_index < figQuizQuestions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final score = _correctCount * 10;
    final cleared = score >= _clearScore;
    // 목표 달성 시에만 후보 중 하나를 랜덤으로 지급한다.
    final GameItem? earned =
        cleared ? rewardItems[Random().nextInt(rewardItems.length)] : null;
    final result = GameResult(
      score: score,
      cleared: cleared,
      itemEarned: earned,
      grade: computeRewardGrade(score),
    );
    if (!mounted) return;
    await GameScaffold.showResultDialog(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final question = figQuizQuestions[_index];
    return GameScaffold(
      title: '무화과 퀴즈',
      score: _correctCount * 10,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_index + 1} / ${figQuizQuestions.length}',
              textAlign: TextAlign.center,
              style: AppTextStyles.guide(
                fontSize: 14,
                color: AppColors.badgeGreenText,
              ),
            ),
            const SizedBox(height: 14),
            _QuestionCard(text: question.question),
            const SizedBox(height: 20),
            for (var i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OptionTile(
                  label: question.options[i],
                  state: _stateFor(i, question.correctIndex),
                  onTap: () => _onOptionTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _OptionState _stateFor(int index, int correctIndex) {
    if (!_answered) return _OptionState.idle;
    if (index == correctIndex) return _OptionState.correct;
    if (index == _selected) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

/// 문항 상태에 따른 보기 버튼 표시 상태.
enum _OptionState { idle, correct, wrong, dimmed }

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.title(fontSize: 17).copyWith(height: 1.5),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border, textColor) = switch (state) {
      _OptionState.idle => (Colors.white, AppColors.outline, AppColors.textPrimary),
      _OptionState.correct => (AppColors.badgeGreenBg, AppColors.green500, AppColors.green800),
      _OptionState.wrong => (AppColors.pink100, AppColors.errorRed, AppColors.errorRed),
      _OptionState.dimmed => (Colors.white, AppColors.outline, AppColors.textMuted),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 15,
                  color: textColor,
                ).copyWith(fontWeight: FontWeight.w700, height: 1.4),
              ),
            ),
            if (state == _OptionState.correct)
              const Icon(Icons.check_circle, color: AppColors.green500, size: 22),
            if (state == _OptionState.wrong)
              const Icon(Icons.cancel, color: AppColors.errorRed, size: 22),
          ],
        ),
      ),
    );
  }
}
