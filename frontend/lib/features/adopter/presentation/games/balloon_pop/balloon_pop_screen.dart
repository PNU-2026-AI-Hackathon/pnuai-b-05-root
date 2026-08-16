import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../models/game_item.dart';
import '../models/game_result.dart';
import '../shared/game_items.dart';
import '../shared/game_scaffold.dart';

/// 화면에 떠 있는 돼지 풍선 하나의 상태.
class _Balloon {
  _Balloon({
    required this.id,
    required this.x,
    required this.spawnMs,
    required this.riseDurationMs,
  });

  final int id;
  final double x; // 가로 위치 비율(0.0~1.0)
  final int spawnMs; // 스폰 시각(게임 시작 후 경과 ms)
  final int riseDurationMs; // 바닥→상단까지 걸리는 시간(작을수록 빠름)
  int? poppedAtMs; // 터진 시각(경과 ms). null이면 아직 안 터짐

  bool get isPopped => poppedAtMs != null;
}

/// 돼지 풍선 터뜨리기 게임. 하단에서 솟아오르는 돼지 풍선을 상단에 닿기 전에 탭해
/// 터뜨리면 +10점, 놓치면 실패 카운트가 오른다. 실패 5회 또는 30초 경과 시 종료되며
/// 총점 50점 이상이면 아이템 1개를 랜덤 획득한다. 점수는 100점을 넘지 않도록 클램프된다.
///
/// 다중 풍선 애니메이션은 단일 [AnimationController]를 프레임 드라이버로 삼아
/// 매 프레임 "경과 시각 기준 각 풍선의 위치"를 계산하는 방식(방식 1)으로 구현했다.
/// 풍선마다 Timer를 두지 않아 정리가 단순하고 화면 밖 판정도 프레임 계산에서 일관되게 처리한다.
class BalloonPopScreen extends StatefulWidget {
  const BalloonPopScreen({super.key});

  @override
  State<BalloonPopScreen> createState() => _BalloonPopScreenState();
}

