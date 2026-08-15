import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/storage/care_inventory_storage.dart';
import '../../../../core/storage/care_storage.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/care_out_of_stock_state.dart';
import '../../../../shared/widgets/care_pot_illustration.dart';
import '../../../../shared/widgets/gauge_bar.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';

/// 1g — 케어: 물주기. 물방울을 꾹 누르는 동안 수분 게이지가 차오른다.
/// 보유 개수([CareInventoryStorage])가 있으면 언제든 여러 번 쓸 수 있고, 0이면
/// [CareOutOfStockState] 안내로 대체된다. 완료 시 [CareStorage]에도 시각을 남겨
/// 나무 방치 판정(TreeStatus)에 반영되게 한다.
class WaterCareScreen extends StatefulWidget {
  const WaterCareScreen({super.key});

  @override
  State<WaterCareScreen> createState() => _WaterCareScreenState();
}

class _WaterCareScreenState extends State<WaterCareScreen>
    with SingleTickerProviderStateMixin {
  CareStorage? _careStorage;
  CareInventoryStorage? _inventoryStorage;

  double _moisture = 0.6;
  int? _remainingCount;
  bool _pressing = false;
  bool _using = false; // 게이지가 다 차서 소비 처리 중(중복 소비 방지)
  Timer? _holdTimer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _initStorages();
  }

  Future<void> _initStorages() async {
    final userId = await TokenStorage().readUserId();
    if (!mounted || userId == null) return;
    _careStorage = CareStorage(userId: userId);
    _inventoryStorage = CareInventoryStorage(userId: userId);
    await _loadRemainingCount();
  }

  Future<void> _loadRemainingCount() async {
    final count = await _inventoryStorage?.getCount(CareItemType.water);
    if (!mounted || count == null) return;
    setState(() => _remainingCount = count);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  bool get _locked => _using || (_remainingCount ?? 0) <= 0;

  void _startFilling() {
    if (_locked) return;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      setState(() => _moisture = (_moisture + 0.05).clamp(0, 1));
      if (_moisture >= 1) {
        _holdTimer?.cancel();
        _useWater();
      }
    });
  }

  void _stopFilling() => _holdTimer?.cancel();

  Future<void> _useWater() async {
    if (_using) return;
    setState(() {
      _using = true;
      _pressing = false;
    });
    final consumed = await _inventoryStorage?.consume(CareItemType.water) ?? false;
    if (!consumed) {
      // 방어적 처리: 이론상 _locked 가드로 여기까지 오지 않지만, 만일을 대비해
      // 게이지를 되돌리고 재고 없음 상태로 갱신한다.
      if (mounted) setState(() => _moisture = 0);
      await _loadRemainingCount();
      if (mounted) setState(() => _using = false);
      return;
    }
    await _careStorage?.markCompleted(CareType.water);
    if (!mounted) return;
    setState(() {
      _remainingCount = (_remainingCount ?? 1) - 1;
      _using = false;
      // 하루 1회 제한이 사라졌으므로, 개수가 남아 있으면 바로 다시 채울 수 있게 리셋한다.
      _moisture = (_remainingCount ?? 0) > 0 ? 0 : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: _remainingCount == 0
            ? const CareOutOfStockState(emoji: '💧', itemLabel: '물')
            : _buildGauge(),
      ),
    );
  }

  Widget _buildGauge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
      child: Column(
        children: [
          Text(
            '물을 주세요!',
            style: AppTextStyles.display(fontSize: 32, color: AppColors.pink500),
          ),
          const SizedBox(height: 10),
          Text('물방울을 꾹 눌러 화분에 부어보세요', style: AppTextStyles.guide()),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onLongPressStart: _locked
                      ? null
                      : (_) {
                          setState(() => _pressing = true);
                          _startFilling();
                        },
                  onLongPressEnd: _locked
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
                const CarePotIllustration(),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            '보유한 물 ${_remainingCount ?? 0}개 — 이 기기에 기록돼요 💧',
            style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
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

}
