import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gauge_bar.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';
import '../../../../shared/widgets/step_indicator.dart';

/// 1h — 케어: 영양제. 영양제를 드래그해서 화분(흙)에 꽂으면 영양 게이지가 오른다.
class NutrientCareScreen extends StatefulWidget {
  const NutrientCareScreen({super.key});

  @override
  State<NutrientCareScreen> createState() => _NutrientCareScreenState();
}

class _NutrientCareScreenState extends State<NutrientCareScreen> {
  double _nutrition = 0.4;
  bool _hoveringTarget = false;

  void _dropNutrient() {
    setState(() {
      _nutrition = (_nutrition + 0.2).clamp(0, 1);
      _hoveringTarget = false;
    });
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
              const StepIndicator(current: 1, total: 1),
              const SizedBox(height: 22),
              Text(
                '영양제를 주세요!',
                style: AppTextStyles.display(
                  fontSize: 32,
                  color: const Color(0xFFF7A0AE),
                ),
              ),
              const SizedBox(height: 10),
              Text('영양제를 끌어서 흙에 꽂아보세요', style: AppTextStyles.guide()),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Draggable<String>(
                        data: 'nutrient',
                        feedback: _nutrientStick(dragging: true),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _nutrientStick(),
                        ),
                        child: _nutrientStick(),
                      ),
                    ),
                    Expanded(
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (_) {
                          setState(() => _hoveringTarget = true);
                          return true;
                        },
                        onLeave: (_) => setState(() => _hoveringTarget = false),
                        onAcceptWithDetails: (_) => _dropNutrient(),
                        builder: (context, candidate, rejected) => _potTarget(),
                      ),
                    ),
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
                  color: const Color(0xFFF2F8EF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: GaugeBar(
                  value: _nutrition,
                  fillColor: AppColors.green500,
                  trackColor: const Color(0xFFE3EEDD),
                  height: 10,
                  label: '영양 게이지',
                  trailing: '${(_nutrition * 100).round()}%',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '영양제는 7일에 한 번이면 충분해요 🍃',
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

  Widget _nutrientStick({bool dragging = false}) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCBE5C4), width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: dragging
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: const Text('🍃', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 6),
          Text(
            '잡아서 끌기',
            style: AppTextStyles.body(
              fontSize: 12,
              color: const Color(0xFFB7B2A4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _potTarget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 64,
          decoration: BoxDecoration(
            color: _hoveringTarget
                ? const Color(0xFFA9713F)
                : const Color(0xFFC08552),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(22),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '여기에 꽂기',
          style: AppTextStyles.body(
            fontSize: 12,
            color: const Color(0xFFB7B2A4),
          ),
        ),
      ],
    );
  }
}
