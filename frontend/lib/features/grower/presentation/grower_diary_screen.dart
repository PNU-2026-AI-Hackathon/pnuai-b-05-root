import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/diary_repository.dart';
import '../data/grower_repository.dart';

/// 1s — 재배자 일지 작성: 사진 업로드(선택) + 기록 입력. `POST /api/diary/`와 실제 연동한다.
/// "성장 단계" 칩은 실제 `Diary` 모델에 대응하는 필드가 없어 여전히 로컬 UI 장식으로만 남는다.
class GrowerDiaryScreen extends StatefulWidget {
  const GrowerDiaryScreen({super.key});

  @override
  State<GrowerDiaryScreen> createState() => _GrowerDiaryScreenState();
}

class _GrowerDiaryScreenState extends State<GrowerDiaryScreen> {
  static const _stages = ['뿌리', '잎 성장 중', '가지 발달', '묘목 완성'];

  final _seedlingRepository = GrowerRepository();
  final _diaryRepository = DiaryRepository();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();

  bool _loadingSeedlings = true;
  String? _loadErrorMessage;
  List<Seedling> _seedlings = const [];
  int? _selectedSeedlingId;

  int _selectedStage = 1;
  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSeedlings();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
      setState(() {
        _seedlings = seedlings;
        _selectedSeedlingId = growing.isNotEmpty
            ? growing.first.id
            : (seedlings.isNotEmpty ? seedlings.first.id : null);
      });
    } on ApiException catch (e) {
      setState(() => _loadErrorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loadingSeedlings = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoFileName = picked.name;
    });
  }

  Future<void> _submit() async {
    final seedlingId = _selectedSeedlingId;
    if (seedlingId == null) return;
    final content = _noteController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘의 성장 기록을 입력해주세요')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await _diaryRepository.createDiary(
        seedlingId: seedlingId,
        content: content,
        photoBytes: _photoBytes,
        photoFileName: _photoFileName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘의 일지를 입양자에게 전달했어요 🌱')));
      setState(() {
        _noteController.clear();
        _photoBytes = null;
        _photoFileName = null;
        _selectedStage = 1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
          '📋 오늘의 일지',
          style: AppTextStyles.title(
            fontSize: 20,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          '입양자에게 성장 기록을 전달해요',
          style: AppTextStyles.guide(
            fontSize: 14,
            color: AppColors.badgeGreenText,
          ),
        ),
        const SizedBox(height: 14),
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
                onTap: () => setState(() => _selectedSeedlingId = seedling.id),
              ),
          ],
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _photoBytes == null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 26,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.dotInactive,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📷', style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(
                          '사진 추가하기',
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: AppColors.badgeGreenText,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '묘목 상태를 찍어 업로드해주세요',
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: const Color(0xFFB7B2A4),
                          ),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.memory(
                          _photoBytes!,
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '탭해서 변경',
                            style: AppTextStyles.body(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '성장 단계',
          style: AppTextStyles.title(
            fontSize: 15,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
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
                hintStyle: AppTextStyles.body(
                  fontSize: 14,
                  color: const Color(0xFFB7B2A4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PigFigButton.primary(
          label: '입양자에게 전달하기',
          onPressed: _submit,
          loading: _submitting,
        ),
        const SizedBox(height: 14),
      ],
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

class _StageChip extends StatelessWidget {
  const _StageChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.green500 : Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: selected
              ? null
              : Border.all(color: AppColors.outline, width: 1.5),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 14,
            color: selected ? Colors.white : AppColors.textMuted,
          ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}
