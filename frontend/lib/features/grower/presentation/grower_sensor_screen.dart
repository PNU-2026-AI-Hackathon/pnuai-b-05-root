import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/grower_repository.dart';
import '../data/sensor_repository.dart';

/// 1t — 환경 점검: 재배지 방문 시 온도/습도/조도를 수동 입력. `POST /api/sensor/data/`,
/// `GET /api/sensor/anomaly/{seedling_id}/`와 실제 연동한다.
class GrowerSensorScreen extends StatefulWidget {
  const GrowerSensorScreen({super.key});

  @override
  State<GrowerSensorScreen> createState() => _GrowerSensorScreenState();
}

class _GrowerSensorScreenState extends State<GrowerSensorScreen> {
  final _seedlingRepository = GrowerRepository();
  final _sensorRepository = SensorRepository();

  bool _loadingSeedlings = true;
  String? _loadErrorMessage;
  List<Seedling> _seedlings = const [];
  int? _selectedSeedlingId;

  int _temperature = 16;
  int _humidity = 82;
  int _lux = 1400;

  bool _saving = false;
  SensorReading? _lastReading;

  bool _historyLoading = false;
  List<SensorReading> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadSeedlings();
  }

  Future<void> _loadSeedlings() async {
    setState(() {
      _loadingSeedlings = true;
      _loadErrorMessage = null;
    });
    try {
      final seedlings = await _seedlingRepository.fetchSeedlings();
      final growing = seedlings
          .where((s) => s.status == SeedlingStatus.growing)
          .toList();
      final selectedId = growing.isNotEmpty
          ? growing.first.id
          : (seedlings.isNotEmpty ? seedlings.first.id : null);
      setState(() {
        _seedlings = seedlings;
        _selectedSeedlingId = selectedId;
      });
      if (selectedId != null) _loadHistory(selectedId);
    } on ApiException catch (e) {
      setState(() => _loadErrorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loadingSeedlings = false);
    }
  }

  Future<void> _loadHistory(int seedlingId) async {
    setState(() => _historyLoading = true);
    try {
      final history = await _sensorRepository.fetchAnomalyHistory(seedlingId);
      if (mounted) setState(() => _history = history);
    } on ApiException {
      // 이력 조회 실패는 화면 전체를 막을 정도는 아니라 조용히 빈 목록으로 둔다.
      if (mounted) setState(() => _history = const []);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _selectSeedling(int seedlingId) {
    setState(() {
      _selectedSeedlingId = seedlingId;
      _lastReading = null;
    });
    _loadHistory(seedlingId);
  }

  Future<void> _save() async {
    final seedlingId = _selectedSeedlingId;
    if (seedlingId == null) return;

    setState(() => _saving = true);
    try {
      final reading = await _sensorRepository.createSensorData(
        seedlingId: seedlingId,
        temperature: _temperature.toDouble(),
        humidity: _humidity.toDouble(),
        light: _lux.toDouble(),
      );
      if (!mounted) return;
      setState(() => _lastReading = reading);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reading.isAnomaly ? '기록을 저장했어요 · 이상이 감지됐어요 ⚠️' : '기록을 저장했어요 ✅',
          ),
        ),
      );
      _loadHistory(seedlingId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    if (_loadingSeedlings) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
    }
    if (_loadErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadErrorMessage!,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadSeedlings, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_seedlings.isEmpty) {
      return Center(
        child: Text(
          '아직 담당하는 묘목이 없어요',
          style: AppTextStyles.body(fontSize: 14, color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🌡️ 환경 점검',
          style: AppTextStyles.title(
            fontSize: 20,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          '재배지 방문 시 수치를 입력해주세요',
          style: AppTextStyles.guide(
            fontSize: 14,
            color: AppColors.badgeGreenText,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '어떤 묘목인가요?',
                  style: AppTextStyles.body(
                    fontSize: 13,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final seedling in _seedlings)
                      _SeedlingChip(
                        label: '무화과 #${seedling.id}',
                        selected: seedling.id == _selectedSeedlingId,
                        onTap: () => _selectSeedling(seedling.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetricRow(
                  icon: '🌡️',
                  iconBg: const Color(0xFFFDF3DC),
                  label: '온도',
                  value: '$_temperature',
                  unit: '°C',
                  onDecrement: () => setState(() => _temperature -= 1),
                  onIncrement: () => setState(() => _temperature += 1),
                ),
                const SizedBox(height: 12),
                _MetricRow(
                  icon: '💧',
                  iconBg: const Color(0xFFF3F8FD),
                  label: '습도',
                  value: '$_humidity',
                  unit: '%',
                  onDecrement: () => setState(() => _humidity -= 1),
                  onIncrement: () => setState(() => _humidity += 1),
                ),
                const SizedBox(height: 12),
                _MetricRow(
                  icon: '☀️',
                  iconBg: const Color(0xFFFDF3DC),
                  label: '조도',
                  value: '$_lux',
                  unit: 'lux',
                  onDecrement: () => setState(() => _lux -= 100),
                  onIncrement: () => setState(() => _lux += 100),
                ),
                if (_lastReading != null) ...[
                  const SizedBox(height: 12),
                  _ResultBox(reading: _lastReading!),
                ],
                const SizedBox(height: 16),
                Text(
                  '최근 이상 이력',
                  style: AppTextStyles.body(
                    fontSize: 13,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_historyLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.pink500,
                      ),
                    ),
                  )
                else if (_history.isEmpty)
                  Text(
                    '이상 이력이 없어요',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final reading in _history.take(3)) ...[
                        _HistoryRow(reading: reading),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        PigFigButton.positive(
          label: '기록 저장하기',
          onPressed: _save,
          loading: _saving,
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.unit,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String icon;
  final Color iconBg;
  final String label;
  final String value;
  final String unit;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: AppTextStyles.title(
                        fontSize: 22,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: const Color(0xFFB7B2A4),
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _StepperButton(
                symbol: '−',
                background: const Color(0xFFF3F1E9),
                color: AppColors.textMuted,
                onTap: onDecrement,
              ),
              const SizedBox(width: 6),
              _StepperButton(
                symbol: '+',
                background: AppColors.badgeGreenBg,
                color: AppColors.badgeGreenText,
                onTap: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.symbol,
    required this.background,
    required this.color,
    required this.onTap,
  });

  final String symbol;
  final Color background;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Text(
          symbol,
          style: AppTextStyles.body(
            fontSize: 16,
            color: color,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SeedlingChip extends StatelessWidget {
  const _SeedlingChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.pink500 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? null
              : Border.all(color: AppColors.outline, width: 1.5),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 13,
            color: selected ? Colors.white : AppColors.textMuted,
          ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}

/// 방금 저장한 값의 판정 결과. `is_anomaly`/`gemini_diagnosis` 모두 서버 응답 그대로다.
class _ResultBox extends StatelessWidget {
  const _ResultBox({required this.reading});

  final SensorReading reading;

  @override
  Widget build(BuildContext context) {
    final isAnomaly = reading.isAnomaly;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isAnomaly ? const Color(0xFFFDEFF2) : AppColors.badgeGreenBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAnomaly ? '⚠️ 이상 감지' : '✅ 정상이에요',
            style: AppTextStyles.body(
              fontSize: 14,
              color: isAnomaly
                  ? AppColors.warningPink
                  : AppColors.badgeGreenText,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          if (isAnomaly && reading.geminiDiagnosis != null) ...[
            const SizedBox(height: 6),
            Text(
              reading.geminiDiagnosis!,
              style: AppTextStyles.body(
                fontSize: 13,
                color: const Color(0xFF6B675C),
              ).copyWith(height: 1.65),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.reading});

  final SensorReading reading;

  static String _formatDateTime(DateTime date) =>
      '${date.month}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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
                '${reading.temperature.toStringAsFixed(0)}°C · ${reading.humidity.toStringAsFixed(0)}% · ${reading.light.toStringAsFixed(0)}lux',
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
