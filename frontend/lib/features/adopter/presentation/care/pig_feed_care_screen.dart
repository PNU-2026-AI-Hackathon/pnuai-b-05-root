import 'package:flutter/material.dart';

import '../../../../core/storage/care_inventory_storage.dart';
import '../../../../core/storage/care_storage.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/care_out_of_stock_state.dart';
import '../../../../shared/widgets/gauge_bar.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';
import '../../../../shared/widgets/pigfig_button.dart';
import '../../../../shared/widgets/speech_bubble.dart';
import '../../../../shared/widgets/status_badge.dart';

enum _FeedStage { before, inProgress, complete }

enum _PigMood { calm, eating, satisfied }

/// 먹이통에 장식으로 남은 음식 아이콘. 실제 보유 재고(진짜 개수는
/// [CareInventoryStorage])와는 무관하게, 탭 진행도에 따라 줄어드는 연출용이다.
const _troughFoodIcons = ['🍎', '🥕', '🌽'];

/// 케어: 돼지 먹이 주기. 나무에 나타난 돼지를 먹이 아이템(🍖)을 반복해서 눌러
/// 배부르게 해 쫓아낸다. 보유 개수([CareInventoryStorage])가 있으면 쓸 수 있고,
/// 0이면 [CareOutOfStockState] 안내로 대체된다. 20탭을 채우면(=[_FeedStage.complete])
/// [CareInventoryStorage.consume]으로 먹이 1개를 소비하고 [CareStorage.markPigFed]로
/// 시각을 남긴 뒤, "확인"을 누르면 `Navigator.pop(context, true)`로 홈 화면에
/// 성공 여부를 전달하며 화면을 나간다(홈 화면은 이 결과로 돼지 퇴장 애니메이션을 재생).
class PigFeedCareScreen extends StatefulWidget {
  const PigFeedCareScreen({super.key});

  static const _targetTaps = 20;

  @override
  State<PigFeedCareScreen> createState() => _PigFeedCareScreenState();
}

