import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/gauge_bar.dart';
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

/// 1u — 묘목 완성 신고: 체크리스트 확인 후 `PATCH /api/seedlings/{id}/complete/` 호출.
class GrowerCompleteScreen extends StatefulWidget {
  const GrowerCompleteScreen({super.key});

  @override
  State<GrowerCompleteScreen> createState() => _GrowerCompleteScreenState();
}

class _GrowerCompleteScreenState extends State<GrowerCompleteScreen> {
  final _repository = GrowerRepository();
  bool _loading = false;
  String? _errorMessage;

  static const _checklist = [
    ('수고(키) 30cm 이상', '34cm'),
    ('잎 10장 이상', '13장'),
    ('가지 3개 이상', '4개'),
  ];

  Future<void> _submit(GrowerCompleteArgs args) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _repository.completeSeedling(args.seedlingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${args.seedlingName} 완성 신고를 보냈어요 🎉')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as GrowerCompleteArgs;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
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
            Container(
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
            GestureDetector(
              onTap: _showComingSoon,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFCBE5C4),
                      width: 2,
                    ),
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
                              '최종 사진 업로드 📷',
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
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                children: [
                  for (var i = 0; i < _checklist.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        border: i == _checklist.length - 1
                            ? null
                            : const Border(
                                bottom: BorderSide(color: Color(0xFFF3F1E9)),
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.green500,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _checklist[i].$1,
                              style: AppTextStyles.body(
                                fontSize: 14,
                              ).copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            _checklist[i].$2,
                            style: AppTextStyles.body(
                              fontSize: 13,
                              color: AppColors.badgeGreenText,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
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
            const Spacer(),
            PigFigButton.primary(
              label: '완성 신고하기 🎉',
              onPressed: () => _submit(args),
              loading: _loading,
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
