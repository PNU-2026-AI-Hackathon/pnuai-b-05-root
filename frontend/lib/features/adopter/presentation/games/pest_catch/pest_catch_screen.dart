import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../models/game_result.dart';
import '../models/game_type.dart';
import '../models/reward_grade.dart';
import '../shared/game_items.dart';
import '../shared/game_scaffold.dart';

/// 해충 잡기 게임(두더지잡기 형태). 3x3 격자에서 랜덤 칸에 해충이 잠깐 나타났다가
/// 사라지며, 사라지기 전에 탭하면 +10점. 총 30초, 시간이 지날수록 노출 시간이 짧아진다.
/// 50점 이상이면 아이템 1개를 랜덤 획득한다. 점수는 100점을 넘지 않도록 클램프된다.
class PestCatchScreen extends StatefulWidget {
  const PestCatchScreen({super.key});

  @override
  State<PestCatchScreen> createState() => _PestCatchScreenState();
}

class _PestCatchScreenState extends State<PestCatchScreen> {
  static const _cellCount = 9; // 3x3
  static const _gameSeconds = 30;
  static const _clearScore = 50;
  static const _pointsPerHit = 10;
  static const _spawnIntervalMs = 900; // 스폰 간격
  static const _initialExposureMs = 700; // 초기 노출 시간
  static const _maxConcurrent = 2; // 동시에 노출되는 최대 칸 수

  // 흙 구멍 느낌의 셀 배경색.
  static const _cellColor = Color(0xFFEADFD2);

  final _random = Random();

  int _score = 0;
  int _remainingSeconds = _gameSeconds;
  int _exposureMs = _initialExposureMs;

  /// 현재 해충이 노출된 칸 인덱스.
  final Set<int> _activeCells = {};

  Timer? _spawnTimer;
  Timer? _countdownTimer;

  /// 칸별 자동 퇴장 타이머(노출 시간 경과 시 해당 칸을 비운다).
  final Map<int, Timer> _hideTimers = {};

  @override
  void initState() {
    super.initState();
    _spawnTimer = Timer.periodic(
      const Duration(milliseconds: _spawnIntervalMs),
      _onSpawnTick,
    );
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      _onCountdownTick,
    );
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }

  /// 진행 중인 모든 타이머(스폰/카운트다운/칸별 퇴장)를 정리한다.
  void _cancelAllTimers() {
    _spawnTimer?.cancel();
    _countdownTimer?.cancel();
    for (final timer in _hideTimers.values) {
      timer.cancel();
    }
    _hideTimers.clear();
  }

  void _onSpawnTick(Timer _) {
    if (!mounted) return;
    if (_activeCells.length >= _maxConcurrent) return;
    // 비어 있는 칸 중 하나를 랜덤으로 고른다.
    final empty = [
      for (var i = 0; i < _cellCount; i++)
        if (!_activeCells.contains(i)) i,
    ];
    if (empty.isEmpty) return;
    final cell = empty[_random.nextInt(empty.length)];
    setState(() => _activeCells.add(cell));
    // 노출 시간이 지나면 자동으로 사라진다.
    _hideTimers[cell] = Timer(Duration(milliseconds: _exposureMs), () {
      if (!mounted) return;
      setState(() => _activeCells.remove(cell));
      _hideTimers.remove(cell);
    });
  }

  void _onCountdownTick(Timer _) {
    if (!mounted) return;
    setState(() {
      _remainingSeconds--;
      // 시간이 지날수록 노출 시간을 단축해 난이도를 올린다(10초 단위).
      if (_remainingSeconds == 20) {
        _exposureMs = 550;
      } else if (_remainingSeconds == 10) {
        _exposureMs = 400;
      }
    });
    if (_remainingSeconds <= 0) _finish();
  }

  void _onCellTap(int index) {
    // 해충이 없는 칸을 탭하면 무시(감점 없음).
    if (!_activeCells.contains(index)) return;
    // 성공: 해당 칸의 퇴장 타이머를 취소하고 점수를 올린다.
    _hideTimers.remove(index)?.cancel();
    setState(() {
      // 30초 동안 계속 잡으면 무제한 누적되므로 100점으로 클램프한다.
      _score = (_score + _pointsPerHit).clamp(0, 100);
      _activeCells.remove(index);
    });
  }

  Future<void> _finish() async {
    _cancelAllTimers();
    setState(() => _activeCells.clear());
    final cleared = _score >= _clearScore;
    final grade = computeRewardGrade(_score);
    final result = GameResult(
      score: _score,
      cleared: cleared,
      itemsEarned: pickRewardItems(GameType.pestCatch, grade, _random),
      grade: grade,
    );
    if (!mounted) return;
    await GameScaffold.showResultDialog(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '해충 잡기',
      score: _score,
      // 세로 오버플로를 피하려 스크롤로 감싸고, GridView는 AspectRatio로 높이를 확정한다
      // (unbounded 높이 컨텍스트에 GridView가 직접 놓이지 않게 함).
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          children: [
            Text(
              '⏱ 남은 시간 $_remainingSeconds초',
              style: AppTextStyles.title(
                fontSize: 20,
                color: _remainingSeconds <= 10
                    ? AppColors.errorRed
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '해충을 사라지기 전에 잡으세요! 🐛',
              style: AppTextStyles.guide(
                fontSize: 14,
                color: AppColors.badgeGreenText,
              ),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < _cellCount; i++) _PestCell(
                    key: ValueKey('pest_cell_$i'),
                    active: _activeCells.contains(i),
                    color: _cellColor,
                    onTap: () => _onCellTap(i),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '30초 안에 50점 이상이면 아이템을 획득해요 🎁',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 격자의 한 칸. 해충 등장/퇴장을 AnimatedScale + AnimatedOpacity로 부드럽게 전환한다.
class _PestCell extends StatelessWidget {
  const _PestCell({
    super.key,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline, width: 1.5),
        ),
        child: Center(
          child: AnimatedScale(
            scale: active ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: active ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: const Text('🐛', style: TextStyle(fontSize: 36)),
            ),
          ),
        ),
      ),
    );
  }
}