class _PigFeedCareScreenState extends State<PigFeedCareScreen>
    with SingleTickerProviderStateMixin {
  CareStorage? _careStorage;
  CareInventoryStorage? _inventoryStorage;

  int _tapCount = 0;
  int? _remainingCount;
  bool _using = false; // 20탭 완료 후 소비 처리 중(중복 소비 방지)
  bool _pressed = false;
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
    final count = await _inventoryStorage?.getCount(CareItemType.pigFeed);
    if (!mounted || count == null) return;
    setState(() => _remainingCount = count);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _locked => _using || (_remainingCount ?? 0) <= 0;

  _FeedStage get _stage {
    if (_tapCount <= 0) return _FeedStage.before;
    if (_tapCount >= PigFeedCareScreen._targetTaps) return _FeedStage.complete;
    return _FeedStage.inProgress;
  }

  _PigMood get _mood => switch (_stage) {
    _FeedStage.before => _PigMood.calm,
    _FeedStage.inProgress => _PigMood.eating,
    _FeedStage.complete => _PigMood.satisfied,
  };

  /// 먹이통에 남은 장식용 음식 아이콘 개수(0~3) — 실제 보유 재고와 무관하다.
  int get _troughFoodLeft {
    final ratio = PigFeedCareScreen._targetTaps / _troughFoodIcons.length;
    final consumed = (_tapCount / ratio).floor();
    return (_troughFoodIcons.length - consumed).clamp(
      0,
      _troughFoodIcons.length,
    );
  }

  Future<void> _handleTap() async {
    if (_locked || _stage == _FeedStage.complete) return;
    setState(() {
      _tapCount = (_tapCount + 1).clamp(0, PigFeedCareScreen._targetTaps);
      _pressed = false;
    });
    if (_tapCount >= PigFeedCareScreen._targetTaps) {
      await _consumeAndRecord();
    }
  }

  Future<void> _consumeAndRecord() async {
    setState(() => _using = true);
    final consumed =
        await _inventoryStorage?.consume(CareItemType.pigFeed) ?? false;
    if (!consumed) {
      // 방어적 처리: 이론상 _locked 가드로 여기까지 오지 않지만, 만일을 대비해
      // 탭 카운트를 되돌리고 재고 없음 상태로 갱신한다.
      if (mounted) setState(() => _tapCount = 0);
      await _loadRemainingCount();
      if (mounted) setState(() => _using = false);
      return;
    }
    await _careStorage?.markPigFed();
    if (!mounted) return;
    setState(() {
      _remainingCount = (_remainingCount ?? 1) - 1;
      _using = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: _remainingCount == 0
            ? const CareOutOfStockState(emoji: '🍖', itemLabel: '먹이')
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final stage = _stage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      child: Column(
        children: [
          _statusPill(stage),
          const SizedBox(height: 14),
          Text(
            _headline(stage),
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              fontSize: 30,
              color: AppColors.pink500,
            ),
          ),
          const SizedBox(height: 10),
          Text(_subtitle(stage), style: AppTextStyles.guide()),
          Expanded(child: _interactionArea(stage)),
          _gaugeCard(stage),
          const SizedBox(height: 16),
          Text(
            _caption(stage),
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '보유한 먹이 ${_remainingCount ?? 0}개 — 이 기기에 기록돼요 🍖',
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.textCaption,
            ),
          ),
          if (stage == _FeedStage.complete) ...[
            const SizedBox(height: 16),
            PigFigButton.positive(
              label: '확인',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(_FeedStage stage) {
    final isComplete = stage == _FeedStage.complete;
    return StatusBadge(
      label: isComplete ? '위협 해제' : '돼지 출현!',
      background: isComplete ? AppColors.badgeGreenBg : AppColors.pink100,
      textColor: isComplete
          ? AppColors.badgeGreenText
          : AppColors.badgePinkText,
    );
  }

  Widget _gaugeCard(_FeedStage stage) {
    final isComplete = stage == _FeedStage.complete;
    final percent = ((_tapCount / PigFeedCareScreen._targetTaps) * 100)
        .round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.badgeGreenBg : const Color(0xFFFDF0F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: GaugeBar(
        value: _tapCount / PigFeedCareScreen._targetTaps,
        fillColor: isComplete ? AppColors.green500 : AppColors.pink500,
        trackColor: isComplete
            ? const Color(0xFFDCEEDC)
            : const Color(0xFFF6DEE2),
        height: 10,
        label: '포만 게이지',
        trailing: '$percent%',
      ),
    );
  }

  Widget _interactionArea(_FeedStage stage) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (stage != _FeedStage.complete)
          Align(alignment: const Alignment(0, -0.85), child: _feedButton()),
        if (stage == _FeedStage.inProgress) ...[
          const Positioned(
            top: 4,
            right: 12,
            child: SpeechBubble(text: '톡톡톡!'),
          ),
          const Align(
            alignment: Alignment(-0.42, -0.35),
            child: Text('🍎', style: TextStyle(fontSize: 20)),
          ),
          const Align(
            alignment: Alignment(0.32, -0.18),
            child: Text('🥕', style: TextStyle(fontSize: 16)),
          ),
        ],
        if (stage == _FeedStage.complete)
          const Align(
            alignment: Alignment(0, -0.92),
            child: SpeechBubble(text: '꿀꿀~ 잘 먹었다!'),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _PigFeedMascot(mood: _mood, foodLeft: _troughFoodLeft),
        ),
      ],
    );
  }

  Widget _feedButton() {
    return GestureDetector(
      onTapDown: _locked ? null : (_) => setState(() => _pressed = true),
      onTapUp: _locked ? null : (_) => setState(() => _pressed = false),
      onTapCancel: _locked ? null : () => setState(() => _pressed = false),
      onTap: _locked ? null : _handleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final t = _pulseController.value;
                    return Opacity(
                      opacity: (0.5 * (1 - t)).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1 + 0.35 * t,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: const BoxDecoration(
                            color: AppColors.pink100,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                AnimatedScale(
                  scale: _pressed ? 0.88 : 1.0,
                  duration: const Duration(milliseconds: 90),
                  child: const Text('🍖', style: TextStyle(fontSize: 44)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '톡톡!',
            style: AppTextStyles.body(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _headline(_FeedStage stage) => switch (stage) {
    _FeedStage.before => '먹이를 줘서\n쫓아내주세요!',
    _FeedStage.inProgress => '조금만 더!\n계속 눌러주세요',
    _FeedStage.complete => '배가 불러서\n돌아갔어요!',
  };

  String _subtitle(_FeedStage stage) => switch (stage) {
    _FeedStage.before => '먹이를 톡톡 눌러 배부르게 해주세요',
    _FeedStage.inProgress => '$_tapCount / ${PigFeedCareScreen._targetTaps} 탭',
    _FeedStage.complete => '무화과가 안전해졌어요',
  };

  String _caption(_FeedStage stage) => switch (stage) {
    _FeedStage.before => '먹이 아이템은 게임에서 모을 수 있어요 🎮',
    _FeedStage.inProgress => '정신없이 받아먹고 있어요 🐽',
    _FeedStage.complete => '돼지는 며칠 뒤 다시 나타날 수 있어요 🐷',
  };
}

/// 돼지 얼굴 + 먹이통 일러스트. 원/사각형 도형 조합으로 그린다(다른 화면
/// 일러스트와 동일한 컨벤션, 예: [CarePotIllustration]). 눈·입 모양이 [mood]에
/// 따라 바뀌고, 먹이통에 [foodLeft]개만큼 음식 아이콘이 남는다.
class _PigFeedMascot extends StatelessWidget {
  const _PigFeedMascot({required this.mood, required this.foodLeft});

  final _PigMood mood;
  final int foodLeft;

  @override
  Widget build(BuildContext context) {
    final shownFoodCount = foodLeft.clamp(0, _troughFoodIcons.length);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 130,
          height: 118,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                top: 2,
                left: 10,
                child: _FeedCircle(size: 34, color: AppColors.pink500),
              ),
              const Positioned(
                top: 6,
                right: 8,
                child: _FeedCircle(size: 32, color: AppColors.pink500),
              ),
              Positioned(
                top: 16,
                left: 6,
                child: Container(
                  width: 118,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9A8B6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              ..._eyes(),
              _mouth(),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: -6),
          width: 112,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.brown600,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(42)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: -11,
                left: 6,
                right: 6,
                child: Container(
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7A4E30),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: -17,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < shownFoodCount; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          _troughFoodIcons[i],
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _eyes() {
    switch (mood) {
      case _PigMood.calm:
        return const [
          Positioned(
            top: 52,
            left: 34,
            child: _FeedCircle(size: 9, color: Color(0xFF2B2B2B)),
          ),
          Positioned(
            top: 52,
            right: 34,
            child: _FeedCircle(size: 9, color: Color(0xFF2B2B2B)),
          ),
        ];
      case _PigMood.eating:
        return const [
          Positioned(top: 50, left: 33, child: _ArcEye(fromTop: true)),
          Positioned(top: 50, right: 33, child: _ArcEye(fromTop: true)),
        ];
      case _PigMood.satisfied:
        return const [
          Positioned(
            top: 56,
            left: 30,
            child: _FeedCircle(size: 16, color: Color(0xFFFBC4CE)),
          ),
          Positioned(
            top: 56,
            right: 30,
            child: _FeedCircle(size: 16, color: Color(0xFFFBC4CE)),
          ),
          Positioned(top: 48, left: 38, child: _ArcEye(fromTop: false)),
          Positioned(top: 48, right: 38, child: _ArcEye(fromTop: false)),
        ];
    }
  }

  Widget _mouth() {
    switch (mood) {
      case _PigMood.calm:
        return const Positioned(
          top: 66,
          left: 0,
          right: 0,
          child: Center(child: _Snout(width: 34, height: 22)),
        );
      case _PigMood.eating:
        return const Positioned(
          top: 64,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 40,
              height: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFF08CA0),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF7A3B49),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      case _PigMood.satisfied:
        return const Positioned(
          top: 66,
          left: 0,
          right: 0,
          child: Center(child: _Snout(width: 32, height: 20)),
        );
    }
  }
}

class _FeedCircle extends StatelessWidget {
  const _FeedCircle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 돼지 주둥이: 둥근 패드 + 콧구멍 2개. calm/satisfied 표정에 쓰인다.
class _Snout extends StatelessWidget {
  const _Snout({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF08CA0),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [_Nostril(), SizedBox(width: 6), _Nostril()],
      ),
    );
  }
}

class _Nostril extends StatelessWidget {
  const _Nostril();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 7,
      decoration: BoxDecoration(
        color: const Color(0xFFC9647C),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// 위/아래 중 한쪽 테두리만 그려 곡선 눈매를 표현한다 — eating(윗선, 부릅뜬
/// 느낌)과 satisfied(아랫선, 감은 느낌) 표정에 쓰인다.
class _ArcEye extends StatelessWidget {
  const _ArcEye({required this.fromTop});
  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: Color(0xFF2B2B2B), width: 3);
    return Container(
      width: 11,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: fromTop
            ? const Border(top: side)
            : const Border(bottom: side),
      ),
    );
  }
}
