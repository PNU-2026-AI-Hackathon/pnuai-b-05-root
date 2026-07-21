import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/presentation/account_actions.dart';
import '../data/grower_repository.dart';

/// 재배자용 마이 탭: 프로필 카드(이메일 + 담당 묘목 수) + 로그아웃/회원탈퇴.
/// `GrowerDashboardScreen` 앱바에 있던 사람 아이콘 진입점을 이 탭으로 대체했다.
class GrowerMypageScreen extends StatefulWidget {
  const GrowerMypageScreen({super.key});

  @override
  State<GrowerMypageScreen> createState() => _GrowerMypageScreenState();
}

class _GrowerMypageScreenState extends RevalidatableState<GrowerMypageScreen> {
  final _repository = GrowerRepository();

  bool _loading = true;
  bool _hasLoadedOnce = false;
  String? _email;
  int _seedlingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final email = await TokenStorage().readEmail();
    var seedlingCount = 0;
    try {
      final seedlings = await _repository.fetchSeedlings();
      seedlingCount = seedlings.length;
    } on ApiException {
      // 목록 조회가 실패해도 이메일/로그아웃 기능은 그대로 쓸 수 있어야 하므로
      // 담당 묘목 수만 0으로 두고 화면 자체는 정상 표시한다.
    }
    if (!mounted) return;
    setState(() {
      _email = email;
      _seedlingCount = seedlingCount;
      _loading = false;
    });
    _hasLoadedOnce = true;
  }

  /// `GrowerShell`이 마이 탭 재진입 시 호출한다. 다른 탭에서 묘목 상태가 바뀌었을
  /// 수 있으니 담당 묘목 수를 다시 불러오되, 기존 화면은 그대로 둔 채 응답이 오면
  /// 조용히 교체한다.
  @override
  Future<void> revalidate() async {
    if (!_hasLoadedOnce) return _load();
    try {
      final seedlings = await _repository.fetchSeedlings();
      if (mounted) setState(() => _seedlingCount = seedlings.length);
    } on ApiException {
      // 재조회 실패 시 기존 값을 그대로 유지한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(showNotificationBell: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          children: [
            _loading
                ? const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: CircularProgressIndicator(color: AppColors.pink500),
                  )
                : _ProfileCard(
                    email: _email ?? '알 수 없음',
                    seedlingCount: _seedlingCount,
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
  const _ProfileCard({required this.email, required this.seedlingCount});

  final String email;
  final int seedlingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.pink100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: AppTextStyles.title(
              fontSize: 16,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          StatusBadge(
            label: '담당 묘목 $seedlingCount그루 🌱',
            background: AppColors.badgeGreenBg,
            textColor: AppColors.badgeGreenText,
            pill: false,
          ),
        ],
      ),
    );
  }
}
