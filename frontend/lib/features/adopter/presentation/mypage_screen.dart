import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/presentation/account_actions.dart';
import '../data/seedling_repository.dart';
import 'account_settings_dialog.dart';
import 'donation_certificate_screen.dart';

/// 1n — 마이페이지: 프로필 카드(실제 닉네임/이메일/입양 그루 수) + 2x2 서비스 카드.
class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});

  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends RevalidatableState<MypageScreen> {
  final _seedlingRepository = SeedlingRepository();

  bool _loading = true;
  bool _hasLoadedOnce = false;
  // 서버/로컬에 저장된 원본 값(빈 문자열일 수 있음). 화면 표시용 대체 문구
  // ("입양자")는 build()에서만 계산해, 실제 닉네임이 우연히 그 문구와 같은
  // 경우에도 "값이 비어있다"는 사실과 섞이지 않게 한다.
  String _nickname = '';
  String? _email;
  int _seedlingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final nickname = await TokenStorage().readNickname();
    final email = await TokenStorage().readEmail();
    var count = 0;
    try {
      count = (await _seedlingRepository.fetchSeedlings()).length;
    } on ApiException {
      // 목록 조회가 실패해도 프로필 표시/로그아웃 등은 그대로 써야 하므로
      // 입양 그루 수만 0으로 두고 화면 자체는 정상 표시한다.
    }
    if (!mounted) return;
    setState(() {
      _nickname = nickname ?? '';
      _email = email;
      _seedlingCount = count;
      _loading = false;
    });
    _hasLoadedOnce = true;
  }

  /// `AdopterShell`이 마이 탭 재진입 시 호출한다. 다른 탭(무화과 입양 등)에서
  /// 묘목 개수가 바뀌었을 수 있으니 다시 불러오되, 기존 화면은 그대로 둔 채
  /// 응답이 오면 조용히 교체한다.
  @override
  Future<void> revalidate() async {
    if (!_hasLoadedOnce) return _load();
    try {
      final seedlings = await _seedlingRepository.fetchSeedlings();
      if (mounted) setState(() => _seedlingCount = seedlings.length);
    } on ApiException {
      // 재조회 실패 시 기존 값을 그대로 유지한다.
    }
  }

  Future<void> _openSettings() async {
    final newNickname = await showAccountSettingsDialog(
      context,
      initialNickname: _nickname,
    );
    if (newNickname == null || !mounted) return;
    setState(() => _nickname = newNickname);
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _loading
                ? const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.pink500,
                      ),
                    ),
                  )
                : _ProfileCard(
                    nickname: _nickname.isEmpty ? '입양자' : _nickname,
                    email: _email ?? '알 수 없음',
                    seedlingCount: _seedlingCount,
                    onSettingsTap: _openSettings,
                  ),
            const SizedBox(height: 22),
            Text('주요 서비스', style: AppTextStyles.title(fontSize: 16)),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ServiceCard(
                      emoji: '🎁',
                      iconBg: AppColors.green500,
                      title: '수령 / 기부 선택',
                      description: '완성된 무화과 수령 방법을 선택해요',
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed('/adopter/pickup-donate'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ServiceCard(
                      emoji: '📜',
                      iconBg: AppColors.pink100,
                      title: '기부 인증서',
                      description: '기부 나눔 인증서를 확인해요',
                      onTap: () => Navigator.of(context).pushNamed(
                        '/adopter/donation-certificate',
                        arguments: const DonationCertificateArgs(
                          seedlingName: '무화과 #001',
                          organizationName: '행복 지역아동센터',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ServiceCard(
                      emoji: '🤖',
                      iconBg: AppColors.green500,
                      title: 'AI 챗봇 (무화과 Q&A)',
                      description: '무화과 재배 궁금증을 물어보세요',
                      onTap: () =>
                          Navigator.of(context).pushNamed('/adopter/chatbot'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ServiceCard(
                      emoji: '📋',
                      iconBg: AppColors.green500,
                      title: '입양 내역서',
                      description: '나의 입양 내역을 확인해요',
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: () => confirmLogout(context),
                child: Text(
                  '로그아웃',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => confirmDeleteAccount(context),
                child: Text(
                  '회원탈퇴',
                  style: AppTextStyles.caption(
                    fontSize: 12,
                    color: AppColors.textCaption,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.nickname,
    required this.email,
    required this.seedlingCount,
    required this.onSettingsTap,
  });

  final String nickname;
  final String email;
  final int seedlingCount;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.pink100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      nickname,
                      style: AppTextStyles.title(
                        fontSize: 17,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    StatusBadge(
                      label: '입양 중: $seedlingCount그루 🌱',
                      background: AppColors.badgeGreenBg,
                      textColor: AppColors.badgeGreenText,
                      pill: false,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.emoji,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String emoji;
  final Color iconBg;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.body(
                fontSize: 14,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.caption(
                fontSize: 12,
                color: AppColors.textMuted,
              ).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
