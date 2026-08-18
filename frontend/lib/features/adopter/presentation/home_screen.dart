import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/storage/care_inventory_storage.dart';
import '../../../core/storage/care_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/care_action_button.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pig_character.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/speech_bubble.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/seedling_repository.dart';

/// 가장 최근 케어 이후 경과일을 [TreeStatus]로 변환한다. 케어 기록이 아예 없으면
/// (예: 막 입양한 신규 계정) 방치로 간주하지 않고 healthy로 취급한다.
TreeStatus computeTreeStatus(DateTime? lastCompleted) {
  if (lastCompleted == null) return TreeStatus.healthy;
  final daysSince = DateTime.now().difference(lastCompleted).inDays;
  if (daysSince >= 6) return TreeStatus.pigInfested;
  if (daysSince >= 3) return TreeStatus.wilted;
  return TreeStatus.healthy;
}

/// 1f — 홈: 나의 무화과. 묘목 상태는 `GET /api/seedlings/`와 실제 연동하고,
/// 케어 게이지(물주기/영양제/햇빛)는 여전히 로컬 mock이다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends RevalidatableState<HomeScreen> {
  final _repository = SeedlingRepository();

  bool _loading = true;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  Seedling? _seedling;
  DateTime? _lastCareCompletedAt;
  int? _waterCount;
  int? _nutrientCount;
  int? _pigFeedCount;
  bool _isPigFedRecently = false;
  bool _isPigExiting = false;
  bool _exitDirectionLeft = true;

  /// 직전에 계산된 [TreeStatus] — POC 시범 적용이라 별도 저장소 없이 이 State
  /// 필드에만 기억한다(앱을 완전히 재시작하면 초기화되지만, 탭 전환/재조회에서는
  /// [RevalidatableState] 덕분에 이 State 자체가 유지되므로 충분하다).
  TreeStatus? _previousTreeStatus;

  /// wilted/pigInfested → healthy로 "좋아지는 전환"이 감지된 직후 한 번만 true가
  /// 되어 [_GrowAnimatedTree]가 tree_growing.json을 재생하게 한다. 매 홈 화면
  /// 진입마다 재생되면 안 되므로(요구사항), 이미 healthy였던 상태에서 다시
  /// healthy로 재조회되는 경우는 트리거하지 않는다.
  bool _playGrowAnimation = false;

  /// [_load]/[revalidate]가 새로 계산한 [TreeStatus]를 이전 값과 비교해 "좋아지는
  /// 전환"일 때만 [_playGrowAnimation]을 켠다. 최초 진입(_previousTreeStatus가
  /// null)에는 이전 값이 없어 전환으로 취급하지 않는다.
  void _updateGrowAnimationFlag(TreeStatus newStatus) {
    if (_previousTreeStatus != null &&
        _previousTreeStatus != TreeStatus.healthy &&
        newStatus == TreeStatus.healthy) {
      _playGrowAnimation = true;
    }
    _previousTreeStatus = newStatus;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 로그인한 사용자의 케어 완료 기록([CareStorage])과 보유 개수([CareInventoryStorage])를
  /// 함께 조회한다. userId를 아직 못 읽었으면 전부 비어있는 값([_CareState] 기본값) —
  /// 이 경우 [computeTreeStatus]가 healthy로 취급하고, 배지는 표시하지 않는다.
  Future<_CareState> _fetchCareState() async {
    final userId = await TokenStorage().readUserId();
    if (userId == null) return const _CareState();
    final careStorage = CareStorage(userId: userId);
    final lastCare = await careStorage.mostRecentCompletion();
    final isPigFedRecently = await careStorage.isPigFedRecently();
    final inventory = CareInventoryStorage(userId: userId);
    final water = await inventory.getCount(CareItemType.water);
    final nutrient = await inventory.getCount(CareItemType.nutrient);
    final pigFeed = await inventory.getCount(CareItemType.pigFeed);
    return _CareState(
      lastCare: lastCare,
      water: water,
      nutrient: nutrient,
      pigFeed: pigFeed,
      isPigFedRecently: isPigFedRecently,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedlings = await _repository.fetchSeedlings();
      final careState = await _fetchCareState();
      setState(() {
        _seedling = pickPrimarySeedling(seedlings);
        _lastCareCompletedAt = careState.lastCare;
        _waterCount = careState.water;
        _nutrientCount = careState.nutrient;
        _pigFeedCount = careState.pigFeed;
        _isPigFedRecently = careState.isPigFedRecently;
        _updateGrowAnimationFlag(computeTreeStatus(careState.lastCare));
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
      _hasLoadedOnce = true;
    }
  }

  /// `AdopterShell`이 홈 탭 재진입 시 호출한다. 완성 신고 등으로 묘목 상태가 바뀌었을
  /// 수 있으니 다시 불러오되, 기존 화면은 그대로 둔 채 응답이 오면 조용히 교체한다.
  @override
  Future<void> revalidate() async {
    if (!_hasLoadedOnce) return _load();
    try {
      final seedlings = await _repository.fetchSeedlings();
      final careState = await _fetchCareState();
      if (mounted) {
        setState(() {
          _seedling = pickPrimarySeedling(seedlings);
          _lastCareCompletedAt = careState.lastCare;
          _waterCount = careState.water;
          _nutrientCount = careState.nutrient;
          _pigFeedCount = careState.pigFeed;
          _isPigFedRecently = careState.isPigFedRecently;
          _updateGrowAnimationFlag(computeTreeStatus(careState.lastCare));
        });
      }
    } on ApiException {
      // 재조회 실패 시 기존 화면을 그대로 유지한다.
    }
  }

  Future<void> _goToAdopt() async {
    await Navigator.of(context).pushNamed('/adopter/adopt');
    // 입양 성공/실패와 무관하게 최신 상태를 다시 불러온다.
    if (mounted) _load();
  }

  Future<void> _goToPigFeed() async {
    final fed = await Navigator.of(
      context,
    ).pushNamed<bool>('/adopter/care/pig-feed');
    if (fed == true) {
      // _load()가 끝나기 전에 먼저 퇴장 애니메이션을 시작해야, 그 사이 showPig가
      // false로 바뀌어도 isPigExiting 덕분에 돼지가 화면에서 갑자기 사라지지 않는다.
      setState(() {
        _isPigExiting = true;
        _exitDirectionLeft = Random().nextBool();
      });
    }
    if (mounted) _load();
  }

  /// [AnimatedSlide.onEnd]는 최초 mount 시에도 한 번 호출되므로(변화 없는
  /// 애니메이션), 실제로 퇴장 중일 때만 리셋한다.
  void _onPigExitAnimationEnd() {
    if (_isPigExiting) setState(() => _isPigExiting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
    }
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _load);
    }
    if (_seedling == null) {
      return _EmptyState(onAdopt: _goToAdopt);
    }
    final treeStatus = computeTreeStatus(_lastCareCompletedAt);
    // 나무 톤(treeStatus)과 돼지 노출 여부는 별개다 — 6일 이상 방치돼 pigInfested
    // 톤이어도, 최근 12시간 안에 이미 먹이를 줬다면(_isPigFedRecently) 돼지는
    // 화면에서 빠진다(나무는 여전히 시든 톤 유지).
    final showPig = treeStatus == TreeStatus.pigInfested && !_isPigFedRecently;
    return _SeedlingHome(
      seedling: _seedling!,
      treeStatus: treeStatus,
      playGrowAnimation: _playGrowAnimation,
      onGrowAnimationConsumed: () =>
          setState(() => _playGrowAnimation = false),
      showPig: showPig,
      lastCareCompletedAt: _lastCareCompletedAt,
      waterCount: _waterCount,
      nutrientCount: _nutrientCount,
      pigFeedCount: _pigFeedCount,
      onPigTap: _goToPigFeed,
      isPigExiting: _isPigExiting,
      exitDirectionLeft: _exitDirectionLeft,
      onPigExitAnimationEnd: _onPigExitAnimationEnd,
    );
  }
}

