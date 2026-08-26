import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/diary_repository.dart';
import '../data/grower_repository.dart';
import 'grower_seedling_analysis_screen.dart';

/// 담당 묘목 한 그루 + 가장 최근 일지의 성장 단계(코드값 + 한글 라벨, 둘 다 없으면 null).
class _ShelfEntry {
  const _ShelfEntry({
    required this.seedling,
    this.growthStage,
    this.growthStageLabel,
  });

  final Seedling seedling;

  /// 가장 최근 일지의 성장 단계 코드값(rooting/leafing/branching/mature). 필터 버튼이
  /// 이 값을 기준으로 걸러낸다.
  final String? growthStage;
  final String? growthStageLabel;
}

/// 선반 상단 필터 버튼 4개. "전체"만 [growthStageCode]가 null이라 모든 묘목을 통과시키고,
/// 나머지 세 개는 가장 최근 일지의 [_ShelfEntry.growthStage]와 정확히 일치하는 묘목만
/// 남긴다 — mature(완료) 단계 묘목은 이 세 필터 중 어느 것에도 매칭되지 않고 "전체"에만
/// 포함된다(요구사항: 개별 필터 탭 없음).
enum _ShelfFilter {
  all('전체', null),
  rooting('발근중', 'rooting'),
  leafing('잎성장', 'leafing'),
  branching('가지발달', 'branching');

  const _ShelfFilter(this.label, this.growthStageCode);

  final String label;
  final String? growthStageCode;
}

/// [entries]를 [size]개씩 순서대로 잘라 "단(tier)" 목록으로 만든다. 마지막 단은
/// [size]개보다 적어도(예: size=2일 때 5개 → 2+2+1) 그대로 둔다 — 억지로 채우지 않는다.
List<List<_ShelfEntry>> _chunkIntoTiers(List<_ShelfEntry> entries, int size) {
  final tiers = <List<_ShelfEntry>>[];
  for (var i = 0; i < entries.length; i += size) {
    final end = (i + size < entries.length) ? i + size : entries.length;
    tiers.add(entries.sublist(i, end));
  }
  return tiers;
}

/// "홈" 탭: 담당 묘목을 "N단 선반"(한 단에 2개씩) 단위로 세로로 쌓아 보여주는 선반 뷰.
/// 각 단은 참고 React 목업의 렌더링 순서(단 헤더 → 브라켓+쿨링팬 로우+LED 3단 후드 →
/// 은은한 하향 글로우 → 화분 2개 → 선반 받침대)를 그대로 옮긴 `_ShelfTier`다. 쿨링팬
/// 아이콘/텍스트나 온습도 수치처럼 실제 데이터가 없는 부분은 장식(정적)으로만
/// 표현한다 — 실제 재배 데이터는 화분번호/성장단계 배지뿐이다(입양자 정보는 화분 카드가
/// 좁아 제거했다). 카드를 탭하면 묘목 분석 화면(`/grower/seedling-analysis`, 현재는
/// 최소 뼈대)으로 이동하는 로직은 그대로다. 헤더 아래에는 성장 단계 필터 버튼 4개
/// (전체/발근중/잎성장/가지발달, `_ShelfFilterBar`)가 있어 가장 최근 일지의 성장 단계
/// 기준으로 화분을 걸러볼 수 있다.
class GrowerShelfScreen extends StatefulWidget {
  const GrowerShelfScreen({super.key});

  @override
  State<GrowerShelfScreen> createState() => _GrowerShelfScreenState();
}

class _GrowerShelfScreenState extends RevalidatableState<GrowerShelfScreen> {
  final _seedlingRepository = GrowerRepository();
  final _diaryRepository = DiaryRepository();

