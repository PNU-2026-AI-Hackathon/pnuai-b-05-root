import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gauge_bar.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';
import '../../../../shared/widgets/step_indicator.dart';

/// 1i — 케어: 햇빛. 슬라이더로 보광등 밝기를 조절한다.
class SunlightCareScreen extends StatefulWidget {
  const SunlightCareScreen({super.key});

  @override
  State<SunlightCareScreen> createState() => _SunlightCareScreenState();
}

class _SunlightCareScreenState extends State<SunlightCareScreen> {
  double _brightness = 0.7;

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
              Text(
                '햇빛을 쬐어주세요!',
                style: AppTextStyles.display(
                  fontSize: 32,
                  color: const Color(0xFFF7A0AE),
                ),
              ),
              const SizedBox(height: 10),
              Text('슬라이더를 밀어 보광등을 켜보세요', style: AppTextStyles.guide()),
              Expanded(
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF3DC),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange400.withValues(
                            alpha: 0.25 * _brightness + 0.05,
                          ),
                          blurRadius: 60 * _brightness + 10,
                          spreadRadius: 20 * _brightness,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('☀️', style: TextStyle(fontSize: 64)),
                  ),
                ),
              ),
              Slider(
                value: _brightness,
                onChanged: (v) => setState(() => _brightness = v),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF8EC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    GaugeBar(
                      value: _brightness,
                      fillColor: AppColors.orange400,
                      trackColor: const Color(0xFFF3EAD3),
                      label: '보광등 밝기',
                      trailing: '${(_brightness * 100).round()}%',
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🌥️ 흐림', style: AppTextStyles.caption()),
                        Text('☀️ 쨍쨍', style: AppTextStyles.caption()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '적정 조도 2000~3000 lux를 맞춰주세요 ☀️',
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
