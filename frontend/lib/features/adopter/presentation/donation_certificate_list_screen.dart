import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
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
  // 카드 모드가 기본값 — donation_certificate_screen.dart와 동일한 인증서
  // 디자인을 세로 스와이프로 보여준다. "자세히" 아이콘을 누르면 기존 목록형으로 전환.
  bool _isCardMode = true;
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadNickname();
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

  // 카드 모드의 모든 인증서가 같은 로그인 계정 닉네임을 쓰므로, 인증서마다
  // 다시 조회하지 않고 한 번만 불러와 DonationCertificateCard에 내려준다.
  Future<void> _loadNickname() async {
    final nickname = await TokenStorage().readNickname();
    if (!mounted) return;
    setState(() => _nickname = nickname ?? '');
  }

  void _openCertificate(Seedling seedling) {
    Navigator.of(context).pushNamed(
      '/adopter/donation-certificate',
      arguments: DonationCertificateArgs(
        seedlingId: seedling.id,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                      ],
                    ),
                  ),
                  _ViewModeToggle(
                    isCardMode: _isCardMode,
                    onChanged: (isCardMode) =>
                        setState(() => _isCardMode = isCardMode),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(child: _buildBody()),
            ],
          ),
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
    return _isCardMode ? _buildCardMode() : _buildListMode();
  }

  // "아주 큰 아이콘" 모드 — donation_certificate_screen.dart와 동일한 인증서
  // 카드를 화면 가득 채워 보여주고, 위아래로 스와이프해 다음/이전 인증서로 넘긴다.
  Widget _buildCardMode() {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _seedlings.length,
      itemBuilder: (context, index) {
        final seedling = _seedlings[index];
        return DonationCertificateCard(
          // 카드가 stateful이라(저장/공유 로딩 상태) 세로 스와이프로 페이지
          // element가 재사용될 때 이전 묘목의 상태가 새지 않도록 키를 고정한다.
          key: ValueKey(seedling.id),
          args: DonationCertificateArgs(
            seedlingId: seedling.id,
            seedlingName: '무화과 #${seedling.id}',
            organizationName: seedling.donateType?.label ?? '',
            startedAt: seedling.startedAt,
            completedAt: seedling.completedAt,
          ),
          nickname: _nickname,
        );
      },
    );
  }

  // "자세히" 모드 — 요약 정보만 나열하는 기존 목록형 뷰(변경 없음).
  Widget _buildListMode() {
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

/// 우측 상단 보기 모드 전환 아이콘 2개 — Windows 탐색기의 "아주 큰 아이콘"/
/// "자세히" 버튼과 같은 개념. 선택된 쪽만 진한 색으로 강조한다.
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.isCardMode, required this.onChanged});

  final bool isCardMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewModeIconButton(
          icon: Icons.view_agenda_outlined,
          tooltip: '카드로 보기',
          selected: isCardMode,
          onPressed: () => onChanged(true),
        ),
        _ViewModeIconButton(
          icon: Icons.view_list_outlined,
          tooltip: '자세히 보기',
          selected: !isCardMode,
          onPressed: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ViewModeIconButton extends StatelessWidget {
  const _ViewModeIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      color: selected ? AppColors.pink500 : AppColors.textMuted,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? AppColors.pink500.withValues(alpha: 0.12)
            : Colors.transparent,
      ),
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
