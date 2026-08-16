import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/support_contact.dart';
import '../../../core/network/api_client.dart';
import '../../../core/revalidatable_state.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
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
            PigFigButton.outline(
              label: '📅 나의 재배 활동 보기',
              onPressed: () => Navigator.of(
                context,
              ).pushNamed('/grower/activity-calendar'),
            ),
            const SizedBox(height: 14),
            _HelpSection(onTap: () => _showHelpSheet(context)),
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

/// 시니어 재배자가 헷갈릴 때 바로 누를 수 있는 큼직한 도움 요청 버튼 섹션.
/// 작은 아이콘 버튼(`CareActionButton` 등)과 달리 가로 전체 폭 + 큰 글씨로
/// 탭 실수를 줄인다.
class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '도움이 필요하신가요?',
          textAlign: TextAlign.center,
          style: AppTextStyles.title(fontSize: 15),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: Text(
              '🆘 도움 요청하기',
              style: AppTextStyles.title(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// "도움 요청하기"를 누르면 뜨는 바텀시트 — 전화/문자 중 하나를 고르면 실제
/// 전화·문자 앱을 실행한다. 시니어가 잘못 누르지 않도록 옵션마다 탭 영역을
/// 크게(높이 60) 잡는다.
Future<void> _showHelpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '어떻게 도와드릴까요?',
              textAlign: TextAlign.center,
              style: AppTextStyles.title(fontSize: 18),
            ),
            const SizedBox(height: 20),
            _HelpOptionButton(
              emoji: '📞',
              label: '전화 걸기',
              background: AppColors.pink500,
              onTap: () => _launchContact(sheetContext, scheme: 'tel'),
            ),
            const SizedBox(height: 14),
            _HelpOptionButton(
              emoji: '💬',
              label: '문자 보내기',
              background: AppColors.green500,
              onTap: () => _launchContact(sheetContext, scheme: 'sms'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 바텀시트 안의 전화/문자 옵션 버튼. [_HelpSection]의 진입 버튼과 마찬가지로
/// 아이콘 + 큰 텍스트 조합으로 탭 영역과 가독성을 키운다.
class _HelpOptionButton extends StatelessWidget {
  const _HelpOptionButton({
    required this.emoji,
    required this.label,
    required this.background,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.title(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// [scheme]('tel'/'sms')으로 [SupportContact.phoneNumber]를 열어 실제 전화/문자
/// 앱을 실행한다. 바텀시트를 먼저 닫은 뒤 시도하며, 실행 앱이 없는 환경(웹 등)
/// 이거나 launchUrl 자체가 예외를 던져도 앱이 죽지 않도록 try-catch로 감싸고
/// 실패 시 스낵바로만 안내한다. `await` 전에 `ScaffoldMessenger`를 미리 잡아둬
/// 바텀시트가 닫혀 [sheetContext]가 무효해진 뒤에도 안내를 띄울 수 있게 한다.
Future<void> _launchContact(
  BuildContext sheetContext, {
  required String scheme,
}) async {
  final messenger = ScaffoldMessenger.of(sheetContext);
  Navigator.of(sheetContext).pop();
  final uri = Uri(scheme: scheme, path: SupportContact.phoneNumber);
  try {
    final launched = await launchUrl(uri);
    if (!launched) {
      messenger.showSnackBar(const SnackBar(content: Text('연결할 수 없어요')));
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('연결할 수 없어요')));
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
