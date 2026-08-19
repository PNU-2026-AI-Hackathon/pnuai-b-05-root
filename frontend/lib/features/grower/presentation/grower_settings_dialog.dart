import 'package:flutter/material.dart';

import '../../../core/storage/grower_font_scale_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_button.dart';

/// 재배자 마이페이지 톱니바퀴 → 글자 크기 설정 모달.
///
/// 저장 성공 시 새로 선택한 배율(`double`)을 반환해 호출부가
/// [GrowerFontScaleScope.refresh]로 화면에 즉시 반영할 수 있게 한다.
/// 취소로 닫히면 `null`.
Future<double?> showGrowerSettingsDialog(
  BuildContext context, {
  required double initialScale,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => GrowerSettingsDialog(initialScale: initialScale),
  );
}

class GrowerSettingsDialog extends StatefulWidget {
  const GrowerSettingsDialog({super.key, required this.initialScale});

  final double initialScale;

  @override
  State<GrowerSettingsDialog> createState() => _GrowerSettingsDialogState();
}

class _GrowerLevel {
  const _GrowerLevel(this.label, this.scale);

  final String label;
  final double scale;
}

const _levels = [
  _GrowerLevel('작게', GrowerFontScaleStorage.small),
  _GrowerLevel('보통', GrowerFontScaleStorage.medium),
  _GrowerLevel('크게', GrowerFontScaleStorage.large),
];

class _GrowerSettingsDialogState extends State<GrowerSettingsDialog> {
  late double _selected = widget.initialScale;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final userId = await TokenStorage().readUserId();
    if (userId != null) {
      await GrowerFontScaleStorage(userId: userId).setScale(_selected);
    }
    if (!mounted) return;
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '글자 크기',
                    style: AppTextStyles.title(fontSize: 18),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '재배자 화면에서만 적용돼요',
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < _levels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _LevelButton(
                      label: _levels[i].label,
                      selected: _selected == _levels[i].scale,
                      onTap: () =>
                          setState(() => _selected = _levels[i].scale),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.beigeBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(_selected)),
                child: Text(
                  '오늘 무화과가 잘 자라고 있어요 🌱',
                  style: AppTextStyles.body(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
            PigFigButton.positive(
              label: '저장',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({
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
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.pink500 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.pink500 : AppColors.outline,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 14,
            color: selected ? Colors.white : AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
