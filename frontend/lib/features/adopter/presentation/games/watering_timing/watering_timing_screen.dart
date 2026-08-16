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

/// 물주기 타이밍 게임. 바(bar)를 왕복하는 물방울 인디케이터를 타겟 존 정중앙에서
/// 탭할수록 높은 점수를 얻는다. 총 5라운드, 라운드가 오를수록 속도가 빨라지며,
/// 5라운드 평균 50점 이상이면 아이템 1개를 랜덤 획득한다.
class WateringTimingScreen extends StatefulWidget {
  const WateringTimingScreen({super.key});

  @override
  State<WateringTimingScreen> createState() => _WateringTimingScreenState();
}

class _WateringTimingScreenState extends State<WateringTimingScreen>
    with SingleTickerProviderStateMixin {
  static const _totalRounds = 5;
  static const _clearScore = 50; // 평균 이 점수 이상이면 cleared
  static const _baseDurationMs = 1100; // 1라운드 왕복 주기
  static const _speedStepMs = 130; // 라운드마다 이만큼씩 주기 단축(속도 상승)
  static const _targetHalfWidth = 0.1; // 타겟 존 반폭(존 = center ± 0.1)
  static const _minCenter = 0.2;
  static const _maxCenter = 0.8;

  final _random = Random();

  late final AnimationController _controller;
  int _round = 0;
  int _totalScore = 0;
  double _targetCenter = 0.5;
  bool _tapped = false; // 이번 라운드에서 이미 탭했는지
  String? _feedback; // 라운드 즉시 피드백 문구
  Timer? _nextRoundTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _baseDurationMs),
    );
    _startRound();
  }

  @override
  void dispose() {
    _nextRoundTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 라운드 시작: 타겟 존을 랜덤 배치하고, 라운드에 맞는 속도로 왕복을 재시작한다.
  void _startRound() {
    _targetCenter =
        _minCenter + _random.nextDouble() * (_maxCenter - _minCenter);
    final durationMs = _baseDurationMs - _round * _speedStepMs;
    _controller.duration = Duration(milliseconds: durationMs);
    _controller
      ..reset()
      ..repeat(reverse: true);
  }

  /// 탭 시점의 인디케이터 위치(0.0~1.0)와 타겟 존 중앙의 거리로 점수를 매긴다.
  int _scoreFor(double value) {
    final dist = (value - _targetCenter).abs();
    if (dist > _targetHalfWidth) return 0; // 존 밖이면 0점
    return (100 * (1 - dist / _targetHalfWidth)).round(); // 정중앙=100
  }

  String _feedbackFor(double value, int score) {
    if (score == 0) return '놓쳤어요 😢';
    if (score >= 90) return '완벽해요! 🎯';
    return value < _targetCenter ? '조금 빠르셨어요 💨' : '조금 느리셨어요 🐢';
  }

  void _onTap() {
    if (_tapped) return;
    _controller.stop();
    final value = _controller.value;
    final score = _scoreFor(value);
    setState(() {
      _tapped = true;
      _totalScore += score;
      _feedback = _feedbackFor(value, score);
    });
    // 피드백을 잠깐 보여준 뒤 다음 라운드(또는 종료)로 자동 전환한다.
    _nextRoundTimer?.cancel();
    _nextRoundTimer = Timer(const Duration(milliseconds: 1200), _advanceRound);
  }

  void _advanceRound() {
    if (!mounted) return;
    if (_round < _totalRounds - 1) {
      setState(() {
        _round++;
        _tapped = false;
        _feedback = null;
      });
      _startRound();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    _controller.stop();
    final average = (_totalScore / _totalRounds).round();
    final cleared = average >= _clearScore;
    final GameItem? earned =
        cleared ? rewardItems[_random.nextInt(rewardItems.length)] : null;
    final result = GameResult(
      score: average,
      cleared: cleared,
      itemEarned: earned,
      grade: computeRewardGrade(average),
    );
    if (!mounted) return;
    await GameScaffold.showResultDialog(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '물주기 타이밍',
      score: _totalScore,
      // GameScaffold가 Expanded로 감싸 높이가 유한하므로 Column을 그대로 써도 안전하다.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            children: [
              Text(
                '${_round + 1} / $_totalRounds 라운드',
                style: AppTextStyles.guide(
                  fontSize: 14,
                  color: AppColors.badgeGreenText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '타겟 존 정중앙에서 화면을 탭하세요!',
                textAlign: TextAlign.center,
                style: AppTextStyles.title(fontSize: 18),
              ),
              const Spacer(),
              // 왕복 바 + 타겟 존 + 물방울 인디케이터.
              SizedBox(
                height: 70,
                child: _TimingBar(
                  controller: _controller,
                  targetCenter: _targetCenter,
                  halfWidth: _targetHalfWidth,
                ),
              ),
              const SizedBox(height: 28),
              // 라운드 즉시 피드백 자리(높이 고정으로 레이아웃 흔들림 방지).
              SizedBox(
                height: 34,
                child: Center(
                  child: Text(
                    _feedback ?? '',
                    style: AppTextStyles.title(
                      fontSize: 20,
                      color: AppColors.pink500,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '5라운드 평균 50점 이상이면 아이템을 획득해요 🎁',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 왕복 바: 트랙 + 타겟 존 + 물방울 인디케이터.
class _TimingBar extends StatelessWidget {
  const _TimingBar({
    required this.controller,
    required this.targetCenter,
    required this.halfWidth,
  });

  final AnimationController controller;
  final double targetCenter;
  final double halfWidth;

  static const _indicatorSize = 40.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 인디케이터가 좌우 끝에서 삐져나오지 않도록 이동 가능 폭을 계산한다.
        final usable = constraints.maxWidth - _indicatorSize;
        final zoneLeft = (targetCenter - halfWidth) * usable;
        final zoneWidth = 2 * halfWidth * usable + _indicatorSize;
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // 트랙 배경 선 (세로 중앙, 가로 꽉 채움 — left+right로 폭을 명시)
            Positioned(
              left: 0,
              right: 0,
              top: 30,
              height: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            // 타겟 존
            Positioned(
              left: zoneLeft,
              width: zoneWidth,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.green500.withValues(alpha: 0.28),
                  border: Border.all(color: AppColors.green500, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // 물방울 인디케이터
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Positioned(
                left: controller.value * usable,
                child: const Text('💧', style: TextStyle(fontSize: 34)),
              ),
            ),
          ],
        );
      },
    );
  }
}
