import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/grower_repository.dart';
import 'grower_diary_list_screen.dart';
import 'grower_seedling_overview.dart';

/// 재배중 묘목이 완료 묘목보다 항상 먼저 오도록 재정렬한다. `List.sort`는 Dart에서 stable을
/// 보장하지 않으므로, 상태별로 `where()`(원래 순서를 보존)한 결과를 이어붙여 안정적으로
/// 정렬한다 — 같은 상태 안에서의 순서는 API 응답 순서 그대로 유지된다.
List<Seedling> _sortByStatus(List<Seedling> seedlings) => [
  ...seedlings.where((s) => s.status == SeedlingStatus.growing),
  ...seedlings.where((s) => s.status == SeedlingStatus.completed),
];

/// "일지" 탭: 예전 대시보드(현재는 "선반 뷰"인 홈 탭으로 대체됨)가 쓰던 것과 동일한
/// 디자인(통계 3칸 + 담당 묘목 목록 카드)을 쓰되, 카드를 탭하면 완성 신고가 아니라 그
/// 묘목의 일지 리스트 화면(`GrowerDiaryListScreen`)으로 이동한다. 상단 헤더(이모지+
/// 타이틀, 부제목)는 `grower_shelf_screen.dart`의 톤을 그대로 따른다.
class GrowerDiaryTabScreen extends StatefulWidget {
  const GrowerDiaryTabScreen({super.key});

  @override
  State<GrowerDiaryTabScreen> createState() => _GrowerDiaryTabScreenState();
}

class _GrowerDiaryTabScreenState
    extends RevalidatableState<GrowerDiaryTabScreen> {
  final _repository = GrowerRepository();

  bool _loading = true;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  List<Seedling> _seedlings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedlings = await _repository.fetchSeedlings();
      setState(() => _seedlings = _sortByStatus(seedlings));
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
      _hasLoadedOnce = true;
    }
  }

  /// `GrowerShell`이 일지 탭 재진입 시 호출한다. 다른 탭에 다녀오는 동안 담당 묘목이
  /// 바뀌었을 수 있으니 다시 불러오되, 기존 목록은 그대로 둔 채 응답이 오면 조용히
  /// 교체한다.
  @override
  Future<void> revalidate() async {
    if (!_hasLoadedOnce) return _load();
    try {
      final seedlings = await _repository.fetchSeedlings();
      if (mounted) setState(() => _seedlings = _sortByStatus(seedlings));
    } on ApiException {
      // 재조회 실패 시 기존 목록을 그대로 유지한다.
    }
  }

  void _openDiaryList(Seedling seedling) {
    Navigator.of(context).pushNamed(
      '/grower/diary-list',
      arguments: GrowerDiaryListArgs(
        seedlingId: seedling.id,
        isCompleted: seedling.status == SeedlingStatus.completed,
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
    if (_seedlings.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📋 담당 묘목 일지',
          style: AppTextStyles.title(
            fontSize: 20,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          '묘목을 선택해 성장 기록을 남겨보세요',
          style: AppTextStyles.guide(
            fontSize: 14,
            color: AppColors.badgeGreenText,
          ),
        ),
        const SizedBox(height: 16),
        GrowerSeedlingStatsRow(seedlings: _seedlings),
        const SizedBox(height: 16),
        Text('담당 묘목 목록', style: AppTextStyles.title(fontSize: 17)),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _seedlings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final seedling = _seedlings[index];
                return GrowerSeedlingListCard(
                  seedling: seedling,
                  onTap: () => _openDiaryList(seedling),
                );
              },
            ),
          ),
        ),
      ],
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
