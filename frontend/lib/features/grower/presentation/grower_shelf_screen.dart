import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/diary_repository.dart';
import '../data/grower_repository.dart';
import 'grower_seedling_analysis_screen.dart';

/// 담당 묘목 한 그루 + 가장 최근 일지의 성장 단계 라벨(없으면 null).
class _ShelfEntry {
  const _ShelfEntry({required this.seedling, this.growthStageLabel});

  final Seedling seedling;
  final String? growthStageLabel;
}

/// "홈" 탭: 담당 묘목을 화분 카드로 평평하게 나열하는 "선반 뷰". 그룹 섹션(단)·온습도·
/// FAN/LED 배지는 실제 기능이 없는 장식이라 제외했다(참고 디자인을 단순화). 카드를 탭하면
/// 묘목 분석 화면(`/grower/seedling-analysis`, 현재는 최소 뼈대)으로 이동한다.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 담당 묘목 전체를 조회한 뒤, 묘목마다 일지 목록을 병렬로 조회해 가장 최근 일지의
  /// 성장 단계를 묶는다 — `grower_anomaly_summary_screen.dart`가 이상 감지 이력을 묘목별로
  /// 병렬 조회하는 것과 동일한 패턴이다. `fetchDiaries()`는 이미 `created_at` 내림차순으로
  /// 정렬해 반환하므로 첫 번째 항목이 최신 일지다.
  Future<List<_ShelfEntry>> _fetchData() async {
    final seedlings = await _seedlingRepository.fetchSeedlings();
    final diaries = await Future.wait(
      seedlings.map((s) => _diaryRepository.fetchDiaries(s.id)),
    );
    return [
      for (var i = 0; i < seedlings.length; i++)
        _ShelfEntry(
          seedling: seedlings[i],
          growthStageLabel: diaries[i].isEmpty
              ? null
              : diaries[i].first.growthStageLabel,
        ),
    ];
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
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
        const SizedBox(height: 14),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return _ShelfCard(
                  entry: entry,
                  onTap: () => _openAnalysis(entry.seedling),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.entry, required this.onTap});

  final _ShelfEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final seedling = entry.seedling;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.badgeGreenBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const FigTreeIllustration(width: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '무화과 #${seedling.id}',
                    style: AppTextStyles.title(
                      fontSize: 15,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '입양자 #${seedling.adopterId}',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            entry.growthStageLabel != null
                ? StatusBadge(
                    label: entry.growthStageLabel!,
                    background: AppColors.green500,
                    pill: false,
                  )
                : Text(
                    '성장 기록 없음',
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: const Color(0xFFB7B2A4),
                    ),
                  ),
          ],
        ),
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
