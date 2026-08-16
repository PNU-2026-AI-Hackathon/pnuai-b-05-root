import 'package:flutter/material.dart';

import '../../../core/storage/inventory_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pig_character.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import 'games/balloon_pop/balloon_pop_screen.dart';
import 'games/fig_quiz/fig_quiz_screen.dart';
import 'games/models/game_item.dart';
import 'games/models/game_result.dart';
import 'games/models/game_type.dart';
import 'games/pest_catch/pest_catch_screen.dart';
import 'games/watering_timing/watering_timing_screen.dart';

class _GameCardData {
  const _GameCardData({
    required this.type,
    required this.title,
    required this.description,
    required this.difficultyLabel,
    required this.difficultyBg,
    required this.difficultyTextColor,
    required this.icon,
  });

  final GameType type;
  final String title;
  final String description;
  final String difficultyLabel;
  final Color difficultyBg;
  final Color difficultyTextColor;
  final Widget icon;
}

class _ItemStack {
  const _ItemStack(this.emoji, this.count);

  final String emoji;
  final int count;
}

/// 1m — 게임 탭: 2x2 게임 카드 그리드 + 보유 아이템 바.
/// 게임 4종(무화과 퀴즈·물주기 타이밍·해충 잡기·돼지 풍선 터뜨리기) 모두 실제 게임
/// 화면으로 연결된다. 보유 아이템은 [InventoryStorage]에서 실제로 읽어와 표시한다(게임에서
/// 아이템을 획득하고 돌아오면 갱신됨).
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const _mediumDifficultyBg = Color(0xFFAFD6A0);

  final _tokenStorage = TokenStorage();
  InventoryStorage? _inventory;
  List<GameItem> _ownedItems = [];

  @override
  void initState() {
    super.initState();
    _initInventory();
  }

  // 보유 아이템은 계정별로 분리 저장되므로([InventoryStorage] 참고), 로그인한
  // 사용자의 id를 먼저 조회한 뒤에야 인스턴스를 만들 수 있다.
  Future<void> _initInventory() async {
    final userId = await _tokenStorage.readUserId();
    if (!mounted || userId == null) return;
    _inventory = InventoryStorage(userId: userId);
    await _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await _inventory!.getItems();
    if (!mounted) return;
    setState(() => _ownedItems = items);
  }

  static final _games = [
    _GameCardData(
      type: GameType.balloonPop,
      title: '돼지 풍선 터뜨리기',
      description: '풍선을 터뜨려 아이템 획득!',
      difficultyLabel: '쉬움',
      difficultyBg: AppColors.green500,
      difficultyTextColor: Colors.white,
      icon: const PigCharacter(width: 56),
    ),
    _GameCardData(
      type: GameType.quiz,
      title: '무화과 퀴즈',
      description: '무화과 상식 퀴즈 도전!',
      difficultyLabel: '보통',
      difficultyBg: _mediumDifficultyBg,
      difficultyTextColor: Colors.white,
      icon: const Text('🍃', style: TextStyle(fontSize: 36)),
    ),
    _GameCardData(
      type: GameType.pestCatch,
      title: '해충 잡기',
      description: '해충을 빠르게 잡아라!',
      difficultyLabel: '보통',
      difficultyBg: _mediumDifficultyBg,
      difficultyTextColor: Colors.white,
      icon: const Text('🐛', style: TextStyle(fontSize: 34)),
    ),
    _GameCardData(
      type: GameType.wateringTiming,
      title: '물주기 타이밍',
      description: '정확한 타이밍에 물을 주세요!',
      difficultyLabel: '어려움',
      difficultyBg: AppColors.pink100,
      difficultyTextColor: AppColors.warningPink,
      icon: const Text('💧', style: TextStyle(fontSize: 34)),
    ),
  ];

  Future<void> _openGame(GameType type) async {
    // 게임 4종 모두 실제 게임 화면으로 연결된다. 각 게임은 종료 시 GameResult를 돌려주며,
    // 획득한 아이템(등급에 따라 여러 개일 수 있음)을 모두 저장하고 보유 아이템 바를
    // 갱신하는 동일한 패턴을 따른다.
    switch (type) {
      case GameType.quiz:
        final result = await Navigator.of(context).push<GameResult>(
          MaterialPageRoute(builder: (_) => const FigQuizScreen()),
        );
        if (!mounted) return;
        await _saveEarnedItems(result?.itemsEarned);
      case GameType.wateringTiming:
        final result = await Navigator.of(context).push<GameResult>(
          MaterialPageRoute(builder: (_) => const WateringTimingScreen()),
        );
        if (!mounted) return;
        await _saveEarnedItems(result?.itemsEarned);
      case GameType.pestCatch:
        final result = await Navigator.of(context).push<GameResult>(
          MaterialPageRoute(builder: (_) => const PestCatchScreen()),
        );
        if (!mounted) return;
        await _saveEarnedItems(result?.itemsEarned);
      case GameType.balloonPop:
        final result = await Navigator.of(context).push<GameResult>(
          MaterialPageRoute(builder: (_) => const BalloonPopScreen()),
        );
        if (!mounted) return;
        await _saveEarnedItems(result?.itemsEarned);
    }
  }

  /// 획득한 아이템을 모두 보유 아이템 저장소에 추가하고 보유 아이템 바를 갱신한다.
  /// [items]가 비어있으면(클리어 실패 등) 아무것도 하지 않는다.
  Future<void> _saveEarnedItems(List<GameItem>? items) async {
    if (items == null || items.isEmpty) return;
    for (final item in items) {
      await _inventory?.addItem(item);
    }
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
        child: Column(
          children: [
            Text('🎮 Pig.Fig. 게임', style: AppTextStyles.display(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              '게임으로 아이템을 모아 돼지를 쫓아내세요!',
              style: AppTextStyles.guide(
                fontSize: 15,
                color: AppColors.badgeGreenText,
              ),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _GameCard(
                      data: _games[0],
                      onTap: () => _openGame(_games[0].type),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _GameCard(
                      data: _games[1],
                      onTap: () => _openGame(_games[1].type),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _GameCard(
                      data: _games[2],
                      onTap: () => _openGame(_games[2].type),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _GameCard(
                      data: _games[3],
                      onTap: () => _openGame(_games[3].type),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _OwnedItemsCard(items: _ownedItems),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.data, required this.onTap});

  final _GameCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 54, child: Center(child: data.icon)),
            const SizedBox(height: 8),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title(
                fontSize: 15,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              data.description,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textMuted,
              ).copyWith(height: 1.5),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(
                label: data.difficultyLabel,
                background: data.difficultyBg,
                textColor: data.difficultyTextColor,
                pill: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnedItemsCard extends StatelessWidget {
  const _OwnedItemsCard({required this.items});

  final List<GameItem> items;

  @override
  Widget build(BuildContext context) {
    // 같은 아이템은 id 기준으로 묶어 이모지 + 개수 칩으로 표시한다.
    final stacks = <String, _ItemStack>{};
    for (final item in items) {
      final prev = stacks[item.id];
      stacks[item.id] = _ItemStack(item.emoji, (prev?.count ?? 0) + 1);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '보유 아이템',
            style: AppTextStyles.title(
              fontSize: 16,
              color: AppColors.badgeGreenText,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          if (stacks.isEmpty)
            Text(
              '아직 없어요',
              style: AppTextStyles.caption(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            )
          else
            Row(
              children: [
                for (final stack in stacks.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _ItemChip(item: stack),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.item});

  final _ItemStack item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5EC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(item.emoji, style: const TextStyle(fontSize: 18)),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            constraints: const BoxConstraints(minWidth: 17),
            height: 17,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.pink500,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${item.count}',
              style: AppTextStyles.body(fontSize: 10, color: Colors.white)
                  .copyWith(fontWeight: FontWeight.w700, height: 1),
            ),
          ),
        ),
      ],
    );
  }
}
