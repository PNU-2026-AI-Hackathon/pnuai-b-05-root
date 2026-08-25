import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../data/seedling_repository.dart';
import 'donation_certificate_screen.dart';

/// 기부 인증서 목록: 완료 + 기부 확정된 묘목 전체를 완료일 내림차순으로 보여준다.
/// 카드를 탭하면 해당 묘목의 인증서 상세(donation_certificate_screen.dart)로 이동한다
/// — adoption_history_screen.dart와 달리 이 화면은 각 인증서를 보러 가는 진입점 자체가
/// 목적이라 카드에 탭 동작이 있다.
class DonationCertificateListScreen extends StatefulWidget {
  const DonationCertificateListScreen({super.key});

  @override
  State<DonationCertificateListScreen> createState() =>
      _DonationCertificateListScreenState();
}

class _DonationCertificateListScreenState
    extends State<DonationCertificateListScreen> {
  final _repository = SeedlingRepository();

  bool _loading = true;
  String? _errorMessage;
  List<Seedling> _seedlings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final seedlings = await _repository.fetchSeedlings();
      setState(
        () => _seedlings = filterSeedlingsForDonationCertificates(seedlings),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCertificate(Seedling seedling) {
    Navigator.of(context).pushNamed(
      '/adopter/donation-certificate',
      arguments: DonationCertificateArgs(
        seedlingName: '무화과 #${seedling.id}',
        organizationName: seedling.donateType?.label ?? '',
        startedAt: seedling.startedAt,
        completedAt: seedling.completedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📜 기부 인증서',
              style: AppTextStyles.title(
                fontSize: 20,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '지금까지 발급된 기부 인증서를 모두 확인할 수 있어요',
              style: AppTextStyles.guide(
                fontSize: 14,
                color: AppColors.badgeGreenText,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink500),
      );
    }
    if (_errorMessage != null) {
      return _MessageState(
        emoji: '😢',
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    if (_seedlings.isEmpty) {
      return const _MessageState(
        emoji: '📜',
        message: '아직 발급된 기부 인증서가 없어요',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _seedlings.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final seedling = _seedlings[index];
        return _CertificateListCard(
          seedling: seedling,
          onTap: () => _openCertificate(seedling),
        );
      },
    );
  }
}

class _CertificateListCard extends StatelessWidget {
  const _CertificateListCard({required this.seedling, required this.onTap});

  final Seedling seedling;
  final VoidCallback onTap;

  static String _formatCompletedAt(DateTime? date) {
    if (date == null) return '완료일 정보 없음';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')} 완료';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '무화과 #${seedling.id} 🎁',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      seedling.donateType?.label ?? '기부처 정보 없음',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.badgePinkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCompletedAt(seedling.completedAt),
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.emoji, required this.message, this.onRetry});

  final String emoji;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }
}
