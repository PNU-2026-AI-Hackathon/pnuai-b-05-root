import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/storage/care_inventory_storage.dart';
import '../../../core/storage/care_storage.dart';
import '../../../core/storage/growth_stage_storage.dart';
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
import '../data/diary_repository.dart';
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

/// 백엔드 `Diary.GrowthStage` choices와 동일한 순서 — 인덱스 비교로 "진행"을 판단한다.
const _growthStageOrder = ['rooting', 'leafing', 'branching', 'mature'];

/// [stage]가 [_growthStageOrder]에 없으면(알 수 없는/미래 버전 코드) -1을 반환해
/// "진행 아님"으로 방어적으로 처리한다.
int _growthStageIndex(String stage) => _growthStageOrder.indexOf(stage);

/// 1f — 홈: 나의 무화과. 묘목 상태는 `GET /api/seedlings/`와 실제 연동하고,
/// 케어 게이지(물주기/영양제/햇빛)는 여전히 로컬 mock이다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends RevalidatableState<HomeScreen> {
  final _repository = SeedlingRepository();
  final _diaryRepository = DiaryRepository();

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

  /// 현재 성장 단계(코드). 일지에 growth_stage가 하나도 없으면(신규 묘목, 또는 기존
  /// 일지들) 'rooting' 기본값.
  String _growthStage = 'rooting';

  /// non-null이면 [_growthStage] 직전 단계(진행 애니메이션의 "출발" 구간) — 진행이
  /// 감지되지 않았거나(변화 없음/히스토리 없음) 이미 소비된 경우 null.
  String? _growthStageAdvanceFrom;

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

  /// 대표 묘목의 최신 일지에서 성장 단계를 읽고, 계정별 저장소([GrowthStageStorage])와
  /// 비교해 "진행됨"을 감지한다. 부가 기능이라 실패해도 화면 전체 에러로 번지면 안 되므로
  /// [ApiException]을 이 메서드 안에서 직접 삼키고 기본값으로 폴백한다(센서/비전/챗봇
  /// Gemini 연동에서 쓰는 것과 동일한 "게이트 확인 → try/except → 정적 폴백" 관례).
  Future<_GrowthStageState> _fetchGrowthStageState(int seedlingId) async {
    String current = 'rooting';
    try {
      final diaries = await _diaryRepository.fetchDiaries(seedlingId);
      for (final diary in diaries) {
        if (diary.growthStage != null) {
          current = diary.growthStage!;
          break;
        }
      }
    } on ApiException {
      return const _GrowthStageState.initial();
    }

    final userId = await TokenStorage().readUserId();
    if (userId == null) return _GrowthStageState(stage: current);

    final storage = GrowthStageStorage(userId: userId);
    final stored = await storage.getLastSeenStage();
    // 감지 즉시 무조건 최신값으로 덮어쓴다 — 이 State가 이후 unmount되거나 setState가
    // 반영되지 않아도, "이 계정이 current 단계를 확인했다"는 사실 자체는 위젯 수명과
    // 무관하게 남아야 한다(CareStorage.markCompleted와 동일한 관례).
    await storage.setLastSeenStage(current);

    final storedIndex = stored == null ? -1 : _growthStageIndex(stored);
    final currentIndex = _growthStageIndex(current);
    final advanced = stored != null && storedIndex >= 0 && currentIndex > storedIndex;
    return _GrowthStageState(stage: current, advanceFrom: advanced ? stored : null);
  }

  /// [_load]/[revalidate]가 공유하는 다단계 조회. 대표 묘목을 먼저 고른 뒤, 케어 상태와
  /// 성장 단계 상태를 병렬로 조회한다(서로 독립적인 조회라 순차로 기다릴 이유가 없다).
  Future<_HomeFetchResult> _fetchData() async {
    final seedlings = await _repository.fetchSeedlings();
    final seedling = pickPrimarySeedling(seedlings);
    final careFuture = _fetchCareState();
    final stageFuture = seedling != null
        ? _fetchGrowthStageState(seedling.id)
        : Future.value(const _GrowthStageState.initial());
    final careState = await careFuture;
    final growthStageState = await stageFuture;
    return _HomeFetchResult(
      seedling: seedling,
      careState: careState,
      growthStageState: growthStageState,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await _fetchData();
      setState(() {
        _seedling = result.seedling;
        _lastCareCompletedAt = result.careState.lastCare;
        _waterCount = result.careState.water;
        _nutrientCount = result.careState.nutrient;
        _pigFeedCount = result.careState.pigFeed;
        _isPigFedRecently = result.careState.isPigFedRecently;
        _growthStage = result.growthStageState.stage;
        _growthStageAdvanceFrom = result.growthStageState.advanceFrom;
        _updateGrowAnimationFlag(computeTreeStatus(result.careState.lastCare));
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
      final result = await _fetchData();
      if (mounted) {
        setState(() {
          _seedling = result.seedling;
          _lastCareCompletedAt = result.careState.lastCare;
          _waterCount = result.careState.water;
          _nutrientCount = result.careState.nutrient;
          _pigFeedCount = result.careState.pigFeed;
          _isPigFedRecently = result.careState.isPigFedRecently;
          _growthStage = result.growthStageState.stage;
          _growthStageAdvanceFrom = result.growthStageState.advanceFrom;
          _updateGrowAnimationFlag(computeTreeStatus(result.careState.lastCare));
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

  Future<void> _goToWaterCare() async {
    await Navigator.of(context).pushNamed('/adopter/care/water');
    if (mounted) _load();
  }

  Future<void> _goToNutrientCare() async {
    await Navigator.of(context).pushNamed('/adopter/care/nutrient');
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

  /// [_LottiePig]가 퇴장 애니메이션을 끝마쳤을 때 호출한다(자체적으로 1회만
  /// 호출되도록 가드하지만, 방어적으로 여기서도 이미 false면 무시한다).
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
      onGrowAnimationConsumed: () => setState(() => _playGrowAnimation = false),
      growthStage: _growthStage,
      growthStageAdvanceFrom: _growthStageAdvanceFrom,
      showPig: showPig,
      lastCareCompletedAt: _lastCareCompletedAt,
      waterCount: _waterCount,
      nutrientCount: _nutrientCount,
      pigFeedCount: _pigFeedCount,
      onWaterTap: _goToWaterCare,
      onNutrientTap: _goToNutrientCare,
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

/// [_HomeScreenState._fetchGrowthStageState] 조회 결과.
class _GrowthStageState {
  const _GrowthStageState({required this.stage, this.advanceFrom});
  const _GrowthStageState.initial() : stage = 'rooting', advanceFrom = null;

  final String stage;

  /// non-null이면 [stage] 직전 단계 — 진행 애니메이션의 "출발" 구간.
  final String? advanceFrom;
}

/// [_HomeScreenState._fetchData]가 묶어 반환하는 다단계 조회 결과 — [_HomeScreenState._load]/
/// [_HomeScreenState.revalidate]가 중복 없이 공유한다.
class _HomeFetchResult {
  const _HomeFetchResult({
    required this.seedling,
    required this.careState,
    required this.growthStageState,
  });

  final Seedling? seedling;
  final _CareState careState;
  final _GrowthStageState growthStageState;
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
    required this.growthStage,
    required this.growthStageAdvanceFrom,
    required this.showPig,
    required this.lastCareCompletedAt,
    required this.waterCount,
    required this.nutrientCount,
    required this.pigFeedCount,
    required this.onWaterTap,
    required this.onNutrientTap,
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

  /// 현재 성장 단계 코드(rooting/leafing/branching/mature) — [treeStatus]와
  /// 무관하게 [_GrowthStageTree]가 idle-loop할 프레임 구간을 결정한다.
  final String growthStage;

  /// non-null이면 [growthStage] 직전 단계 — [_GrowthStageTree]가 그 구간 시작
  /// 지점부터 [growthStage] 구간 시작 지점까지 한 번 전진 재생한다.
  final String? growthStageAdvanceFrom;

  /// pigInfested 톤이어도 최근 12시간 안에 먹이를 줬으면 false — 나무 톤과
  /// 별개로 결정된다([_HomeScreenState._buildBody] 참고).
  final bool showPig;
  final DateTime? lastCareCompletedAt;
  final int? waterCount;
  final int? nutrientCount;
  final int? pigFeedCount;
  final VoidCallback onWaterTap;
  final VoidCallback onNutrientTap;
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
      // 기본값 topStart(좌상단)면 아래 non-positioned Column이 자기 콘텐츠 폭(가장 넓은
      // 자식 기준)으로 shrink-wrap된 채 왼쪽에 붙어버려 나무가 화면 중앙이 아니라
      // 왼쪽으로 치우쳐 보인다 — Column의 cross-axis(가로)는 stretch가 아닌 한 부모가
      // 준 loose 제약을 다 채우지 않는다. topCenter로 지정해 나무를 포함한 콘텐츠를
      // 화면 가로 중앙에 오게 한다. Positioned로 배치된 케어 버튼/하단 카드는 이
      // alignment와 무관하게 기존 좌표 그대로 유지된다.
      alignment: Alignment.topCenter,
      children: [
        Column(
          children: [
            const SizedBox(height: 12),
            // "나의 무화과" 정보 카드 — 원래는 화면 최하단에 Positioned(bottom:14)로
            // 고정돼 있었으나, 나무가 2배로 커지면서 방치(pigInfested) 상태에서 나무
            // 아래로 등장하는 돼지가 이 카드에 가려 거의 안 보이는 문제가 있었다. 카드를
            // 최상단(배너보다도 위)으로 옮기고 하단을 완전히 비워 돼지가 가려지지 않게
            // 했다. Positioned(left:16, right:16)이 주던 좌우 인셋/전체 폭 채우기를
            // Column 자식이 된 뒤에도 재현하기 위해 margin과 width를 명시한다 — 제목
            // Row의 Expanded가 우연히 폭을 채워주는 데 기대지 않는다.
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                      Expanded(
                        child: Text(
                          '나의 무화과 #${seedling.id} 🌱',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title(),
                        ),
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
            const SizedBox(height: 12),
            // Visibility(maintainSize: true)로 배너가 없는 healthy 상태에서도
            // 항상 같은 높이를 예약한다 — 예전엔 if/else로 healthy일 때만 배너
            // Container 자체를 렌더링하지 않아 그만큼 높이가 줄어, 아래 나무가
            // 상태에 따라 다른 Y 위치에 그려지는 문제가 있었다(로컬 Stack으로
            // 나무를 감싼 것과는 무관 — 그 Stack은 나무 하나만으로 크기가
            // 정해져 자체적으로는 위치를 바꾸지 않는다). 나무 위치를 항상
            // healthy 상태 기준으로 고정하기 위한 조치.
            Visibility(
              visible: treeStatus != TreeStatus.healthy,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Container(
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
                  showPig ? '6일이나 지났어요... 돼지가 찾아왔어요 🐷' : '3일 동안 자리를 비웠더니...',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.badgePinkText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              // 로컬 Stack의 폭(380)은 화면보다 좁아 기본 Clip.hardEdge를 쓰면
              // 돼지의 등장/퇴장 슬라이드(화면 밖 → 중앙, screenWidth 기준)가 이
              // 경계에서 잘린다 — 바깥 화면폭 Stack(alignment: topCenter)은 이미
              // 화면과 폭이 같아 문제없었지만 이 로컬 Stack은 명시적으로 풀어줘야 한다.
              clipBehavior: Clip.none,
              children: [
                // Transform.translate는 페인트 단계에서만 그림을 옮길 뿐 레이아웃
                // 크기/위치는 그대로라서, 이 Stack의 크기(=나무의 원래 380×482.6
                // 레이아웃 박스)와 그 아래 SizedBox(8)/Spacer 등 Column 흐름에는
                // 전혀 영향이 없다 — 나무만 시각적으로 50px 위로 옮겨지고, 아래
                // Positioned 돼지는 여전히 이 Stack의 원래 박스 기준으로 배치되어
                // 제자리(밑동 밴드)에 남는다.
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: _GrowAnimatedTree(
                    width: 380,
                    status: treeStatus,
                    playAnimation: playGrowAnimation,
                    onAnimationConsumed: onGrowAnimationConsumed,
                    growthStage: growthStage,
                    growthStageAdvanceFrom: growthStageAdvanceFrom,
                  ),
                ),
                // 돼지를 Column 흐름이 아니라 나무 위에 겹치는 오버레이로 배치 —
                // 예전엔 이 블록이 Column의 세로 흐름에 그대로 더해져(말풍선+돼지
                // 106px) 방치 상태에서 하단 오버플로가 났었다. Positioned로 빼면
                // 이 Stack의 크기는 여전히 비-Positioned 자식인 나무(380×482.6)
                // 하나로만 결정되어 Column 총 높이가 healthy 상태와 동일하게
                // 유지된다.
                if (showPig || isPigExiting)
                  Positioned(
                    left: 0,
                    right: 0,
                    // 나무 밑동 근처(전체 높이 482.6의 하단 1/5≈96.5px 밴드) 안에서
                    // 쉬는 기준점. [_LottiePigState]의 배회 오프셋(dy)이 이 값을
                    // 0점으로 삼아 밴드 안을 오르내리므로, 두 상수가 어긋나지
                    // 않도록 [_LottiePig.baseBottomOffset]을 그대로 쓴다.
                    bottom: _LottiePig.baseBottomOffset,
                    child: Center(
                      child: _LottiePig(
                        showPig: showPig,
                        isPigExiting: isPigExiting,
                        exitDirectionLeft: exitDirectionLeft,
                        onPigTap: onPigTap,
                        onPigExitAnimationEnd: onPigExitAnimationEnd,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Spacer(),
          ],
        ),
        Positioned(
          right: 14,
          top: 206,
          child: Column(
            children: [
              CareActionButton(
                emoji: '💧',
                label: '물주기',
                count: waterCount,
                onTap: onWaterTap,
              ),
              const SizedBox(height: 16),
              CareActionButton(
                emoji: '🍃',
                label: '영양제',
                count: nutrientCount,
                onTap: onNutrientTap,
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
      ],
    );
  }
}

/// [FigTreeIllustration] 자리에 들어가 "좋아지는 전환" 순간에만
/// `tree_growing.json`을 한 번 재생한 뒤(회복 flourish), 평상시에는
/// [status]에 맞는 에셋(healthy=`tree_growing.json`, wilted/pigInfested=
/// `tree_wilted.json`)으로 [_GrowthStageTree]를 그리는 위젯(Lottie 도입 시범
/// 적용, 12번 브랜치에서 시작해 이후 wilted 톤까지 확장). [playAnimation]은 이
/// 위젯이 처음 build될 때만 확인한다 — 이후 재생 중에 [status]가 바뀌어도(예:
/// 케어 게이지 조작) 재생을 중단하지 않는다.
class _GrowAnimatedTree extends StatefulWidget {
  const _GrowAnimatedTree({
    required this.width,
    required this.status,
    required this.playAnimation,
    required this.onAnimationConsumed,
    required this.growthStage,
    required this.growthStageAdvanceFrom,
  });

  final double width;
  final TreeStatus status;
  final bool playAnimation;
  final VoidCallback onAnimationConsumed;

  /// 회복 flourish("좋아지는 전환")와 별개인 성장 단계 신호 — [status]와 무관하게
  /// 항상 [_GrowthStageTree]로 전달된다(어느 상태든 같은 프레임 구간을 쓰므로).
  /// flourish 재생 중에는 쓰이지 않는다.
  final String growthStage;
  final String? growthStageAdvanceFrom;

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
      return _GrowthStageTree(
        width: widget.width,
        status: widget.status,
        stage: widget.growthStage,
        advanceFrom: widget.growthStageAdvanceFrom,
      );
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
          return FigTreeIllustration(
            width: widget.width,
            status: widget.status,
          );
        },
      ),
    );
  }
}

/// 무화과 성장 단계(rooting/leafing/branching/mature)에 맞는 프레임 구간을
/// idle-loop 재생하고, 단계가 진행되면([advanceFrom] non-null) 이전 구간 시작
/// 지점부터 새 구간 시작 지점까지 순방향으로 한 번 재생한 뒤 다시 idle로
/// 돌아간다. 프레임 구간/idle 로직 자체는 [status]와 무관하게 동일하게
/// 적용되고, [status]는 오직 어느 에셋을 재생할지만 결정한다([_assetPath]
/// 참고) — healthy는 `tree_growing.json`, wilted/pigInfested는 같은 프레임
/// 구성을 시든 색으로 리스킨한 `tree_wilted.json`을 쓴다. 두 상태
/// 모두 같은 파일을 쓰므로 나무 톤만으로는 wilted/pigInfested를 구분할 수
/// 없는데, 이 구분은 여전히 [_LottiePig] 오버레이(pigInfested일 때만 등장)가
/// 담당한다([_SeedlingHome] 참고) — 이 위젯 자체는 관여하지 않는다.
///
/// `AdopterShell`이 `IndexedStack`으로 홈 탭을 계속 마운트 상태로 유지하는 탓에,
/// 다른 탭에 있다가 홈 탭으로 돌아올 때([RevalidatableState.revalidate]가 호출하는
/// 조회 경로)는 이 위젯이 새로 마운트되지 않고 [didUpdateWidget]만 호출된다 — 재배자가
/// 새 일지를 남기는 시점은 대부분 입양자가 홈 탭을 보고 있지 않을 때이므로, 실제
/// 사용에서 "단계 진행"은 거의 항상 이 경로로 감지된다. 따라서 [didUpdateWidget]
/// 오버라이드가 장식이 아니라 이 기능이 동작하기 위한 필수 조건이다. 같은 이유로
/// [status] 전환(예: 3일 경과로 healthy→wilted) 역시 새로 마운트되지 않고
/// [didUpdateWidget]에서 에셋 경로 변경으로 감지된다.
class _GrowthStageTree extends StatefulWidget {
  const _GrowthStageTree({
    required this.width,
    required this.status,
    required this.stage,
    required this.advanceFrom,
  });

  final double width;

  /// 재생할 에셋만 결정한다([_assetPath] 참고) — 프레임 구간/idle 로직에는
  /// 영향을 주지 않는다.
  final TreeStatus status;
  final String stage;
  final String? advanceFrom;

  @override
  State<_GrowthStageTree> createState() => _GrowthStageTreeState();
}

class _GrowthStageTreeState extends State<_GrowthStageTree>
    with SingleTickerProviderStateMixin {
  /// tree_growing.json 확인된 사양: fr(frameRate)=60 — 전진 재생 시간(초)을 프레임
  /// 수로부터 역산할 때만 쓴다. progress(0.0~1.0) 계산은 [_composition]의 실제
  /// startFrame/endFrame을 쓰므로 총 프레임 수(1200)를 따로 하드코딩하지 않는다
  /// (에셋이 나중에 다른 길이로 재수출돼도 안전).
  static const _frameRate = 60.0;

  static const _frameRanges = <String, (int, int)>{
    'rooting': (400, 600),
    'leafing': (600, 800),
    'branching': (800, 1000),
    'mature': (1000, 1200),
  };

  late final AnimationController _controller;
  LottieComposition? _composition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _GrowthStageTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_composition == null) return; // 아직 로드 전 — onLoaded가 최신 값을 읽는다.
    if (widget.status != oldWidget.status) {
      // 에셋 경로가 바뀌어 Lottie가 새 composition을 다시 로드한다(lottie
      // 패키지의 LottieBuilder가 provider 변경을 감지해 자동으로 재요청) —
      // 재적용은 build()의 onLoaded가 최신 widget.stage/advanceFrom으로
      // 처리하므로 여기서 별도로 호출할 필요가 없다. 두 에셋이 프레임
      // 구성(ip/op/fr)까지 동일해 재생 위치가 끊기지 않는다.
      return;
    }
    if (widget.advanceFrom != oldWidget.advanceFrom) {
      _applyStage(stage: widget.stage, advanceFrom: widget.advanceFrom);
    }
  }

  /// healthy면 원본 성장 애니메이션, wilted/pigInfested면 동일한 프레임
  /// 구성을 시든 색으로 리스킨한 파일을 고른다.
  String get _assetPath => widget.status == TreeStatus.healthy
      ? 'assets/lottie/tree_growing.json'
      : 'assets/lottie/tree_wilted.json';

  /// 알 수 없는 단계 코드(백엔드에 나중에 choice가 추가되는 등)가 들어오면 'rooting'
  /// 구간으로 방어적 폴백한다.
  (int, int) _rangeFor(String stage) =>
      _frameRanges[stage] ?? _frameRanges['rooting']!;

  double _progress(int frame) {
    final c = _composition!;
    // lottie 패키지는 endFrame을 op - 0.01로 파싱한다(LottieCompositionParser) —
    // 그 결과 frame이 op와 정확히 같은 마지막 구간(mature: 1000~1200)에서는
    // raw가 1.0을 미세하게 초과해 AnimationController.repeat()의
    // `max <= upperBound` assert를 위반한다. clamp로 진짜 마지막 지점(1.0)에
    // 정확히 맞춘다.
    final raw = (frame - c.startFrame) / (c.endFrame - c.startFrame);
    return raw.clamp(0.0, 1.0);
  }

  Duration _durationForFrames(int frames) =>
      Duration(milliseconds: (frames / _frameRate * 1000).round());

  void _idleAt(String stage) {
    final (start, end) = _rangeFor(stage);
    // 정방향 단순 반복은 구간 경계마다 시작 지점으로 순간 이동하는 "튐"이 생길 수
    // 있다 — tree_growing.json은 seamless 루프로 제작된 에셋이 아니라서, 항상 현재
    // 위치에서 이어 재생되는 핑퐁(reverse: true)이 더 안전하다.
    _controller.repeat(
      min: _progress(start),
      max: _progress(end),
      reverse: true,
      period: _durationForFrames(end - start),
    );
  }

  Future<void> _applyStage({required String stage, String? advanceFrom}) async {
    if (advanceFrom == null || !_frameRanges.containsKey(advanceFrom)) {
      _idleAt(stage);
      return;
    }
    final (fromStart, _) = _rangeFor(advanceFrom);
    final (toStart, _) = _rangeFor(stage);
    _controller.value = _progress(fromStart);
    await _controller.animateTo(
      _progress(toStart),
      duration: _durationForFrames(toStart - fromStart),
    );
    if (!mounted) return;
    _idleAt(stage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.width * 1.27,
      child: Lottie.asset(
        _assetPath,
        controller: _controller,
        fit: BoxFit.contain,
        onLoaded: (composition) {
          _composition = composition;
          _applyStage(stage: widget.stage, advanceFrom: widget.advanceFrom);
        },
        errorBuilder: (context, error, stackTrace) {
          return FigTreeIllustration(width: widget.width, status: widget.status);
        },
      ),
    );
  }
}

/// 돼지 등장/배회/탭 리액션/퇴장을 관리하는 위젯 — `pig.json`(제자리 씰룩 반복)을
/// `Transform.translate`/`Transform.scale`로 감싸 위치·크기 변화를 얹는다
/// (Lottie는 "제자리 애니메이션"만 담당, 위치/크기는 Flutter `AnimationController`가 담당).
enum _PigPhase { entering, idle, exiting }

class _LottiePig extends StatefulWidget {
  const _LottiePig({
    required this.showPig,
    required this.isPigExiting,
    required this.exitDirectionLeft,
    required this.onPigTap,
    required this.onPigExitAnimationEnd,
  });

  /// 호출부(_SeedlingHome)의 바깥 Positioned가 쓰는 bottom 기준값이자,
  /// [_LottiePigState]의 배회 밴드 계산에서 dy=0에 해당하는 쉬는 지점.
  /// 두 곳이 각자 상수를 들고 있으면 어긋날 수 있어 하나로 공유한다.
  static const double baseBottomOffset = 20.0;

  // 호출부(_SeedlingHome)의 기존 파라미터 구성을 그대로 유지하기 위해 받지만,
  // 등장 시점은 항상 이 위젯이 새로 mount되는 순간과 일치해(부모가 showPig ||
  // isPigExiting일 때만 트리에 넣음) 내부 로직에서는 쓰이지 않는다.
  final bool showPig;
  final bool isPigExiting;
  final bool exitDirectionLeft;
  final VoidCallback onPigTap;
  final VoidCallback onPigExitAnimationEnd;

  @override
  State<_LottiePig> createState() => _LottiePigState();
}

class _LottiePigState extends State<_LottiePig> with TickerProviderStateMixin {
  late final AnimationController _hopController;
  late final AnimationController _wanderController;
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;

  final _random = Random();
  _PigPhase _phase = _PigPhase.entering;
  bool _entryFromLeft = true;
  bool _isReacting = false;
  bool _exitEndCalled = false;
  Offset _wanderFrom = Offset.zero;
  Offset _wanderTarget = Offset.zero;

  /// 5초마다 한 번, 2초 동안만 말풍선을 보여준다([_scheduleBubble] 참고). idle
  /// 상태일 때만 순환하고, 등장/퇴장 중에는 항상 false.
  bool _bubbleVisible = false;

  @override
  void initState() {
    super.initState();
    _entryFromLeft = _random.nextBool();
    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _wanderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.85,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_tapController);

    if (widget.isPigExiting) {
      // 방어적 예외: 첫 build부터 이미 퇴장 중이면 등장을 건너뛰고 곧장 퇴장한다.
      _phase = _PigPhase.idle;
      _startExit();
    } else {
      _phase = _PigPhase.entering;
      _runEntrance();
    }
  }

  @override
  void didUpdateWidget(covariant _LottiePig oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isPigExiting &&
        widget.isPigExiting &&
        _phase != _PigPhase.exiting) {
      _startExit();
    }
  }

  /// 등장/퇴장 공용 "통통 튐" 오프셋. 수평은 [curve]로 단조 이동하고, 수직은
  /// 감쇠하는 사인파(`sin(3πt)`, 3구간)로 2~3번 바운스하는 느낌을 낸다.
  Offset _hopOffset({
    required double fromX,
    required double toX,
    required Curve curve,
  }) {
    final t = _hopController.value;
    final dx = fromX + (toX - fromX) * curve.transform(t);
    const bounceHeight = 18.0;
    final envelope = 1 - t;
    final dy = -bounceHeight * envelope * sin(3 * pi * t).abs();
    return Offset(dx, dy);
  }

  Future<void> _runEntrance() async {
    await _hopController.forward(from: 0);
    if (!mounted || _phase != _PigPhase.entering) return;
    setState(() => _phase = _PigPhase.idle);
    _scheduleWander();
    _scheduleBubble();
  }

  Future<void> _startExit() async {
    if (_phase == _PigPhase.exiting) return;
    _wanderController.stop();
    _hopController.stop();
    setState(() {
      _phase = _PigPhase.exiting;
      _wanderFrom = Offset.zero;
      _wanderTarget = Offset.zero;
      _bubbleVisible = false;
    });
    await _hopController.forward(from: 0);
    if (!mounted || _exitEndCalled) return;
    _exitEndCalled = true;
    widget.onPigExitAnimationEnd();
  }

  /// 좌우 배회 폭(중심 기준 ±100px) — 나무 폭(380px) 안에서 밑동을 벗어나지
  /// 않는 선에서 훨씬 넓게 움직이도록 기존 ±20px → ±70px → ±100px로 확장했다.
  static const double _wanderRangeX = 100.0;

  /// 세로 배회 밴드 — 나무 줄기 하단 1/5 구간(전체 높이 482.6 × 0.2 ≈ 96.5px)
  /// 안에서만 움직이도록, [_LottiePig.baseBottomOffset](20)을 기준(dy=0)으로
  /// 한 bottom 값의 허용 범위를 [ _wanderBandMin, _wanderBandMax ]로 둔다 —
  /// 밴드의 정확한 양 끝(0, 96.5)까지 쓰지 않고 위아래로 약간의 여유를 남긴다.
  /// 위쪽 한계(bandMax)는 20px 줄이고 아래쪽 한계(bandMin)는 20px 늘려, 중심
  /// (구간 중앙값 47)은 그대로 두고 범위만 위아래로 20px씩 좁혔다.
  static const double _wanderBandMin = 26.0;
  static const double _wanderBandMax = 68.0;

  /// 3~5초 간격으로 나무 밑동 하단 밴드 안(좌우 ±100px, 상하 [_wanderBandMin]~
  /// [_wanderBandMax])에서 랜덤하게 배회한다. `mounted`/`_phase` 체크로 퇴장
  /// 시작 시 스스로 멈춘다.
  Future<void> _scheduleWander() async {
    while (mounted && _phase == _PigPhase.idle) {
      final waitMs = 3000 + _random.nextInt(2000);
      await Future.delayed(Duration(milliseconds: waitMs));
      if (!mounted || _phase != _PigPhase.idle) return;
      _wanderFrom = _wanderTarget;
      final targetBottom =
          _wanderBandMin +
          _random.nextDouble() * (_wanderBandMax - _wanderBandMin);
      _wanderTarget = Offset(
        (_random.nextDouble() * (_wanderRangeX * 2)) - _wanderRangeX,
        // Transform.translate의 dy는 양수일 때 아래로 이동하므로, "밴드 안의
        // 목표 bottom"을 얻으려면 기준 bottom에서 뺀 값을 써야 한다.
        _LottiePig.baseBottomOffset - targetBottom,
      );
      await _wanderController.forward(from: 0);
      if (!mounted || _phase != _PigPhase.idle) return;
    }
  }

  /// 5초마다 한 번, 2초 동안만 말풍선을 노출한다. [_scheduleWander]와 동일한
  /// async-while 패턴 — idle 상태가 아니게 되면(퇴장 시작 등) 스스로 멈춘다.
  Future<void> _scheduleBubble() async {
    while (mounted && _phase == _PigPhase.idle) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || _phase != _PigPhase.idle) return;
      setState(() => _bubbleVisible = true);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _phase != _PigPhase.idle) return;
      setState(() => _bubbleVisible = false);
    }
  }

  void _handleTap() {
    if (_phase != _PigPhase.idle || _isReacting) return;
    _isReacting = true;
    _tapController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _isReacting = false;
      widget.onPigTap();
    });
  }

  @override
  void dispose() {
    _hopController.stop();
    _wanderController.stop();
    _tapController.stop();
    _hopController.dispose();
    _wanderController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _hopController,
          _wanderController,
          _tapController,
        ]),
        builder: (context, child) {
          final positionOffset = switch (_phase) {
            _PigPhase.entering => _hopOffset(
              fromX: _entryFromLeft ? -screenWidth : screenWidth,
              toX: 0,
              curve: Curves.easeOut,
            ),
            _PigPhase.exiting => _hopOffset(
              fromX: 0,
              toX: widget.exitDirectionLeft ? -screenWidth : screenWidth,
              curve: Curves.easeIn,
            ),
            _PigPhase.idle => Offset.lerp(
              _wanderFrom,
              _wanderTarget,
              Curves.easeInOut.transform(_wanderController.value),
            )!,
          };
          return Transform.translate(
            offset: positionOffset,
            // 말풍선을 돼지와 같은 Transform 아래 두어 배회 중에도 돼지 머리
            // 위에 항상 붙어 함께 움직이게 한다(예전엔 말풍선이 이 Transform
            // 밖에 있어 돼지가 배회해도 제자리에 머무는 문제가 있었다).
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  opacity: _bubbleVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  // 말풍선이 보이지 않을 때도(opacity 0) 레이아웃 공간은
                  // 차지하므로, GestureDetector가 이 트리 전체를 감싸는 상황에서
                  // 우발적으로 탭 히트 영역에 들어가지 않게 막는다 — 기존처럼
                  // "돼지 180×180만 탭 가능"을 유지.
                  child: const IgnorePointer(
                    child: SpeechBubble(text: '꿀꿀~ 내가 왔다!'),
                  ),
                ),
                Transform.scale(scale: _tapScale.value, child: child),
              ],
            ),
          );
        },
        // 기존 60×60 대비 3배 확대 — 나무 대비 존재감을 키우기 위한 요청.
        child: SizedBox(
          width: 180,
          height: 180,
          child: Lottie.asset(
            'assets/lottie/pig.json',
            repeat: true,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const PigCharacter(width: 180),
          ),
        ),
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