/// [_HomeScreenState._fetchCareState]의 조회 결과를 묶는다. 필드 4개짜리 튜플이
/// 가독성을 해쳐 클래스로 뺐다.
class _CareState {
  const _CareState({
    this.lastCare,
    this.water,
    this.nutrient,
    this.pigFeed,
    this.isPigFedRecently = false,
  });

  final DateTime? lastCare;
  final int? water;
  final int? nutrient;
  final int? pigFeed;
  final bool isPigFedRecently;
}

/// 마지막 케어 시각을 홈 화면 문구로 변환한다. 기록이 없으면(신규 계정 등) 별도 안내를,
/// 있으면 오늘/어제/N일 전으로 표시한다.
String formatLastCare(DateTime? lastCompleted) {
  if (lastCompleted == null) return '아직 케어 기록이 없어요';
  final days = DateTime.now().difference(lastCompleted).inDays;
  if (days == 0) return '마지막 케어: 오늘';
  if (days == 1) return '마지막 케어: 어제';
  return '마지막 케어: $days일 전';
}

class _SeedlingHome extends StatelessWidget {
  const _SeedlingHome({
    required this.seedling,
    required this.treeStatus,
    required this.playGrowAnimation,
    required this.onGrowAnimationConsumed,
    required this.showPig,
    required this.lastCareCompletedAt,
    required this.waterCount,
    required this.nutrientCount,
    required this.pigFeedCount,
    required this.onPigTap,
    required this.isPigExiting,
    required this.exitDirectionLeft,
    required this.onPigExitAnimationEnd,
  });

