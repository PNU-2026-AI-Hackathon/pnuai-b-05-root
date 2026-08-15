import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/care_pot_illustration.dart';
import '../../../../shared/widgets/gauge_bar.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';

/// 1i — 케어: 햇빛. 슬라이더로 보광등 밝기를 조절한다.
/// 완료 개념이 없는 자유 다이얼이라 [CareStorage]를 쓰지 않는다(물주기/영양제와 다른 점).
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
              Text(
                '햇빛을 쬐어주세요!',
                style: AppTextStyles.display(
                  fontSize: 32,
                  color: AppColors.pink500,
                ),
              ),
              const SizedBox(height: 10),
              Text('슬라이더를 밀어 보광등을 켜보세요', style: AppTextStyles.guide()),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _sunWithGlow(),
                    const SizedBox(height: 26),
                    const CarePotIllustration(showPot: false),
                  ],
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

  /// 해 아이콘 + 밝기에 비례해 커지는 방사형 글로우(반투명 원 3겹).
  Widget _sunWithGlow() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _glowLayer(220 + 140 * _brightness, alpha: 0.02 + 0.10 * _brightness),
          _glowLayer(160 + 90 * _brightness, alpha: 0.03 + 0.16 * _brightness),
          _glowLayer(110 + 50 * _brightness, alpha: 0.05 + 0.22 * _brightness),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0xFFFDF3DC),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD873), AppColors.orange400],
              ).createShader(bounds),
              child: const Icon(
                Icons.wb_sunny,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowLayer(double size, {required double alpha}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.orange400.withValues(alpha: alpha.clamp(0.0, 1.0)),
      ),
    );
  }
}
