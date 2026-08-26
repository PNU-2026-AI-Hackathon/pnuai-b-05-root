import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/season_badge.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/gauge_bar.dart';
import '../../../shared/widgets/photo_source_dialog.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/grower_repository.dart';

/// `/grower/complete` route argument: 묘목 분석 화면(`GrowerSeedlingAnalysisScreen`)에서
/// 넘어온 담당 묘목 정보.
class GrowerCompleteArgs {
  const GrowerCompleteArgs({
    required this.seedlingId,
    required this.seedlingName,
    required this.adopterName,
  });

  final int seedlingId;
  final String seedlingName;
  final String adopterName;
}

/// 30cm 미만이면 경고를 보여주는 기준(완성 신고 자체는 막지 않음 — 재배자 판단).
const _minRecommendedHeightCm = 30;

/// 1u — 묘목 완성 신고: 최종 키 입력 + 최종 사진(선택) 업로드 후
/// `PATCH /api/seedlings/{id}/complete/` 호출.
class GrowerCompleteScreen extends StatefulWidget {
  const GrowerCompleteScreen({super.key});

  @override
  State<GrowerCompleteScreen> createState() => _GrowerCompleteScreenState();
}

class _GrowerCompleteScreenState extends State<GrowerCompleteScreen> {
  final _repository = GrowerRepository();
  final _heightController = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = false;
  String? _errorMessage;
  Uint8List? _photoBytes;
  String? _photoFileName;

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  /// 입력된 키(cm). 비었거나 숫자가 아니면 null.
  int? get _heightCm => int.tryParse(_heightController.text.trim());

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
      if (!mounted) return;
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

  Future<void> _submit(GrowerCompleteArgs args) async {
    final heightCm = _heightCm;
    if (heightCm == null || heightCm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('완성된 키(cm)를 입력해주세요')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedling = await _repository.completeSeedling(
        seedlingId: args.seedlingId,
        heightCm: heightCm,
        photoBytes: _photoBytes,
        photoFileName: _photoFileName,
      );
      if (!mounted) return;
      final completedAt = seedling.completedAt;
      final message = completedAt == null
          ? '${args.seedlingName} 완성 신고를 보냈어요 🎉'
          : '${args.seedlingName} 완성! ${seasonCompletionPhrase(completedAt)}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as GrowerCompleteArgs;
    final heightCm = _heightCm;
    final showHeightWarning =
        heightCm != null && heightCm > 0 && heightCm < _minRecommendedHeightCm;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎉 묘목 완성 신고',
                style: AppTextStyles.title(
                  fontSize: 20,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${args.seedlingName} · ${args.adopterName}님에게 알림이 가요',
                style: AppTextStyles.guide(
                  fontSize: 14,
                  color: AppColors.badgeGreenText,
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  children: [
                    Text(
                      '완성 단계',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const GaugeBar(value: 1.0, height: 12),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '5/5단계 완료!',
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.badgeGreenText,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '완성된 키',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onChanged: (_) => setState(() {}),
                            style: AppTextStyles.title(fontSize: 22),
                            decoration: InputDecoration(
                              // 화면 톤에 맞춰 앱 기본 테마의 흰 배경·라운드 테두리를
                              // 걷어내고, _Card 안에 밑줄 없는 큰 숫자 입력으로 둔다.
                              isCollapsed: true,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: '예: 34',
                              hintStyle: AppTextStyles.body(
                                fontSize: 20,
                                color: const Color(0xFFB7B2A4),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'cm',
                          style: AppTextStyles.body(
                            fontSize: 15,
                            color: AppColors.textMuted,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (showHeightWarning) ...[
                      const SizedBox(height: 8),
                      Text(
                        '30cm 미만이에요 — 조금 더 키우는 걸 권하지만, '
                        '완성이 맞다면 그대로 신고할 수 있어요',
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.warningPink,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                      ? const _PhotoPlaceholder()
                      : _PhotoPreview(bytes: _photoBytes!),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.errorRed,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PigFigButton.primary(
                label: '완성 신고하기 🎉',
                onPressed: () => _submit(args),
                loading: _loading,
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// 완성 신고 화면에서 반복되는 흰 라운드 카드(그림자 포함).
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

/// 사진을 아직 안 고른 상태의 점선(근사) 테두리 박스.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBE5C4), width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const FigTreeIllustration(width: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '최종 사진 업로드 📷 (선택)',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.badgeGreenText,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '완성된 모습을 찍어주세요\n인증서에 일러스트로 실려요',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: const Color(0xFFB7B2A4),
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 사진을 고른 뒤의 미리보기(탭하면 다시 선택).
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Image.memory(
            bytes,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '탭해서 변경',
                style: AppTextStyles.body(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
