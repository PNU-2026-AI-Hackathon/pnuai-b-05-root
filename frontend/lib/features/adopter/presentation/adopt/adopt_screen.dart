import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/fig_tree_illustration.dart';
import '../../../../shared/widgets/pigfig_app_bar.dart';
import '../../../../shared/widgets/pigfig_button.dart';
import '../../data/seedling_repository.dart';

/// 무화과 입양(결제) 화면. 실제 PG 연동 없이 mock 결제 성공 처리 후
/// `POST /api/seedlings/`로 실제 묘목을 생성한다(재배자는 서버가 자동 배정).
class AdoptScreen extends StatefulWidget {
  const AdoptScreen({super.key});

  @override
  State<AdoptScreen> createState() => _AdoptScreenState();
}

class _AdoptScreenState extends State<AdoptScreen> {
  final _repository = SeedlingRepository();
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700)); // mock 결제 처리 시간
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('결제가 완료되었습니다 💳')));
    try {
      await _repository.createSeedling();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '🌱 무화과 입양하기',
              style: AppTextStyles.title(
                fontSize: 20,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
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
                  const FigTreeIllustration(width: 100),
                  const SizedBox(height: 16),
                  Text(
                    '무화과를 입양하면\n재배자가 정성껏 키워드려요',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '도심 유휴공간에서 재배자가 직접 키우고,\n다 자라면 수령하거나 기부할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '무화과 묘목 입양',
                    style: AppTextStyles.body(
                      fontSize: 14,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '19,900원',
                    style: AppTextStyles.title(
                      fontSize: 18,
                      color: AppColors.pink500,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PigFigButton.primary(
              label: '결제하기',
              onPressed: _pay,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