  final Seedling seedling;
  final TreeStatus treeStatus;

  /// wilted/pigInfested → healthy 전환 직후 한 번만 true — [_GrowAnimatedTree]가
  /// tree_growing.json을 재생할지 결정한다.
  final bool playGrowAnimation;

  /// 애니메이션 재생이 끝나 정적 [FigTreeIllustration]으로 돌아간 뒤 호출되어,
  /// 부모의 [playGrowAnimation] 플래그를 리셋한다.
  final VoidCallback onGrowAnimationConsumed;

  /// pigInfested 톤이어도 최근 12시간 안에 먹이를 줬으면 false — 나무 톤과
  /// 별개로 결정된다([_HomeScreenState._buildBody] 참고).
  final bool showPig;
  final DateTime? lastCareCompletedAt;
  final int? waterCount;
  final int? nutrientCount;
  final int? pigFeedCount;
  final VoidCallback onPigTap;

  /// 먹이 주기 성공 직후 true로 켜져 퇴장 애니메이션이 재생되는 동안, 이미
  /// showPig가 false로 바뀌었어도 돼지를 화면에 붙잡아둔다.
  final bool isPigExiting;

  /// 퇴장 방향(왼쪽/오른쪽)을 매 퇴장마다 무작위로 고른 값 — [_HomeScreenState._goToPigFeed] 참고.
  final bool exitDirectionLeft;
  final VoidCallback onPigExitAnimationEnd;

