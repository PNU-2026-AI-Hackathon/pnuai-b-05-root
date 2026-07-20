import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';

/// 1s — 재배자 일지 작성: 사진 업로드 + 성장 단계 선택 + 기록 입력. mock UI(백엔드 미연동).
class GrowerDiaryScreen extends StatefulWidget {
  const GrowerDiaryScreen({super.key});

  @override
  State<GrowerDiaryScreen> createState() => _GrowerDiaryScreenState();
}

class _GrowerDiaryScreenState extends State<GrowerDiaryScreen> {
  static const _stages = ['뿌리', '잎 성장 중', '가지 발달', '묘목 완성'];
  int _selectedStage = 1;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('준비 중이에요')));
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
            Text('📋 오늘의 일지', style: AppTextStyles.title(fontSize: 20).copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('입양자에게 성장 기록을 전달해요', style: AppTextStyles.guide(fontSize: 14, color: AppColors.badgeGreenText)),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _showComingSoon,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.dotInactive, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📷', style: TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text('사진 추가하기', style: AppTextStyles.body(fontSize: 15, color: AppColors.badgeGreenText).copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('묘목 상태를 찍어 업로드해주세요', style: AppTextStyles.body(fontSize: 12, color: const Color(0xFFB7B2A4))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('성장 단계', style: AppTextStyles.title(fontSize: 15).copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _stages.length; i++)
                  _StageChip(
                    label: _stages[i],
                    selected: i == _selectedStage,
                    onTap: () => setState(() => _selectedStage = i),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: TextField(
                  controller: _noteController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTextStyles.body(fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                    hintText: '오늘의 성장 기록을 남겨주세요...',
                    hintStyle: AppTextStyles.body(fontSize: 14, color: const Color(0xFFB7B2A4)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PigFigButton.primary(label: '입양자에게 전달하기', onPressed: _showComingSoon),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.green500 : Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: selected ? null : Border.all(color: AppColors.outline, width: 1.5),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(fontSize: 14, color: selected ? Colors.white : AppColors.textMuted)
              .copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}
