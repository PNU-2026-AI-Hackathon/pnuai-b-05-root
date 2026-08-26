import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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

/// 상단 기간 필터. 백엔드 `GET /api/sensor/anomaly/{id}/?days=N`으로 넘긴다
/// ([_AnomalyPeriod.all]이면 파라미터를 안 붙여 전체 기간).
enum _AnomalyPeriod { week, month, all }

extension _AnomalyPeriodX on _AnomalyPeriod {
  int? get days => switch (this) {
    _AnomalyPeriod.week => 7,
    _AnomalyPeriod.month => 30,
    _AnomalyPeriod.all => null,
  };

  String get label => switch (this) {
    _AnomalyPeriod.week => '최근 7일',
    _AnomalyPeriod.month => '최근 30일',
    _AnomalyPeriod.all => '전체',
  };
}

/// 재배자 마이 탭 "환경 이상 감지 요약"에서 진입. 담당하는 모든 묘목의 이상 감지
/// 이력을 한 화면에서 비교한다 — `grower_sensor_screen.dart`는 묘목 하나씩만 보여줘서,
/// 여러 묘목을 한눈에 비교할 방법이 없었다.
/// `grower_activity_calendar_screen.dart`와 동일하게 담당 묘목마다 병렬로 조회한 뒤
/// 하나의 화면에 모은다. 독립 push 화면이라(탭 화면이 아님) 일반 `State`를 쓴다.
///
/// 손으로 그린 막대(회색 트랙 카드 나열) 대신 `fl_chart`의 가로 막대그래프로 보여주고,
/// 상단 기간 칩(7일/30일/전체)으로 조회 범위를 바꾼다.
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
  _AnomalyPeriod _period = _AnomalyPeriod.all;

  /// 기간 칩을 연타하면 `_load()`가 겹칠 수 있어, 가장 마지막 호출의 응답만 반영한다.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedlings = await _growerRepository.fetchSeedlings();
      final histories = await Future.wait(
        seedlings.map(
          (s) => _sensorRepository.fetchAnomalyHistory(s.id, days: _period.days),
        ),
      );
      if (!mounted || token != _loadToken) return;
      final summaries = <_SeedlingAnomalySummary>[
        for (var i = 0; i < seedlings.length; i++)
          _SeedlingAnomalySummary(
            seedlingId: seedlings[i].id,
            anomalyCount: histories[i].length,
            // fetchAnomalyHistory가 이미 recordedAt 내림차순으로 정렬해 내려준다.
            mostRecent: histories[i].isEmpty ? null : histories[i].first.recordedAt,
          ),
      ];
      setState(() => _summaries = summaries);
    } on ApiException catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted && token == _loadToken) setState(() => _loading = false);
    }
  }

  void _selectPeriod(_AnomalyPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _load);
    }
    // 최초 로드 중에만 전체 스피너. 기간 전환 재조회는 기존 차트를 유지한 채
    // 얇은 진행 표시만 보여준다.
    if (_loading && _summaries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
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
            '담당 묘목별 이상 감지 건수를 기간별로 비교해요',
            style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          _PeriodChips(selected: _period, onSelected: _selectPeriod),
          const SizedBox(height: 8),
          SizedBox(
            height: 3,
            child: _loading
                ? const LinearProgressIndicator(
                    color: AppColors.pink500,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
          const SizedBox(height: 13),
          _AnomalyBarChartCard(summaries: _summaries, maxCount: maxCount),
          if (maxCount == 0) ...[
            const SizedBox(height: 12),
            Text(
              '선택한 기간에는 이상 감지가 없어요 🌿',
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              '막대를 탭하면 건수와 최근 발생일을 볼 수 있어요',
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textCaption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 기간 필터 칩 3개(최근 7일 / 최근 30일 / 전체). `grower_settings_dialog.dart`의
/// 글자 크기 3분할 버튼과 같은 시각 스타일(선택=pink500, 미선택=흰 배경+아웃라인).
class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.selected, required this.onSelected});

  final _AnomalyPeriod selected;
  final ValueChanged<_AnomalyPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _AnomalyPeriod.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _PeriodChip(
              label: _AnomalyPeriod.values[i].label,
              selected: _AnomalyPeriod.values[i] == selected,
              onTap: () => onSelected(_AnomalyPeriod.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.pink500 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.pink500 : AppColors.outline,
            width: 1.5,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppTextStyles.body(
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// `fl_chart` 가로 막대그래프. `rotationQuarterTurns: 1`로 세로 막대 차트를 90도
/// 돌려 가로 막대로 만든다(fl_chart 공식 Horizontal Bar Chart 방식). 축 라벨은
/// `SideTitleWidget`이 회전을 자동 보정한다.
/// - Y축(회전 후 왼쪽): 담당 묘목 목록
/// - X축(막대 길이): 이상 감지 건수. 0건은 회색, 1건 이상은 경고색(errorRed)
/// - 건수/최근 발생일은 막대 탭 시 툴팁으로
class _AnomalyBarChartCard extends StatelessWidget {
  const _AnomalyBarChartCard({required this.summaries, required this.maxCount});

  final List<_SeedlingAnomalySummary> summaries;
  final int maxCount;

  static const _trackColor = Color(0xFFECEAE0);

  @override
  Widget build(BuildContext context) {
    // 막대 길이 상한. 전부 0건이어도 1로 둬 0으로 나누는 상황을 피한다.
    final maxY = (maxCount <= 0 ? 1 : maxCount).toDouble();
    // 묘목 수에 비례해 세로 공간을 늘린다(회전한 차트라 묘목 축이 세로).
    // 담당 묘목이 많아도(10마리+) 바깥 SingleChildScrollView로 스크롤된다 —
    // 차트 안에 스크롤을 또 넣으면 회전 좌표계에서 제스처가 충돌한다.
    final chartHeight = math.max(168.0, summaries.length * 48.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
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
      child: SizedBox(
        height: chartHeight,
        child: BarChart(
          BarChartData(
            rotationQuarterTurns: 1,
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            minY: 0,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 74,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= summaries.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 8,
                      child: Text(
                        '묘목 #${summaries[index].seedlingId}',
                        style: AppTextStyles.caption(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final summary = summaries[group.x];
                  final recent = summary.mostRecent?.toLocal();
                  final recentText = recent == null
                      ? ''
                      : '\n최근 ${recent.month}월 ${recent.day}일';
                  return BarTooltipItem(
                    '${summary.anomalyCount}건$recentText',
                    AppTextStyles.body(
                      fontSize: 12,
                      color: Colors.white,
                    ).copyWith(fontWeight: FontWeight.w700),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < summaries.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: summaries[i].anomalyCount.toDouble(),
                      width: 20,
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                      color: summaries[i].anomalyCount == 0
                          ? AppColors.textMuted
                          : AppColors.errorRed,
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: _trackColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
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