class _BalloonPopScreenState extends State<BalloonPopScreen>
    with SingleTickerProviderStateMixin {
  static const _gameSeconds = 30;
  static const _maxMissed = 5;
  static const _clearScore = 50;
  static const _pointsPerBalloon = 10;
  static const _maxConcurrent = 5; // 동시에 떠 있는(안 터진) 풍선 최대 수
  static const _balloonSlot = 72.0; // 풍선 배치 슬롯 크기(위치 계산용)
  static const _popDurationMs = 160; // 터지는 이펙트 지속 시간

  static const _skyColor = Color(0xFFEAF4FB);

  final _random = Random();

  late final AnimationController _controller;
  Duration _elapsed = Duration.zero;
  int _score = 0;
  int _missed = 0;
  int _nextBalloonId = 0;
  int _lastSpawnMs = 0;
  bool _finished = false;
  List<_Balloon> _balloons = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _gameSeconds),
    )
      ..addListener(_onFrame)
      ..addStatusListener((status) {
        // 30초가 다 차면 종료.
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _spawnIntervalMs(int seconds) {
    // 시간이 지날수록 스폰 간격을 좁혀 난이도를 올린다.
    if (seconds >= 20) return 650;
    if (seconds >= 10) return 900;
    return 1200;
  }

  int _riseDurationMs(int seconds) {
    // 시간이 지날수록 상승 속도를 높인다(도달 시간 단축).
    if (seconds >= 20) return 2400;
    if (seconds >= 10) return 3000;
    return 3800;
  }

  /// 매 프레임 호출: 화면 밖으로 나간 풍선 제거(+실패), 스폰, 상태 갱신.
  void _onFrame() {
    if (!mounted || _finished) return;
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final ms = elapsed.inMilliseconds;

    final survivors = <_Balloon>[];
    var missed = _missed;
    for (final b in _balloons) {
      if (b.isPopped) {
        // 터진 풍선은 이펙트 시간 동안만 유지 후 제거.
        if (ms - b.poppedAtMs! <= _popDurationMs) survivors.add(b);
        continue;
      }
      final progress = (ms - b.spawnMs) / b.riseDurationMs;
      if (progress > 1.0) {
        missed++; // 상단을 벗어나면 놓침
      } else {
        survivors.add(b);
      }
    }

    // 스폰: 간격이 지났고 동시 노출 수 여유가 있으면 새 풍선 추가.
    final activeCount = survivors.where((b) => !b.isPopped).length;
    if (ms - _lastSpawnMs >= _spawnIntervalMs(elapsed.inSeconds) &&
        activeCount < _maxConcurrent) {
      survivors.add(
        _Balloon(
          id: _nextBalloonId++,
          x: 0.05 + _random.nextDouble() * 0.8,
          spawnMs: ms,
          riseDurationMs: _riseDurationMs(elapsed.inSeconds),
        ),
      );
      _lastSpawnMs = ms;
    }

    setState(() {
      _elapsed = elapsed;
      _balloons = survivors;
      _missed = missed;
    });

    if (missed >= _maxMissed) _finish();
  }

  void _onBalloonTap(_Balloon balloon) {
    if (balloon.isPopped) return; // 이미 터진 풍선은 무시
    setState(() {
      // 동시 최대 5개 풍선을 계속 터뜨리면 무제한 누적되므로 100점으로 클램프한다.
      _score = (_score + _pointsPerBalloon).clamp(0, 100);
      balloon.poppedAtMs = _elapsed.inMilliseconds;
    });
  }

  Future<void> _finish() async {
    if (_finished) return; // 프레임/상태 리스너에서 중복 호출 방지
    _finished = true;
    _controller.stop();
    final cleared = _score >= _clearScore;
    final GameItem? earned =
        cleared ? rewardItems[_random.nextInt(rewardItems.length)] : null;
    final result =
        GameResult(score: _score, cleared: cleared, itemEarned: earned);
    if (!mounted) return;
    await GameScaffold.showResultDialog(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        (_gameSeconds - _elapsed.inSeconds).clamp(0, _gameSeconds);
    return GameScaffold(
      title: '돼지 풍선 터뜨리기',
      score: _score,
      // Column은 GameScaffold의 Expanded 안에 있어 높이가 유한하고, 게임 영역도
      // Expanded로 감싸 유한한 크기의 Stack 안에서 풍선을 배치한다(unbounded 회피).
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⏱ 남은 시간 $remaining초',
                  style: AppTextStyles.title(
                    fontSize: 18,
                    color: remaining <= 10
                        ? AppColors.errorRed
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '실패 $_missed/$_maxMissed',
                  style: AppTextStyles.title(
                    fontSize: 16,
                    color: AppColors.warningPink,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: _skyColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final b in _balloons)
                            _buildBalloon(b, width, height),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalloon(_Balloon balloon, double width, double height) {
    // 터진 풍선은 터진 위치에 멈춰서 팝 이펙트를 보여준다.
    final refMs =
        balloon.isPopped ? balloon.poppedAtMs! : _elapsed.inMilliseconds;
    final progress =
        ((refMs - balloon.spawnMs) / balloon.riseDurationMs).clamp(0.0, 1.0).toDouble();
    final left = balloon.x * (width - _balloonSlot);
    final bottom = progress * (height - _balloonSlot);

    return Positioned(
      key: ValueKey('balloon_${balloon.id}'),
      left: left,
      bottom: bottom,
      width: _balloonSlot,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onBalloonTap(balloon),
        child: AnimatedScale(
          scale: balloon.isPopped ? 1.5 : 1.0,
          duration: const Duration(milliseconds: _popDurationMs),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: balloon.isPopped ? 0.0 : 1.0,
            duration: const Duration(milliseconds: _popDurationMs),
            child: const _PigBalloon(),
          ),
        ),
      ),
    );
  }
}

/// 돼지 풍선 비주얼: 분홍 원 + 🐷 + 짧은 끈.
class _PigBalloon extends StatelessWidget {
  const _PigBalloon();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.pink500,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Text('🐷', style: TextStyle(fontSize: 28)),
        ),
        Container(width: 2, height: 14, color: AppColors.brown600),
      ],
    );
  }
}
