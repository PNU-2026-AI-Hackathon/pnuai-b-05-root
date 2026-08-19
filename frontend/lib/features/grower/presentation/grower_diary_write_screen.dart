import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/photo_source_dialog.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/diary_repository.dart';
import '../data/vision_repository.dart';

/// `/grower/diary-write` route argument: 어떤 묘목에 대한 일지를 쓸지는 이 화면에
/// 진입하기 전에(다음 단계에서 만들 일지 리스트 화면에서) 이미 정해진다.
class GrowerDiaryWriteArgs {
  const GrowerDiaryWriteArgs({required this.seedlingId});

  final int seedlingId;
}

/// 1s — 재배자 일지 작성: 사진 업로드(선택) + 기록 입력. `POST /api/diary/`와 실제 연동한다.
/// "성장 단계" 칩은 백엔드 `Diary.GrowthStage` choices(rooting/leafing/branching/mature)와
/// 실제로 연동되어 선택한 코드값이 `growth_stage`로 전송된다. 대상 묘목은 route argument
/// (`GrowerDiaryWriteArgs`)로 이미 정해진 채로 진입한다 — 이 화면 자체에서 묘목을 고르지 않는다.
class GrowerDiaryWriteScreen extends StatefulWidget {
  const GrowerDiaryWriteScreen({super.key});

  @override
  State<GrowerDiaryWriteScreen> createState() =>
      _GrowerDiaryWriteScreenState();
}

class _GrowerDiaryWriteScreenState extends State<GrowerDiaryWriteScreen> {
  /// (한글 라벨, 백엔드 코드값) 쌍 — `backend/diary/models.py`의
  /// `Diary.GrowthStage`와 순서·값을 그대로 맞춘다.
  static const _stages = <(String label, String code)>[
    ('발근 중', 'rooting'),
    ('잎 성장 중', 'leafing'),
    ('가지 발달', 'branching'),
    ('묘목 완성', 'mature'),
  ];

  final _diaryRepository = DiaryRepository();
  final _visionRepository = VisionRepository();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();

  int _selectedStage = 1;
  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _submitting = false;
  bool _analyzing = false;
  String? _lastAnalysisTag;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _choosePhotoSource() async {
    final source = await showPhotoSourceDialog(context);
    if (source == null) return;
    await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoFileName = picked.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 가져오지 못했어요. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _submit(int seedlingId) async {
    final content = _noteController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘의 성장 기록을 입력해주세요')));
      return;
    }

    final photoBytes = _photoBytes;
    final photoFileName = _photoFileName;

    setState(() => _submitting = true);
    try {
      final diaryId = await _diaryRepository.createDiary(
        seedlingId: seedlingId,
        content: content,
        photoBytes: photoBytes,
        photoFileName: photoFileName,
        growthStage: _stages[_selectedStage].$2,
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
      if (photoBytes != null) {
        unawaited(
          _analyzePhoto(
            diaryId: diaryId,
            photoBytes: photoBytes,
            photoFileName: photoFileName,
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 일지 생성이 끝난 뒤 같은 사진으로 vision 분석을 요청한다. 실패해도 일지 자체는
  /// 이미 저장된 상태이므로 조용히 무시하지 않고 스낵바로 별도 안내한다.
  Future<void> _analyzePhoto({
    required int diaryId,
    required Uint8List photoBytes,
    String? photoFileName,
  }) async {
    setState(() {
      _analyzing = true;
      _lastAnalysisTag = null;
    });
    try {
      final result = await _visionRepository.analyzeImage(
        imageBytes: photoBytes,
        imageFileName: photoFileName ?? 'upload.jpg',
        diaryId: diaryId,
      );
      if (!mounted) return;
      setState(() => _lastAnalysisTag = result.resultTag);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 분석 완료: ${result.resultTag}')),
      );
    } on ApiException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('분석에 실패했지만 일지는 저장되었습니다')),
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as GrowerDiaryWriteArgs;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: _buildBody(args.seedlingId),
      ),
    );
  }

  Widget _buildBody(int seedlingId) {
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
          '무화과 #$seedlingId',
          style: AppTextStyles.body(
            fontSize: 13,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _choosePhotoSource,
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
                label: _stages[i].$1,
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
          onPressed: () => _submit(seedlingId),
          loading: _submitting,
        ),
        if (_analyzing) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.pink500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI가 사진을 분석하고 있어요...',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ] else if (_lastAnalysisTag != null) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.badgeGreenBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'AI 분석 결과: $_lastAnalysisTag',
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.badgeGreenText,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
      ],
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
