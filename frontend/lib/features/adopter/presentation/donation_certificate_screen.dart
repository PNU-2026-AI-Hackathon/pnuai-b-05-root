import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pig_character.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';

/// `/adopter/donation-certificate` route argument.
class DonationCertificateArgs {
  const DonationCertificateArgs({
    required this.seedlingName,
    required this.organizationName,
    this.startedAt,
    this.completedAt,
  });

  final String seedlingName;
  final String organizationName;
  // 과거 데이터 등으로 하나라도 없을 수 있어 nullable로 받는다 — 없으면
  // "함께한 N일" 계산 대신 안전한 폴백 문구를 보여준다.
  final DateTime? startedAt;
  final DateTime? completedAt;
}

/// 입양자가 실제로 함께한 기간을 "YYYY. MM. DD · 함께한 N일" 형식으로 만든다.
/// `startedAt`/`completedAt` 중 하나라도 없으면(과거 데이터 등) 계산을 시도하지
/// 않고 안전한 폴백 문구를 돌려준다.
String formatCertificatePeriod(DateTime? startedAt, DateTime? completedAt) {
  if (startedAt == null || completedAt == null) return '기간 정보 없음';
  final days = completedAt.difference(startedAt).inDays;
  final y = completedAt.year.toString().padLeft(4, '0');
  final m = completedAt.month.toString().padLeft(2, '0');
  final d = completedAt.day.toString().padLeft(2, '0');
  return '$y. $m. $d · 함께한 $days일';
}

/// 1p — 기부 인증서: 디지털 발급 화면. 입양자 닉네임은 실제 로그인 계정 값을
/// 조회해 보여준다(이미지 저장/공유는 여전히 준비 중, 이번 범위 아님).
/// `ModalRoute` 인자 읽기 + 닉네임 로드만 담당하는 얇은 wrapper이며, 실제
/// 콘텐츠는 [DonationCertificateCard]가 그린다.
class DonationCertificateScreen extends StatefulWidget {
  const DonationCertificateScreen({super.key});

  @override
  State<DonationCertificateScreen> createState() =>
      _DonationCertificateScreenState();
}

class _DonationCertificateScreenState
    extends State<DonationCertificateScreen> {
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final nickname = await TokenStorage().readNickname();
    if (!mounted) return;
    setState(() => _nickname = nickname ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as DonationCertificateArgs;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: DonationCertificateCard(args: args, nickname: _nickname),
    );
  }
}

/// 기부 인증서 카드 콘텐츠 — 단독 라우트(`DonationCertificateScreen`)와
/// 기부 인증서 목록 화면의 카드 모드(세로 `PageView`) 양쪽에서 재사용된다.
/// `ModalRoute`에 의존하지 않고 필요한 데이터를 전부 생성자로 받는다.
class DonationCertificateCard extends StatelessWidget {
  const DonationCertificateCard({
    super.key,
    required this.args,
    required this.nickname,
  });

  final DonationCertificateArgs args;
  final String nickname;

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    final displayName = nickname.isEmpty ? '입양자' : nickname;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 26,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.pink500,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    '🌸 ⁂ 🌸',
                    style: AppTextStyles.body(
                      fontSize: 15,
                      color: AppColors.pink500,
                    ).copyWith(letterSpacing: 4.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '기부 인증서',
                    style: AppTextStyles.display(
                      fontSize: 34,
                    ).copyWith(letterSpacing: 34 * 0.16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'CERTIFICATE OF DONATION',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: const Color(0xFFB7B2A4),
                    ).copyWith(letterSpacing: 2.16),
                  ),
                  const SizedBox(height: 6),
                  const _CertificateTreeIcon(),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: const Color(0xFF6B675C),
                      ).copyWith(height: 1.8),
                      children: [
                        TextSpan(
                          text: displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' 님이 정성으로 키운\n'),
                        TextSpan(
                          text: args.seedlingName,
                          style: const TextStyle(
                            color: AppColors.badgeGreenText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' 을(를)\n'),
                        TextSpan(
                          text: args.organizationName,
                          style: const TextStyle(
                            color: AppColors.badgePinkText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '에 기부하였습니다.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatCertificatePeriod(args.startedAt, args.completedAt),
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: const Color(0xFFB7B2A4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const PigCharacter(width: 34),
                      const SizedBox(width: 8),
                      Text(
                        'Pig.Fig.',
                        style: AppTextStyles.display(
                          fontSize: 18,
                        ).copyWith(letterSpacing: 18 * 0.12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => _showComingSoon(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6B675C),
                      side: const BorderSide(
                        color: AppColors.outline,
                        width: 1.5,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      '이미지 저장',
                      style: AppTextStyles.button(
                        fontSize: 14,
                        color: const Color(0xFF6B675C),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => _showComingSoon(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green500,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      '공유하기',
                      style: AppTextStyles.button(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '마이페이지 > 기부 인증서에서 다시 볼 수 있어요',
            style: AppTextStyles.body(
              fontSize: 12,
              color: const Color(0xFFB7B2A4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 인증서 안의 미니 무화과나무 + 메달 아이콘.
class _CertificateTreeIcon extends StatelessWidget {
  const _CertificateTreeIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 88,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 8,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.green800,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 6,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF456B3A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 11,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brown600,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Positioned(
            right: -12,
            bottom: -2,
            child: Text('🎖️', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}