  bool _loading = true;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  List<_ShelfEntry> _entries = const [];
  _ShelfFilter _selectedFilter = _ShelfFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 담당 묘목 전체를 조회한 뒤, 묘목마다 일지 목록을 병렬로 조회해 가장 최근 일지의
  /// 성장 단계를 묶는다 — `grower_anomaly_summary_screen.dart`가 이상 감지 이력을 묘목별로
  /// 병렬 조회하는 것과 동일한 패턴이다. 백엔드 응답 순서는 보장되지 않으므로(
  /// `growth_timeline_screen.dart`가 같은 이유로 클라이언트에서 재정렬하는 것과 동일하게)
  /// `created_at` 내림차순으로 직접 정렬한 뒤 첫 번째 항목을 최신 일지로 쓴다 — 응답을
  /// 그대로 믿고 `.first`를 썼다가 실제로는 삽입 순서(오래된 것부터)가 그대로 나와 필터
  /// 배지가 옛 성장 단계로 표시되는 문제를 실제로 확인했다.
  Future<List<_ShelfEntry>> _fetchData() async {
    final seedlings = await _seedlingRepository.fetchSeedlings();
    final diaries = await Future.wait(
      seedlings.map((s) => _diaryRepository.fetchDiaries(s.id)),
    );
    return [
      for (var i = 0; i < seedlings.length; i++)
        _ShelfEntry(
          seedling: seedlings[i],
          growthStage: _latestDiary(diaries[i])?.growthStage,
          growthStageLabel: _latestDiary(diaries[i])?.growthStageLabel,
        ),
    ];
  }

  DiaryEntry? _latestDiary(List<DiaryEntry> diaries) {
    if (diaries.isEmpty) return null;
    return diaries.reduce(
      (latest, entry) => entry.createdAt.isAfter(latest.createdAt) ? entry : latest,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final entries = await _fetchData();
      setState(() => _entries = entries);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
      _hasLoadedOnce = true;
    }
  }

  /// `GrowerShell`이 홈 탭 재진입 시 호출한다. 일지/환경점검 탭에 다녀오는 동안 성장
  /// 단계가 바뀌었을 수 있으니 다시 불러오되, 기존 목록은 그대로 둔 채 응답이 오면
  /// 조용히 교체한다.
  @override
  Future<void> revalidate() async {
    if (!_hasLoadedOnce) return _load();
    try {
      final entries = await _fetchData();
      if (mounted) setState(() => _entries = entries);
    } on ApiException {
      // 재조회 실패 시 기존 목록을 그대로 유지한다.
    }
  }

