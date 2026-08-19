import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gauge_bar.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/grower_repository.dart';
import '../data/sensor_repository.dart';

/// 묘목 한 그루의 이상 감지 요약(건수 + 최근 발생일).
class _SeedlingAnomalySummary {
  const _SeedlingAnomalySummary({
    required this.seedlingId,
    required this.anomalyCount,
    this.mostRecent,
  });

  final int seedlingId;
  final int anomalyCount;
  final DateTime? mostRecent;
}

/// 재배자 마이 탭 "환경 이상 감지 요약"에서 진입. 담당하는 모든 묘목의 이상 감지
/// 이력을 한 화면에서 비교한다 — `grower_sensor_screen.dart`는 묘목 하나씩만 보여줘서,
/// 여러 묘목을 한눈에 비교할 방법이 없었다.
/// `grower_activity_calendar_screen.dart`와 동일하게 담당 묘목마다 병렬로 조회한 뒤
/// 하나의 화면에 모은다. 독립 push 화면이라(탭 화면이 아님) 일반 `State`를 쓴다.
class GrowerAnomalySummaryScreen extends StatefulWidget {
  const GrowerAnomalySummaryScreen({super.key});

  @override
  State<GrowerAnomalySummaryScreen> createState() =>
      _GrowerAnomalySummaryScreenState();
}

class _GrowerAnomalySummaryScreenState
    extends State<GrowerAnomalySummaryScreen> {
  final _growerRepository = GrowerRepository();
  final _sensorRepository = SensorRepository();

  bool _loading = true;
  String? _errorMessage;
  List<_SeedlingAnomalySummary> _summaries = [];

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
      final seedlings = await _growerRepository.fetchSeedlings();
      final histories = await Future.wait(
        seedlings.map((s) => _sensorRepository.fetchAnomalyHistory(s.id)),
      );
      final summaries = <_SeedlingAnomalySummary>[
        for (var i = 0; i < seedlings.length; i++)
          _SeedlingAnomalySummary(
            seedlingId: seedlings[i].id,
            anomalyCount: histories[i].length,
            // fetchAnomalyHistory가 이미 recordedAt 내림차순으로 정렬해 내려준다.
            mostRecent: histories[i].isEmpty ? null : histories[i].first.recordedAt,
          ),
      ];
      if (!mounted) return;
      setState(() => _summaries = summaries);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(child: _buildBody()),
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
    if (_summaries.isEmpty) {
      return const _EmptyState();
    }

    final maxCount = _summaries
        .map((s) => s.anomalyCount)
        .fold(0, (max, count) => count > max ? count : max);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('환경 이상 감지 요약', style: AppTextStyles.title(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            '담당 묘목별 이상 감지 이력을 한눈에 비교해요',
            style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          for (final summary in _summaries) ...[
            _SeedlingAnomalyRow(summary: summary, maxCount: maxCount),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SeedlingAnomalyRow extends StatelessWidget {
  const _SeedlingAnomalyRow({required this.summary, required this.maxCount});

  final _SeedlingAnomalySummary summary;
  final int maxCount;

  String get _recentLabel {
    final date = summary.mostRecent;
    if (date == null) return '';
    final local = date.toLocal();
    return '최근 발생 ${local.month}월 ${local.day}일';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '묘목 #${summary.seedlingId}',
                style: AppTextStyles.body(
                  fontSize: 14,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${summary.anomalyCount}건',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: summary.anomalyCount == 0
                      ? AppColors.textMuted
                      : AppColors.errorRed,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (summary.anomalyCount == 0)
            Text(
              '이상 없음',
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            )
          else ...[
            GaugeBar(
              value: maxCount == 0 ? 0 : summary.anomalyCount / maxCount,
              fillColor: AppColors.errorRed,
            ),
            const SizedBox(height: 6),
            Text(
              _recentLabel,
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              '아직 담당하는 묘목이 없어요',
              style: AppTextStyles.body(
                fontSize: 15,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '묘목이 배정되면 이상 감지 요약이 채워져요',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
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
