import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import 'donation_certificate_screen.dart';

enum _Choice { pickup, donate }

class _Organization {
  const _Organization({
    required this.emoji,
    required this.name,
    required this.detail,
  });

  final String emoji;
  final String name;
  final String detail;
}

/// 1o — 수령/기부 선택. mock UI(선택 상태만 로컬로 관리하며 API 연동은 하지 않는다).
class PickupDonateScreen extends StatefulWidget {
  const PickupDonateScreen({super.key});

  @override
  State<PickupDonateScreen> createState() => _PickupDonateScreenState();
}

class _PickupDonateScreenState extends State<PickupDonateScreen> {
  static const _seedlingName = '무화과 #001';
  static const _organizations = [
    _Organization(
      emoji: '🧒',
      name: '행복 지역아동센터',
      detail: '도보 10분 · 아이들 원예 수업에 사용',
    ),
    _Organization(emoji: '🏥', name: '푸른 종합복지관', detail: '차량 15분 · 로비 정원 조성'),
    _Organization(emoji: '🏡', name: '은빛 경로당', detail: '도보 5분 · 어르신 텃밭에 식재'),
  ];

  _Choice _choice = _Choice.donate;
  int _selectedOrgIndex = 0;

  void _submit() {
    Navigator.of(context).pushNamed(
      '/adopter/donation-certificate',
      arguments: DonationCertificateArgs(
        seedlingName: _seedlingName,
        organizationName: _organizations[_selectedOrgIndex].name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDonate = _choice == _Choice.donate;

    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Text(
                  '다 자란 무화과,\n어떻게 할까요?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(
                    fontSize: 28,
                    color: const Color(0xFFF7A0AE),
                  ).copyWith(letterSpacing: 2.8),
                ),
                const SizedBox(height: 6),
                Text(
                  '묘목 완성! 수령하거나 기부할 수 있어요 🎉',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.badgeGreenText,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ChoiceCard(
                    emoji: '🧺',
                    title: '직접 수령',
                    description: '재배 상가에서\n픽업해요',
                    selected: !isDonate,
                    onTap: () => setState(() => _choice = _Choice.pickup),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ChoiceCard(
                    emoji: '🎁',
                    title: '기부하기',
                    description: '따뜻한 곳으로\n보내요',
                    selected: isDonate,
                    onTap: () => setState(() => _choice = _Choice.donate),
                  ),
                ),
              ],
            ),
            if (isDonate) ...[
              const SizedBox(height: 16),
              Text(
                '기부처를 골라주세요',
                style: AppTextStyles.title(
                  fontSize: 15,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  for (var i = 0; i < _organizations.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _OrganizationRow(
                      organization: _organizations[i],
                      selected: i == _selectedOrgIndex,
                      onTap: () => setState(() => _selectedOrgIndex = i),
                    ),
                  ],
                ],
              ),
            ],
            const Spacer(),
            if (isDonate) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: PigFigButton.primary(
                  label: '기부하고 인증서 받기 📜',
                  onPressed: _submit,
                ),
              ),
            ] else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = selected
        ? AppColors.badgePinkText
        : AppColors.textPrimary;
    final descColor = selected ? AppColors.badgePinkText : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFDEFF2) : Colors.white,
              border: Border.all(
                color: selected ? AppColors.pink500 : AppColors.outline,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: AppTextStyles.title(
                    fontSize: 15,
                    color: titleColor,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: descColor,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: -10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pink500,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '선택됨 ✓',
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrganizationRow extends StatelessWidget {
  const _OrganizationRow({
    required this.organization,
    required this.selected,
    required this.onTap,
  });

  final _Organization organization;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: selected ? AppColors.green500 : const Color(0xFFEEEBDF),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.badgeGreenBg
                    : const Color(0xFFF7F5EC),
                shape: BoxShape.circle,
              ),
              child: Text(
                organization.emoji,
                style: const TextStyle(fontSize: 19),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organization.name,
                    style: AppTextStyles.body(
                      fontSize: 14,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    organization.detail,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.green500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
