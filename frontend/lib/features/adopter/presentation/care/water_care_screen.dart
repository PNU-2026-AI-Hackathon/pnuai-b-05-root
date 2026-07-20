import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gauge_bar.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';
import '../../../../shared/widgets/step_indicator.dart';

/// 1g — 케어: 물주기. 물방울을 꾹 누르는 동안 수분 게이지가 차오른다.
class WaterCareScreen extends StatefulWidget {
  const WaterCareScreen({super.key});

  @override
  State<WaterCareScreen> createState() => _WaterCareScreenState();
}

class _WaterCareScreenState extends State<WaterCareScreen> with SingleTickerProviderStateMixin {
  double _moisture = 0.6;
  Timer? _holdTimer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startFilling() {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      setState(() => _moisture = (_moisture + 0.05).clamp(0, 1));
      if (_moisture >= 1) _holdTimer?.cancel();
    });
  }

  void _stopFilling() => _holdTimer?.cancel();

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
              const StepIndicator(current: 1, total: 1),
              const SizedBox(height: 22),
              Text('물을 주세요!', style: AppTextStyles.display(fontSize: 32, color: const Color(0xFFF7A0AE))),
              const SizedBox(height: 10),
              Text('물방울을 꾹 눌러 화분에 부어보세요', style: AppTextStyles.guide()),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onLongPressStart: (_) => _startFilling(),
                    onLongPressEnd: (_) => _stopFilling(),
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
                                  decoration: const BoxDecoration(color: AppColors.pink100, shape: BoxShape.circle),
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
                        decoration: const BoxDecoration(color: Color(0xFFFDEFF2), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Text('💧', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(color: const Color(0xFFF3F8FD), borderRadius: BorderRadius.circular(18)),
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
              Text('누르는 동안 재배자에게 물주기 요청이 기록돼요 💧', style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
