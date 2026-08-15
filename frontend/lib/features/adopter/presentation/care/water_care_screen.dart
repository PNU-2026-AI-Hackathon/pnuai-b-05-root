import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/storage/care_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gauge_bar.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';

/// 1g — 케어: 물주기. 물방울을 꾹 누르는 동안 수분 게이지가 차오른다.
/// 오늘 이미 완료했으면(로컬 저장, [CareStorage]) 재진입 시 잠긴 완료 상태로 보여준다.
class WaterCareScreen extends StatefulWidget {
  const WaterCareScreen({super.key});

  @override
  State<WaterCareScreen> createState() => _WaterCareScreenState();
}

class _WaterCareScreenState extends State<WaterCareScreen>
    with SingleTickerProviderStateMixin {
  final _careStorage = CareStorage();

  double _moisture = 0.6;
  bool _completed = false;
  bool _pressing = false;
  Timer? _holdTimer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _loadCareStatus();
  }

  Future<void> _loadCareStatus() async {
    final last = await _careStorage.getLastCompleted(CareType.water);
    if (!mounted || last == null || !_isSameDay(last, DateTime.now())) return;
    setState(() {
      _completed = true;
      _moisture = 1;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startFilling() {
    if (_completed) return;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      setState(() => _moisture = (_moisture + 0.05).clamp(0, 1));
      if (_moisture >= 1) {
        _holdTimer?.cancel();
        _markCompleted();
      }
    });
  }

  void _stopFilling() => _holdTimer?.cancel();

  Future<void> _markCompleted() async {
    if (_completed) return;
    setState(() {
      _completed = true;
      _pressing = false;
    });
    await _careStorage.markCompleted(CareType.water);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
          child: Column(
            children: [
              Text(
                _completed ? '오늘 물주기 완료! 💧' : '물을 주세요!',
                style: AppTextStyles.display(
                  fontSize: 32,
                  color: AppColors.pink500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _completed ? '내일 다시 만나요' : '물방울을 꾹 눌러 화분에 부어보세요',
                style: AppTextStyles.guide(),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onLongPressStart: _completed
                          ? null
                          : (_) {
                              setState(() => _pressing = true);
                              _startFilling();
                            },
                      onLongPressEnd: _completed
                          ? null
                          : (_) {
                              setState(() => _pressing = false);
                              _stopFilling();
                            },
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final t = _pulseController.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: (0.5 * (1 - t)).clamp(0, 1),
                                child: Transform.scale(
                                  scale: 1 + 0.35 * t,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: const BoxDecoration(
                                      color: AppColors.pink100,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              child!,
                            ],
                          );
                        },
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFDEFF2),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFBFE3FA), AppColors.blue400],
                            ).createShader(bounds),
                            child: const Icon(
                              Icons.water_drop,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 64,
                      child: _pressing
                          ? _fallingDropsTrail()
                          : const SizedBox.shrink(),
                    ),
                    _potIllustration(),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8FD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: GaugeBar(
                  value: _moisture,
                  fillColor: AppColors.blue400,
                  trackColor: const Color(0xFFE1EBF4),
                  height: 10,
                  label: '수분 게이지',
                  trailing: '${(_moisture * 100).round()}%',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _completed ? '오늘의 물주기가 기록됐어요 💧' : '오늘의 물주기가 이 기기에 기록돼요 💧',
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

  /// 누르는 동안 "꾹—" 안내와 함께 물방울 3개가 화분 쪽으로 떨어지는 트레일.
  Widget _fallingDropsTrail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '꾹—',
          style: AppTextStyles.body(
            fontSize: 13,
            color: AppColors.textCaption,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 20,
          height: 40,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.topCenter,
                children: List.generate(3, (i) {
                  final phase = (_pulseController.value + i * 0.33) % 1;
                  return Positioned(
                    top: phase * 34,
                    child: Opacity(
                      opacity: (1 - phase).clamp(0.0, 1.0),
                      child: Icon(
                        Icons.water_drop,
                        size: 15 - phase * 6,
                        color: AppColors.blue400,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 줄기+새싹이 달린 화분 일러스트. 이미지 파일 대신 도형 조합으로 그린다
  /// (다른 화면 일러스트와 동일한 컨벤션, 예: FigTreeIllustration).
  Widget _potIllustration() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-6, 0),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.green800,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(6, 0),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3E6B33),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(width: 4, height: 22, color: AppColors.brown600),
        Container(
          width: 90,
          height: 8,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF7A4E30),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Container(
          width: 100,
          height: 46,
          decoration: const BoxDecoration(
            color: AppColors.brown600,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
          ),
        ),
      ],
    );
  }
}