  @override
  Widget build(BuildContext context) {
    final isGrowing = seedling.status == SeedlingStatus.growing;
    final daysTogether =
        DateTime.now().difference(seedling.startedAt).inDays + 1;

    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 18),
            if (treeStatus != TreeStatus.healthy) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pink100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  // 돼지가 실제로 안 보이는 상황(showPig == false)이면 pigInfested
                  // 톤이어도 wilted와 같은 문구를 쓴다 — 안 보이는 돼지를 언급하면 어색하다.
                  showPig
                      ? '6일이나 지났어요... 돼지가 찾아왔어요 🐷'
                      : '3일 동안 자리를 비웠더니...',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.badgePinkText,
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ] else
              const SizedBox(height: 28),
            _GrowAnimatedTree(
              width: 190,
              status: treeStatus,
              playAnimation: playGrowAnimation,
              onAnimationConsumed: onGrowAnimationConsumed,
            ),
            const SizedBox(height: 8),
            if (showPig || isPigExiting)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSlide(
                    offset: isPigExiting
                        ? Offset(exitDirectionLeft ? -1.5 : 1.5, 0)
                        : Offset.zero,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOut,
                    onEnd: onPigExitAnimationEnd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SpeechBubble(text: '꿀꿀~ 내가 왔다!'),
                        GestureDetector(
                          onTap: onPigTap,
                          child: const PigCharacter(width: 60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const Spacer(),
          ],
        ),
        Positioned(
          right: 14,
          top: 96,
          child: Column(
            children: [
              CareActionButton(
                emoji: '💧',
                label: '물주기',
                count: waterCount,
                onTap: () =>
                    Navigator.of(context).pushNamed('/adopter/care/water'),
              ),
              const SizedBox(height: 16),
              CareActionButton(
                emoji: '🍃',
                label: '영양제',
                count: nutrientCount,
                onTap: () =>
                    Navigator.of(context).pushNamed('/adopter/care/nutrient'),
              ),
              const SizedBox(height: 16),
              CareActionButton(
                emoji: '☀️',
                label: '햇빛',
                onTap: () =>
                    Navigator.of(context).pushNamed('/adopter/care/sunlight'),
              ),
              const SizedBox(height: 16),
              CareActionButton(
                emoji: '🍖',
                label: '돼지먹이',
                count: pigFeedCount,
                onTap: onPigTap,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '나의 무화과 #${seedling.id} 🌱',
                      style: AppTextStyles.title(),
                    ),
                    StatusBadge(
                      label: isGrowing ? '재배중' : '완료',
                      background: isGrowing
                          ? AppColors.green500
                          : AppColors.pink100,
                      textColor: isGrowing
                          ? Colors.white
                          : AppColors.badgePinkText,
                      pill: false,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGrowing
                      ? '재배자가 정성껏 돌보고 있어요 · 함께한 지 $daysTogether일째'
                      : '무화과가 다 자랐어요! 마이페이지에서 수령/기부를 선택해보세요 🎉',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatLastCare(lastCareCompletedAt),
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// [FigTreeIllustration] 자리에 들어가 "좋아지는 전환" 순간에만
/// `tree_growing.json`을 한 번 재생한 뒤 정적 일러스트로 되돌아가는 POC 위젯
/// (Lottie 도입 시범 적용, 12번 브랜치). [playAnimation]은 이 위젯이 처음
/// build될 때만 확인한다 — 이후 재생 중에 [FigTreeIllustration.status]가
/// 바뀌어도(예: 케어 게이지 조작) 재생을 중단하지 않는다.
class _GrowAnimatedTree extends StatefulWidget {
  const _GrowAnimatedTree({
    required this.width,
    required this.status,
    required this.playAnimation,
    required this.onAnimationConsumed,
  });

  final double width;
  final TreeStatus status;
  final bool playAnimation;
  final VoidCallback onAnimationConsumed;

  @override
  State<_GrowAnimatedTree> createState() => _GrowAnimatedTreeState();
}

class _GrowAnimatedTreeState extends State<_GrowAnimatedTree> {
  bool _showingAnimation = false;

  @override
  void initState() {
    super.initState();
    _showingAnimation = widget.playAnimation;
  }

  /// 재생 완료(정상 종료 또는 로드 실패) 시 한 번만 정적 일러스트로 전환하고,
  /// 부모의 [TreeStatus] 관찰 플래그를 리셋해 다음 전환까지 재생되지 않게 한다.
  void _finishAnimation() {
    if (!mounted || !_showingAnimation) return;
    setState(() => _showingAnimation = false);
    widget.onAnimationConsumed();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showingAnimation) {
      return FigTreeIllustration(width: widget.width, status: widget.status);
    }
    // FigTreeIllustration과 동일한 박스 크기를 유지해 애니메이션↔정적 일러스트
    // 전환 시 레이아웃이 흔들리지 않게 한다.
    return SizedBox(
      width: widget.width,
      height: widget.width * 1.27,
      child: Lottie.asset(
        'assets/lottie/tree_growing.json',
        repeat: false,
        fit: BoxFit.contain,
        onLoaded: (composition) {
          Future.delayed(composition.duration, _finishAnimation);
        },
        errorBuilder: (context, error, stackTrace) {
          // 에셋 로드 실패 시 크래시 대신 즉시 정적 일러스트로 폴백한다.
          // build 중 setState를 피하기 위해 다음 프레임으로 미룬다.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _finishAnimation(),
          );
          return FigTreeIllustration(width: widget.width, status: widget.status);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdopt});

  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FigTreeIllustration(width: 100),
            const SizedBox(height: 20),
            Text('아직 입양한 무화과가 없어요', style: AppTextStyles.title(fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              '무화과를 입양하면 재배자가 정성껏 키워드려요',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PigFigButton.primary(
                label: '무화과 입양하러 가기',
                onPressed: onAdopt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: PigFigButton.outline(label: '다시 시도', onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}