  void _openAnalysis(Seedling seedling) {
    Navigator.of(context).pushNamed(
      '/grower/seedling-analysis',
      arguments: GrowerSeedlingAnalysisArgs(
        seedlingId: seedling.id,
        adopterId: seedling.adopterId,
        status: seedling.status,
        adopterIsActive: seedling.adopterIsActive,
        adopterNickname: seedling.adopterNickname,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: _buildBody(),
      ),
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
    if (_entries.isEmpty) {
      return const _EmptyState();
    }

    final filteredEntries = _selectedFilter.growthStageCode == null
        ? _entries
        : _entries
              .where((e) => e.growthStage == _selectedFilter.growthStageCode)
              .toList();
    // 필터 결과가 0개여도 목록 자체를 감추지 않고, 화분 없는 빈 선반 틀 1단만
    // 보여준다(요구사항) — `_chunkIntoTiers`는 빈 리스트를 넣으면 단 자체가 0개가 되어
    // 아무것도 안 보이므로, 이 경우만 빈 단 하나를 직접 만든다.
    final tiers = filteredEntries.isEmpty
        ? const [<_ShelfEntry>[]]
        : _chunkIntoTiers(filteredEntries, 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🪴 스마트 재배 선반',
          style: AppTextStyles.title(
            fontSize: 20,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          '화분을 눌러 분석 정보를 확인하세요',
          style: AppTextStyles.guide(
            fontSize: 14,
            color: AppColors.badgeGreenText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '오늘도 무화과들이 무럭무럭 자라고 있어요 🌿',
          style: AppTextStyles.caption(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _ShelfFilterBar(
          selected: _selectedFilter,
          onSelected: (filter) => setState(() => _selectedFilter = filter),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: tiers.length,
              itemBuilder: (context, index) => _ShelfTier(
                tierNumber: index + 1,
                entries: tiers[index],
                onTapSeedling: _openAnalysis,
                isLast: index == tiers.length - 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 필터 버튼 4개("전체"/"발근중"/"잎성장"/"가지발달")를 한 줄(Row)에 균등하게 배치한다.
/// `Expanded`로 4개가 폭을 나눠 가지므로 화면 폭이 좁아도 다음 줄로 밀리지 않는다 —
/// pill 안 텍스트도 여유 없이 딱 맞는 폭이라 `FittedBox(scale down)`로 "가지발달"처럼
/// 긴 라벨도 필요하면 글자를 살짝 줄여서 한 줄 안에 유지한다.
class _ShelfFilterBar extends StatelessWidget {
  const _ShelfFilterBar({required this.selected, required this.onSelected});

  final _ShelfFilter selected;
  final ValueChanged<_ShelfFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final filter in _ShelfFilter.values) ...[
          if (filter != _ShelfFilter.values.first) const SizedBox(width: 6),
          Expanded(
            child: _ShelfFilterChip(
              filter: filter,
              isSelected: filter == selected,
              onTap: () => onSelected(filter),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShelfFilterChip extends StatelessWidget {
  const _ShelfFilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final _ShelfFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pink500 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.pink500 : AppColors.outline,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            filter.label,
            maxLines: 1,
            style: AppTextStyles.caption(
              fontSize: 12,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// 선반 한 "단(tier)" 전체. 참고 React 목업의 `tiersInfo.map()` 렌더링 순서를 그대로
/// 위젯 트리 계층으로 옮겼다 — 1) 단 헤더 바, 2) 오버헤드 후드(브라켓 → 쿨링팬 로우 →
/// LED, 3단 바가 틈 없이 붙어 쌓임 — 팬 아이콘/텍스트만 제외하고 바 자체는 포함),
/// 3) 하향 앰비언트 글로우, 4) 화분 최대 2개(Row), 5) 선반 받침대. 이 5단계를 감싸는
/// 하나의 카드 프레임 안에 순서대로 쌓는다.
class _ShelfTier extends StatelessWidget {
  const _ShelfTier({
    required this.tierNumber,
    required this.entries,
    required this.onTapSeedling,
    required this.isLast,
  });

  final int tierNumber;
  final List<_ShelfEntry> entries;
  final ValueChanged<Seedling> onTapSeedling;
  final bool isLast;

  /// 선반 널빤지 톤 — [AppColors.beigeBg](Scaffold 배경)보다 살짝 짙은 웜톤이라야
  /// 화면 배경과 선반 프레임이 구분되어 보인다. 이 화면 전용 일회성 색상이라 인라인으로 둔다.
  static const _surfaceColor = Color(0xFFF2ECD9);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: [
            // 1) Tier Info Header Bar
            _TierHeaderBar(tierNumber: tierNumber),
            const SizedBox(height: 10),
            // 2) Overhead Hood: Metallic Bracket → Cooling Fan Row → Linear LED
            //    Grow Light — 세 바는 원본처럼 틈 없이 붙여 쌓는다.
            const _BracketBar(),
            const _FanRowBar(),
            const _LedGrowBar(),
            // 3) Ambient Downward Light Glow
            const _AmbientGlow(),
            const SizedBox(height: 4),
            // 4) Pots on the Shelf
            _PotsRow(entries: entries, onTapSeedling: onTapSeedling),
            const SizedBox(height: 10),
            // 5) Shelf Base Rail
            const _ShelfBaseRail(),
          ],
        ),
      ),
    );
  }
}

/// 1) 단 제목("N단 선반") + 우측 "스마트 생육 LED" 라벨.
class _TierHeaderBar extends StatelessWidget {
  const _TierHeaderBar({required this.tierNumber});

  final int tierNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$tierNumber단 선반',
          style: AppTextStyles.title(
            fontSize: 14,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.badgeGreenBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '스마트 생육 LED',
            style: AppTextStyles.caption(
              fontSize: 10,
              color: AppColors.badgeGreenText,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// 오버헤드 후드의 금속 브라켓 — 어두운 얇은 바 "안에" 볼트 점 2개를 `Row(spaceBetween)`로
/// 배치한다(참고 React가 점을 별도 오버레이가 아니라 바 자체의 flex 자식으로 넣는 것과
/// 동일 구조). 색은 [AppColors]에 마땅한 회색 톤이 없어(가장 가까운 textPrimary는
/// 검정에 가까운 웜톤이라 "금속 브라켓"보다는 어두운 나무 톤으로 읽힘) 화면 전용
/// 인라인 상수로 진한 은색/메탈 톤을 추가했다.
class _BracketBar extends StatelessWidget {
  const _BracketBar();

  static const _metalColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: _metalColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(2),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_BoltDot(), _BoltDot()],
      ),
    );
  }
}

/// 브라켓 바 안의 작은 점 장식 — 받침대의 [_Bolt](테두리 있는 원)와 달리 테두리 없는
/// 얇은 사각 점(참고 React가 실제로 그렇게 그려서 그대로 따른다).
class _BoltDot extends StatelessWidget {
  const _BoltDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 2,
      decoration: BoxDecoration(
        color: AppColors.dotInactive,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// 브라켓/받침대 양끝의 볼트(리벳) 점 장식 — [_ShelfBaseRail]이 계속 쓴다.
class _Bolt extends StatelessWidget {
  const _Bolt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: AppColors.textMuted,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 1),
      ),
    );
  }
}

/// 쿨링팬 로우 — 참고 목업의 "Cooling Fans Row". 팬 아이콘/텍스트는 실제 데이터가
/// 없어 이번에도 제외하지만, 브라켓과 LED 사이에 층을 만드는 두꺼운 어두운 바 자체는
/// 그대로 살린다. [AppColors]에 2단계 어두운 중립색이 없어 이 화면 전용 인라인 상수
/// 2개를 추가했다 — 순수 회색(slate) 대신 브랜드 톤에 맞게 살짝 웜톤을 섞었다.
class _FanRowBar extends StatelessWidget {
  const _FanRowBar();

  static const _fanRowBg = Color(0xFF2B2724);
  static const _fanRowBorder = Color(0xFF1B1815);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: const BoxDecoration(
        color: _fanRowBg,
        border: Border(bottom: BorderSide(color: _fanRowBorder, width: 1)),
      ),
    );
  }
}

/// 오버헤드 후드의 선형 LED 그로우 라이트 — 참고 목업의 "Linear LED Grow Light"를
/// 단색 바 + box-shadow 글로우로 옮긴 것(그라데이션 아님). 색은 [AppColors.green500]
/// 고정 — "스마트 생육 LED"라는 이름과 어울리는 식물/생육 톤으로 사용자가 직접 확인했다.
class _LedGrowBar extends StatelessWidget {
  const _LedGrowBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.green500,
        boxShadow: [
          BoxShadow(
            color: AppColors.green500.withValues(alpha: 0.85),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

/// 3) LED 아래로 은은하게 퍼지는 하향 글로우 — 참고 목업의 "Ambient Downward Light
/// Glow"를 옮긴 것. 위(LED 톤)에서 아래(투명)로 옅어지는 그라데이션 한 장이며 실제
/// 조도 데이터와는 무관한 순수 장식이다.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.pink500.withValues(alpha: 0.12),
            AppColors.pink500.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// 4) 화분 최대 2개를 가로로 나란히 배치(한 단에 2개씩). 참고 목업의 "flex-1
/// max-w-[100px]"을 `Expanded` + `Center` + `ConstrainedBox(maxWidth: 120)`로 옮겼다 —
/// 폭은 화분/식물 1.2배 확대(`_ShelfPot`)에 맞춰 100→120으로 함께 키웠다. 화분이 2개보다
/// 적은 마지막 단도 억지로 채우지 않고 있는 개수만큼만 중앙에 고르게 배치된다. 필터 결과가
/// 0개면(entries가 빈 리스트) 화분 대신 "빈 화분 영역" 플레이스홀더를 보여준다.
class _PotsRow extends StatelessWidget {
  const _PotsRow({required this.entries, required this.onTapSeedling});

  final List<_ShelfEntry> entries;
  final ValueChanged<Seedling> onTapSeedling;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyPotArea();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: _ShelfPot(
                  entry: entry,
                  onTap: () => onTapSeedling(entry.seedling),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 필터 결과가 0개인 단의 "빈 화분 영역" — 화분이 놓일 자리를 점선풍 테두리 박스로
/// 비워두고 안내 문구만 보여준다. `_ShelfPot`의 전체 높이(잎 58 + 화분 몸통)와 얼추
/// 맞춘 고정 높이를 둬서, 필터를 바꿔도 선반 틀 자체의 높이가 크게 출렁이지 않는다.
class _EmptyPotArea extends StatelessWidget {
  const _EmptyPotArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Text(
        '해당 단계의 묘목이 없어요',
        style: AppTextStyles.caption(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

/// 화분 하나("RackPot" 포팅). 참고 React 원본의 DOM 순서를 그대로 따른다 — 잎사귀
/// (foliage)는 화분 몸통(pot body)의 형제이며 몸통보다 먼저 온다(몸통 "안"에 들어있지
/// 않다). 몸통 Container 자체가 카드 역할을 겸해 별도의 흰 카드는 없다. 음수 마진
/// (`-mt-2`/`-mt-0.5`, `w-[104%]`)은 레이아웃 크기에 영향 없는 `Transform.translate`/
/// `Transform.scale`로 옮겼다. 성장단계 배지는 원본에는 없지만 이 프로젝트에 필요한
/// 정보라 화분 톤을 깨지 않는 저채도 칩으로 몸통 하단에 추가했다(공용 [StatusBadge]는
/// 패딩/폰트가 이 120px 폭 카드엔 너무 커서 재사용하지 않았다).
class _ShelfPot extends StatelessWidget {
  const _ShelfPot({required this.entry, required this.onTap});

  final _ShelfEntry entry;
  final VoidCallback onTap;

  /// 화분 팔레트 — [AppColors]에 맞는 옅은 황갈색 톤이 없어 [AppColors.brown600]에서
  /// 파생한 화면 전용 상수(`Color.lerp`는 const 표현식이 아니라 미리 계산한 값을
  /// 하드코딩 — [FigTreeIllustration._wiltedBrown]/[_ShelfTier._surfaceColor]와 동일한
  /// 기존 관례).
  static const _potBody = Color(0xFFD3C2B5); // lerp(brown600, white, 0.62)
  static const _potBorder = Color(0xFFBCA28E); // lerp(brown600, white, 0.42)
  static const _potRim = Color(0xFFAE8E77); // lerp(brown600, white, 0.30)
  static const _potCodeText = Color(0xFF4B3320); // lerp(brown600, black, 0.46)

  @override
  Widget build(BuildContext context) {
    final seedling = entry.seedling;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Plant Foliage — 몸통의 형제, 몸통보다 먼저 온다(원본 DOM 순서 그대로).
          // 이하 치수는 전체적으로 기존 대비 1.2배 확대(요구사항)했다.
          SizedBox(
            height: 58,
            width: double.infinity,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 24, height: 1)),
                  Transform.translate(
                    offset: const Offset(0, -2.4),
                    child: Container(
                      width: 5,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.green800.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Potted Pot Body — 카드 역할까지 겸용.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(5, 7, 5, 5),
            decoration: BoxDecoration(
              color: _potBody,
              border: Border.all(color: _potBorder, width: 1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2.4),
                topRight: Radius.circular(2.4),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pot Rim — 몸통 위에 별도로 얹힌 것처럼 위로 살짝 겹친다.
                Transform.translate(
                  offset: const Offset(0, -9.6),
                  child: Transform.scale(
                    scaleX: 1.04,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: _potRim,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // 화분 몸통 "안"의 텍스트 — 묘목번호만(입양자 정보는 제거됨).
                Text(
                  '무화과 #${seedling.id}',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: _potCodeText,
                  ).copyWith(fontWeight: FontWeight.w900, height: 1),
                ),

                // 성장단계 배지 — 화분 톤에 맞춘 저채도 칩(원본 React엔 없는 항목).
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _potRim.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    entry.growthStageLabel ?? '–',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      fontSize: 10,
                      color: _potCodeText,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 5) 선반 받침대 — 참고 목업의 "Shelf Base Rail"을 회색 계열 그라데이션 바 + 좌우 볼트
/// 장식 + 중앙 가로선으로 옮긴 것. [AppColors.outline]/[AppColors.dotInactive] 토큰을
/// 그대로 재사용한다.
class _ShelfBaseRail extends StatelessWidget {
  const _ShelfBaseRail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(
                colors: [AppColors.outline, AppColors.dotInactive],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.black.withValues(alpha: 0.12),
          ),
          const Positioned(left: 4, child: _Bolt()),
          const Positioned(right: 4, child: _Bolt()),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FigTreeIllustration(width: 64),
          const SizedBox(height: 16),
          Text(
            '아직 담당하는 묘목이 없어요',
            style: AppTextStyles.body(
              fontSize: 15,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '묘목이 배정되면 여기에 표시돼요',
            style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
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
            Text('😢', style: const TextStyle(fontSize: 40)),
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
