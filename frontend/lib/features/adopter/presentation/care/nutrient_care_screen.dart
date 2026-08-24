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

/// 1h — 케어: 영양제. 영양제를 드래그해서 화분(흙)에 꽂으면 영양 게이지가 오른다.
/// 보유 개수([CareInventoryStorage])가 있으면 언제든 여러 번 쓸 수 있고, 0이면
/// [CareOutOfStockState] 안내로 대체된다. 완료 시 [CareStorage]에도 시각을 남겨
/// 나무 방치 판정(TreeStatus)에 반영되게 한다.
class NutrientCareScreen extends StatefulWidget {
  const NutrientCareScreen({super.key});

  @override
  State<NutrientCareScreen> createState() => _NutrientCareScreenState();
}

class _NutrientCareScreenState extends State<NutrientCareScreen> {
  CareStorage? _careStorage;
  CareInventoryStorage? _inventoryStorage;

  double _nutrition = 0.4;
  bool _hoveringTarget = false;
  int? _remainingCount;
  bool _using = false; // 게이지가 다 차서 소비 처리 중(중복 소비 방지)

  @override
  void initState() {
    super.initState();
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
    final count = await _inventoryStorage?.getCount(CareItemType.nutrient);
    if (!mounted || count == null) return;
    setState(() => _remainingCount = count);
  }

  bool get _locked => _using || (_remainingCount ?? 0) <= 0;

  void _dropNutrient() {
    if (_locked) return;
    setState(() {
      _nutrition = (_nutrition + 0.2).clamp(0, 1);
      _hoveringTarget = false;
    });
    if (_nutrition >= 1) _useNutrient();
  }

  Future<void> _useNutrient() async {
    if (_using) return;
    setState(() => _using = true);
    final consumed =
        await _inventoryStorage?.consume(CareItemType.nutrient) ?? false;
    if (!consumed) {
      // 방어적 처리: 이론상 _locked 가드로 여기까지 오지 않지만, 만일을 대비해
      // 게이지를 되돌리고 재고 없음 상태로 갱신한다.
      if (mounted) setState(() => _nutrition = 0);
      await _loadRemainingCount();
      if (mounted) setState(() => _using = false);
      return;
    }
    await _careStorage?.markCompleted(CareType.nutrient);
    if (!mounted) return;
    setState(() {
      _remainingCount = (_remainingCount ?? 1) - 1;
      _using = false;
      // 쿨다운이 사라졌으므로, 개수가 남아 있으면 바로 다시 채울 수 있게 리셋한다.
      _nutrition = (_remainingCount ?? 0) > 0 ? 0.4 : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: _remainingCount == 0
            ? const CareOutOfStockState(emoji: '🍃', itemLabel: '영양제')
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
            '영양제를 주세요!',
            style: AppTextStyles.display(fontSize: 32, color: AppColors.pink500),
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
                    maxSimultaneousDrags: _locked ? 0 : 1,
                    feedback: _nutrientStick(dragging: true),
                    childWhenDragging: Transform.translate(
                      offset: const Offset(0, -24),
                      child: Opacity(
                        opacity: 0.3,
                        child: _nutrientStick(),
                      ),
                    ),
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: _nutrientStick(),
                    ),
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            '보유한 영양제 ${_remainingCount ?? 0}개 — 이 기기에 기록돼요 🍃',
            style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
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
          Transform.flip(
            flipX: true,
            child: Transform.rotate(
              angle: -1.0,
              child: const Icon(
                Icons.reply,
                size: 18,
                color: AppColors.textCaption,
              ),
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
