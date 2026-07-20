import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/status_badge.dart';

/// 1t — 환경 점검: 재배지 방문 시 온도/습도/조도를 수동 입력. mock UI(백엔드 미연동).
class GrowerSensorScreen extends StatefulWidget {
  const GrowerSensorScreen({super.key});

  @override
  State<GrowerSensorScreen> createState() => _GrowerSensorScreenState();
}

class _GrowerSensorScreenState extends State<GrowerSensorScreen> {
  int _temperature = 16;
  int _humidity = 82;
  int _lux = 1400;

  void _showSaved() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
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
            _MetricRow(
              icon: '🌡️',
              iconBg: const Color(0xFFFDF3DC),
              label: '온도',
              value: '$_temperature',
              unit: '°C',
              valueColor: AppColors.textPrimary,
              normal: true,
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
              valueColor: AppColors.warningPink,
              normal: false,
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
              valueColor: AppColors.textPrimary,
              normal: false,
              onDecrement: () => setState(() => _lux -= 100),
              onIncrement: () => setState(() => _lux += 100),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEFF2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ 이상 감지',
                    style: AppTextStyles.body(
                      fontSize: 14,
                      color: AppColors.warningPink,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '습도가 기준 범위(40~70%)를 초과했어요.\n조도가 기준치(2000 lux) 이하예요. LED 보광등을 켜주세요.',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: const Color(0xFF6B675C),
                    ).copyWith(height: 1.65),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PigFigButton.positive(label: '기록 저장하기', onPressed: _showSaved),
            const SizedBox(height: 14),
          ],
        ),
      ),
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
    required this.valueColor,
    required this.normal,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String icon;
  final Color iconBg;
  final String label;
  final String value;
  final String unit;
  final Color valueColor;
  final bool normal;
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
        border: normal ? null : Border.all(color: AppColors.pink100, width: 2),
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
                        color: valueColor,
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
          const SizedBox(width: 10),
          StatusBadge(
            label: normal ? '정상' : '주의',
            background: normal ? AppColors.green500 : AppColors.pink100,
            textColor: normal ? Colors.white : AppColors.warningPink,
            pill: false,
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
