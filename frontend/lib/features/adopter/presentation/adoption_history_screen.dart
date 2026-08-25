import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/seedling_repository.dart';

/// 1q — 입양 내역서: 입양자가 지금까지 입양한 묘목 전체(재배중/완료 모두)를
/// 최근 입양 순으로 나열한다. 카드는 정보 열람 전용이라 탭 동작이 없고,
/// 완료+기부확정 묘목의 상세(인증서)는 마이페이지의 별도 카드
/// (donation_certificate_screen.dart)로 이미 존재해 여기서는 중복 진입점을
/// 만들지 않는다.
class AdoptionHistoryScreen extends StatefulWidget {
  const AdoptionHistoryScreen({super.key});

  @override
  State<AdoptionHistoryScreen> createState() => _AdoptionHistoryScreenState();
}

class _AdoptionHistoryScreenState extends State<AdoptionHistoryScreen> {
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
      seedlings.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      setState(() => _seedlings = seedlings);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goToAdopt() async {
    await Navigator.of(context).pushNamed('/adopter/adopt');
    // 새로 입양했는지 여부와 무관하게 최신 목록을 다시 불러온다.
    if (mounted) _load();
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
              '📋 입양 내역서',
              style: AppTextStyles.title(
                fontSize: 20,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '지금까지 입양한 무화과를 모두 확인할 수 있어요',
              style: AppTextStyles.guide(
                fontSize: 14,
                color: AppColors.badgeGreenText,
              ),
            ),
            const SizedBox(height: 14),
            PigFigButton.positive(label: '새로 입양하기 🌱', onPressed: _goToAdopt),
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
      return const _MessageState(emoji: '🌱', message: '아직 입양한 무화과가 없어요');
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _seedlings.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _SeedlingHistoryCard(seedling: _seedlings[index]),
    );
  }
}

class _SeedlingHistoryCard extends StatelessWidget {
  const _SeedlingHistoryCard({required this.seedling});

  final Seedling seedling;

  static String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.'
      '${date.day.toString().padLeft(2, '0')}';

  String _buildPeriodText() {
    if (seedling.status == SeedlingStatus.growing) {
      return '${_formatDate(seedling.startedAt)} ~ 재배중';
    }
    final completedAt = seedling.completedAt;
    // status가 completed인데 completedAt이 없는 경우(과거 데이터 등)를
    // 대비해 계산 대신 안전한 폴백 문구를 보여준다.
    if (completedAt == null) return '기간 정보 없음';
    return '${_formatDate(seedling.startedAt)} ~ ${_formatDate(completedAt)}';
  }

  String _buildChoiceText() {
    switch (seedling.pickupOrDonate) {
      case PickupOrDonateChoice.pickup:
        return '수령 완료 🧺';
      case PickupOrDonateChoice.donate:
        final label = seedling.donateType?.label;
        return label == null ? '기부 완료 🎁' : '기부 완료 🎁 · $label';
      case null:
        return '수령/기부 미선택';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGrowing = seedling.status == SeedlingStatus.growing;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '무화과 #${seedling.id} 🌱',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(),
                ),
              ),
              StatusBadge(
                label: isGrowing ? '재배중' : '완료',
                background: isGrowing ? AppColors.green500 : AppColors.pink100,
                textColor: isGrowing ? Colors.white : AppColors.badgePinkText,
                pill: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _buildPeriodText(),
            style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
          ),
          if (!isGrowing) ...[
            const SizedBox(height: 6),
            Text(
              _buildChoiceText(),
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
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
