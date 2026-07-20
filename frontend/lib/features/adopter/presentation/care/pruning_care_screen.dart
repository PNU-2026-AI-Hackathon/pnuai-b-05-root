import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';
import '../../../../shared/widgets/step_indicator.dart';

/// 1j — 케어: 가지치기. 처음 한 번만 하는 인터랙션: 꾹 눌러서 완료한다.
class PruningCareScreen extends StatefulWidget {
  const PruningCareScreen({super.key});

  @override
  State<PruningCareScreen> createState() => _PruningCareScreenState();
}

class _PruningCareScreenState extends State<PruningCareScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _completed = true);
        }
      });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
          child: Column(
            children: [
              const StepIndicator(current: 1, total: 1),
              const SizedBox(height: 22),
              Text(
                _completed ? '첫 가지치기 완료! 🌿' : '첫 가지치기를 해주세요!',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(fontSize: 32, color: const Color(0xFFF7A0AE)),
              ),
              const SizedBox(height: 10),
              Text(
                _completed ? '가지가 튼튼하게 정리됐어요' : '꾹 눌러서 가지를 잘라보세요',
                style: AppTextStyles.guide(),
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onLongPressStart: _completed ? null : (_) => _progressController.forward(from: _progressController.value),
                    onLongPressEnd: _completed
                        ? null
                        : (_) {
                            if (!_completed) _progressController.reverse();
                          },
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 14,
                            height: 130,
                            decoration: BoxDecoration(color: AppColors.brown600, borderRadius: BorderRadius.circular(7)),
                          ),
                          const Positioned(left: 8, top: 20, child: Text('🌱', style: TextStyle(fontSize: 18))),
                          const Positioned(right: 8, bottom: 20, child: Text('🌱', style: TextStyle(fontSize: 18))),
                          if (!_completed)
                            AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, _) => SizedBox(
                                width: 100,
                                height: 100,
                                child: CircularProgressIndicator(
                                  value: _progressController.value,
                                  strokeWidth: 5,
                                  backgroundColor: AppColors.pink100.withValues(alpha: 0.4),
                                  valueColor: const AlwaysStoppedAnimation(AppColors.pink500),
                                ),
                              ),
                            ),
                          if (_completed)
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.check, color: Colors.white, size: 32),
                            )
                          else
                            const Positioned(top: 24, right: -30, child: Text('✂️', style: TextStyle(fontSize: 30))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                _completed ? '다음 가지치기는 다 자란 뒤에 알려드릴게요 🌳' : '처음 한 번만 하는 특별한 인터랙션이에요 🌿',
                style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
