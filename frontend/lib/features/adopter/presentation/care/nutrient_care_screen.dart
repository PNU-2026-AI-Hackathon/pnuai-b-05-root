import 'package:flutter/material.dart';

import '../../../../core/storage/care_storage.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/care_pot_illustration.dart';
import '../../../../shared/widgets/gauge_bar.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';

/// 1h — 케어: 영양제. 영양제를 드래그해서 화분(흙)에 꽂으면 영양 게이지가 오른다.
/// "7일에 한 번이면 충분해요" 문구에 맞춰, 최근 7일 이내 완료 기록(로컬 저장, [CareStorage])이
/// 있으면 재진입 시 잠긴 완료 상태로 보여준다.
class NutrientCareScreen extends StatefulWidget {
  const NutrientCareScreen({super.key});

  @override
  State<NutrientCareScreen> createState() => _NutrientCareScreenState();
}

class _NutrientCareScreenState extends State<NutrientCareScreen> {
  static const _cooldownDays = 7;

  CareStorage? _careStorage;

  double _nutrition = 0.4;
  bool _hoveringTarget = false;
  bool _completed = false;
  int _daysUntilNext = _cooldownDays;

  @override
  void initState() {
    super.initState();
    _initCareStorage();
  }

  Future<void> _initCareStorage() async {
    final userId = await TokenStorage().readUserId();
    if (!mounted || userId == null) return;
    _careStorage = CareStorage(userId: userId);
    await _loadCareStatus();
  }

  Future<void> _loadCareStatus() async {
    final last = await _careStorage?.getLastCompleted(CareType.nutrient);
    if (!mounted || last == null) return;
    final daysSince = DateTime.now().difference(last).inDays;
    if (daysSince < _cooldownDays) {
      setState(() {
        _completed = true;
        _nutrition = 1;
        _daysUntilNext = _cooldownDays - daysSince;
      });
    }
  }

  void _dropNutrient() {
    if (_completed) return;
    setState(() {
      _nutrition = (_nutrition + 0.2).clamp(0, 1);
      _hoveringTarget = false;
    });
    if (_nutrition >= 1) _markCompleted();
  }

  Future<void> _markCompleted() async {
    if (_completed) return;
    setState(() {
      _completed = true;
      _daysUntilNext = _cooldownDays;
    });
    await _careStorage?.markCompleted(CareType.nutrient);
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
                _completed ? '이번 주 영양제 완료! 🍃' : '영양제를 주세요!',
                style: AppTextStyles.display(
                  fontSize: 32,
                  color: AppColors.pink500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _completed
                    ? '다음 영양제까지 $_daysUntilNext일 남았어요'
                    : '영양제를 끌어서 흙에 꽂아보세요',
                style: AppTextStyles.guide(),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Draggable<String>(
                        data: 'nutrient',
                        maxSimultaneousDrags: _completed ? 0 : 1,
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
                        builder: (context, candidate, rejected) =>
                            CarePotIllustration(overlay: _dropRing()),
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
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: -6,
                child: Container(
                  width: 16,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.green500,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFCBE5C4),
                    width: 2,
                  ),
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
                child: const Icon(
                  Icons.eco,
                  size: 22,
                  color: AppColors.green800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '잡아서 끌기',
            style: AppTextStyles.body(
              fontSize: 12,
              color: const Color(0xFFB7B2A4),
            ),
          ),
          const SizedBox(height: 4),
          Transform.rotate(
            angle: -1.0,
            child: const Icon(
              Icons.reply,
              size: 18,
              color: AppColors.textCaption,
            ),
          ),
        ],
      ),
    );
  }

  /// 드래그 중인 영양제를 받는 드롭 타겟 링. 화분(흙) 위에 겹쳐 그려지며,
  /// 호버 여부에 따라 두께·불투명도·glow 크기가 커진다.
  Widget _dropRing() {
    final active = _hoveringTarget;
    return Container(
      width: active ? 76 : 66,
      height: active ? 76 : 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.pink100.withValues(alpha: active ? 0.35 : 0.18),
        border: Border.all(
          color: AppColors.pink500.withValues(alpha: active ? 1 : 0.55),
          width: active ? 3 : 2,
        ),
      ),
    );
  }
}
