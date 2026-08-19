import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/diary_repository.dart';
import '../data/grower_repository.dart';
import '../data/sensor_repository.dart';
import 'grower_complete_screen.dart';
import 'grower_diary_list_screen.dart';

/// 성장 기록 섹션에서 미리 보여줄 최대 일지 수 — 그 이상은 "전체 일지 보기"로 안내한다.
const _diaryPreviewLimit = 5;

/// `/grower/seedling-analysis` route argument.
class GrowerSeedlingAnalysisArgs {
  const GrowerSeedlingAnalysisArgs({
    required this.seedlingId,
    required this.adopterId,
    required this.status,
  });

  final int seedlingId;
  final int adopterId;
  final SeedlingStatus status;
}

/// 묘목 한 그루의 분석 화면. 새 백엔드 API 없이 이미 있는 두 조회를 병렬로 모은다 —
/// `SensorRepository.fetchAnomalyHistory()`(환경 이상 감지 이력)와
/// `DiaryRepository.fetchDiaries()`(일지별 성장 단계/YOLO 태그). 다른 push 화면
/// (`GrowerCompleteScreen`, `GrowerDiaryListScreen` 등)과 동일하게 매번 새로 mount되므로
/// `RevalidatableState`는 쓰지 않는다.
class GrowerSeedlingAnalysisScreen extends StatefulWidget {
  const GrowerSeedlingAnalysisScreen({super.key});

  @override
  State<GrowerSeedlingAnalysisScreen> createState() =>
      _GrowerSeedlingAnalysisScreenState();
}

class _GrowerSeedlingAnalysisScreenState
    extends State<GrowerSeedlingAnalysisScreen> {
  final _sensorRepository = SensorRepository();
  final _diaryRepository = DiaryRepository();

  bool _loading = true;
  String? _errorMessage;
  List<SensorReading> _anomalies = const [];
  List<DiaryEntry> _diaries = const [];

  bool _initialized = false;

  /// `ModalRoute.of(context)`는 위젯이 트리에 삽입된 뒤에만 조회할 수 있어
  /// `initState()`가 아니라 여기서 첫 조회를 시작한다(`GrowerDiaryListScreen`과 동일한 패턴).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  GrowerSeedlingAnalysisArgs get _args =>
      ModalRoute.of(context)!.settings.arguments
          as GrowerSeedlingAnalysisArgs;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedlingId = _args.seedlingId;
      final results = await Future.wait<dynamic>([
        _sensorRepository.fetchAnomalyHistory(seedlingId),
        _diaryRepository.fetchDiaries(seedlingId),
      ]);
      setState(() {
        _anomalies = results[0] as List<SensorReading>;
        _diaries = results[1] as List<DiaryEntry>;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔍 무화과 #${args.seedlingId} 분석',
              style: AppTextStyles.title(
                fontSize: 20,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '센서 이상 이력과 성장 기록을 모아봤어요',
              style: AppTextStyles.guide(
                fontSize: 14,
                color: AppColors.badgeGreenText,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildBody(args)),
            if (args.status == SeedlingStatus.growing) ...[
              const SizedBox(height: 12),
              PigFigButton.primary(
                label: '완성 신고하기',
                onPressed: () => Navigator.of(context).pushNamed(
                  '/grower/complete',
                  arguments: GrowerCompleteArgs(
                    seedlingId: args.seedlingId,
                    seedlingName: '무화과 #${args.seedlingId}',
                    adopterName: '입양자 #${args.adopterId}',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(GrowerSeedlingAnalysisArgs args) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😢', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '환경 이상 감지 이력',
            style: AppTextStyles.body(
              fontSize: 13,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_anomalies.isEmpty)
            Text(
              '이상 감지 이력이 없어요',
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            )
          else
            for (final reading in _anomalies) ...[
              _AnomalyCard(reading: reading),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 20),
          Text(
            '성장 기록',
            style: AppTextStyles.body(
              fontSize: 13,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_diaries.isEmpty)
            Text(
              '작성된 일지가 없어요',
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            )
          else
            for (final entry in _diaries.take(_diaryPreviewLimit)) ...[
              _DiarySummaryCard(entry: entry),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamed(
                '/grower/diary-list',
                arguments: GrowerDiaryListArgs(seedlingId: args.seedlingId),
              ),
              child: const Text('전체 일지 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// `grower_sensor_screen.dart`의 `_HistoryRow`와 동일한 시각적 톤(흰 카드 + 핑크 테두리 +
/// 발생일/수치 한 줄 + 진단 문구)을 재사용한다. 이 API는 어떤 필드가 이상이었는지 별도로
/// 내려주지 않아(백엔드 `SensorData`에 필드별 플래그가 없음) 온도/습도/조도 실측값을 그대로
/// 보여준다.
class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard({required this.reading});

  final SensorReading reading;

  static String _formatDateTime(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pink100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateTime(reading.recordedAt),
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: const Color(0xFFB7B2A4),
                ),
              ),
              Text(
                '${reading.temperature.toStringAsFixed(0)}°C · '
                '${reading.humidity.toStringAsFixed(0)}% · '
                '${reading.light.toStringAsFixed(0)}lux',
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (reading.geminiDiagnosis != null) ...[
            const SizedBox(height: 4),
            Text(
              reading.geminiDiagnosis!,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.warningPink,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}

/// `grower_diary_list_screen.dart`의 `_DiaryCard`와 동일한 카드 톤이되, 본문을 2줄로 요약해
/// 목록이 길어지지 않게 한다.
class _DiarySummaryCard extends StatelessWidget {
  const _DiarySummaryCard({required this.entry});

  final DiaryEntry entry;

  static String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(entry.createdAt),
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: const Color(0xFFB7B2A4),
                ),
              ),
              Row(
                children: [
                  if (entry.growthStageLabel != null)
                    StatusBadge(
                      label: entry.growthStageLabel!,
                      background: AppColors.green500,
                      pill: false,
                    ),
                  if (entry.yoloStatusTag != null) ...[
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: entry.yoloStatusTag!,
                      background: AppColors.badgeGreenBg,
                      textColor: AppColors.badgeGreenText,
                      pill: false,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textPrimary,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
