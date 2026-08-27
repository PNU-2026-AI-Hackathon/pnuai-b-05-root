import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fig_tree_illustration.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../data/seedling_repository.dart';
import 'donation_certificate_screen.dart';

enum _Choice { pickup, donate }

/// 픽업 장소(부산대학교 IT관) 좌표. 공개 도로 주소(부산광역시 금정구 부산대학로63번길 2)를
/// OpenStreetMap Nominatim으로 지오코딩한 근사값이며, 정밀 검증은 별도로 필요하다.
const _pickupLat = 35.2304;
const _pickupLng = 129.0840;
const _pickupAddress = '부산대학교 IT관';

/// 픽업 장소 정적 지도 이미지. 처음엔 Wikimedia Maps 정적 이미지 엔드포인트를 매 요청마다
/// 네트워크로 불러왔으나, 국내 일부 통신망(LTE)에서 위키미디어 도메인 접속이 불안정해 지도가
/// 아예 뜨지 않는 사례가 실기기에서 확인됐다. 픽업 장소는 고정 정보라 바뀔 일이 없으므로,
/// 같은 URL(zoom 17, 640x320)로 한 번 받아온 이미지를 앱에 내장 asset으로 번들링해 네트워크
/// 의존을 없앴다(`_PickupLocationMap` 참고). 지도 위 핀은 여전히 Flutter가 직접 그려 겹친다.
const _staticMapAsset = 'assets/images/pickup_location_map.png';

final _googleMapsUrl =
    'https://www.google.com/maps/search/?api=1&query=$_pickupLat,$_pickupLng';

class _Organization {
  const _Organization({
    required this.emoji,
    required this.name,
    required this.detail,
    required this.donateType,
    this.url,
  });

  final String emoji;
  final String name;
  final String detail;
  final DonateType donateType;
  /// 카테고리를 더 알아볼 수 있는 외부 링크. 앱 내부 기능인 "앱 내 나눔 분양"은 null.
  final String? url;
}

/// 계획서 기준 기부처 3개 카테고리. `Seedling.DonateType`(backend TextChoices)과 1:1 대응한다.
const _organizations = [
  _Organization(
    emoji: '🏫',
    name: '초등학교·복지시설 기증',
    detail: '지역 초등학교나 복지시설에 무화과를 기증해요',
    donateType: DonateType.schoolWelfare,
    url: 'https://forest.or.kr',
  ),
  _Organization(
    emoji: '🌱',
    name: '도시농업 공동체·시민단체 연계',
    detail: '도시농업 공동체·시민단체와 나눔해요',
    donateType: DonateType.urbanFarmingCommunity,
    url: 'https://seoulmytree.forest.or.kr',
  ),
  _Organization(
    emoji: '🎁',
    name: '앱 내 나눔 분양',
    detail: '다른 Pig.Fig. 이용자에게 나눔 분양해요',
    donateType: DonateType.inAppSharing,
  ),
];

/// [url]을 외부 브라우저/앱으로 연다(기부처 상세 링크, 픽업 장소 구글맵 딥링크 양쪽에서 재사용).
/// `grower_mypage_screen.dart`의 `_launchContact()`와 동일하게 실행 실패(웹/앱 부재 등)에도
/// 앱이 죽지 않도록 try-catch로 감싸고 스낵바로만 안내한다.
Future<void> _launchExternalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      messenger.showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
  }
}

/// 1o — 수령/기부 선택. 완성된 묘목을 대상으로
/// `PATCH /api/seedlings/{id}/pickup-donate/`와 실제로 연동한다.
class PickupDonateScreen extends StatefulWidget {
  const PickupDonateScreen({super.key});

  @override
  State<PickupDonateScreen> createState() => _PickupDonateScreenState();
}

class _PickupDonateScreenState extends State<PickupDonateScreen> {
  final _repository = SeedlingRepository();

  bool _loading = true;
  String? _loadErrorMessage;
  Seedling? _seedling;

  _Choice _choice = _Choice.donate;
  int _selectedOrgIndex = 0;

  bool _submitting = false;
  String? _submitErrorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadErrorMessage = null;
    });
    try {
      final seedlings = await _repository.fetchSeedlings();
      final seedling = pickSeedlingForPickupDonate(seedlings);
      setState(() {
        _seedling = seedling;
        // 이미 선택을 마친 묘목이면 그 값으로 초기 상태를 맞춰 보여준다(재선택 가능).
        if (seedling?.pickupOrDonate == PickupOrDonateChoice.pickup) {
          _choice = _Choice.pickup;
        } else if (seedling?.pickupOrDonate == PickupOrDonateChoice.donate) {
          _choice = _Choice.donate;
          final index = _organizations.indexWhere(
            (org) => org.donateType == seedling!.donateType,
          );
          if (index != -1) _selectedOrgIndex = index;
        }
      });
    } on ApiException catch (e) {
      setState(() => _loadErrorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final seedling = _seedling;
    if (seedling == null) return;
    final isDonate = _choice == _Choice.donate;

    setState(() {
      _submitting = true;
      _submitErrorMessage = null;
    });
    try {
      await _repository.updatePickupOrDonate(
        seedlingId: seedling.id,
        choice: isDonate
            ? PickupOrDonateChoice.donate
            : PickupOrDonateChoice.pickup,
        donateType: isDonate ? _organizations[_selectedOrgIndex].donateType : null,
      );
      if (!mounted) return;
      if (isDonate) {
        Navigator.of(context).pushNamed(
          '/adopter/donation-certificate',
          arguments: DonationCertificateArgs(
            seedlingId: seedling.id,
            seedlingName: '무화과 #${seedling.id}',
            organizationName: _organizations[_selectedOrgIndex].name,
            startedAt: seedling.startedAt,
            completedAt: seedling.completedAt,
            heightCm: seedling.heightCm,
            finalIllustrationUrl: seedling.finalIllustrationUrl,
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('수령이 확정됐어요 🧺')));
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      setState(() => _submitErrorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PigFigAppBar(closeLabel: '닫기'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: _buildBody(),
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
    if (_loadErrorMessage != null) {
      return _ErrorState(message: _loadErrorMessage!, onRetry: _load);
    }
    if (_seedling == null) {
      return const _EmptyState();
    }
    return _buildSelection();
  }

  Widget _buildSelection() {
    final isDonate = _choice == _Choice.donate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Column(
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
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.badgeGreenText,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
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
        if (!isDonate) ...[
          const SizedBox(height: 16),
          Text(
            '픽업 장소',
            style: AppTextStyles.title(
              fontSize: 15,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _PickupLocationMap(
            onTap: () => _launchExternalUrl(context, _googleMapsUrl),
          ),
        ],
        if (_submitErrorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _submitErrorMessage!,
            style: AppTextStyles.body(fontSize: 13, color: AppColors.errorRed),
          ),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: PigFigButton.primary(
            label: isDonate ? '기부하고 인증서 받기 📜' : '수령으로 확정하기 🧺',
            onPressed: _submit,
            loading: _submitting,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FigTreeIllustration(width: 100),
            const SizedBox(height: 20),
            Text('아직 완성된 무화과가 없어요', style: AppTextStyles.title(fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              '묘목이 완성되면 그때 수령이나 기부를 선택할 수 있어요',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: PigFigButton.outline(label: '다시 시도', onPressed: onRetry),
            ),
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
      child: Container(
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
    );
  }
}

/// 픽업 장소를 보여주는 정적 지도 카드. `_staticMapUrl()`의 중심좌표가 항상 픽업 장소이므로,
/// 이미지 정중앙에 핀 아이콘을 겹쳐 그리면 실제 마커처럼 보인다(서비스 자체는 URL 파라미터로
/// 마커를 찍는 기능이 없음). 탭하면 [onTap]으로 구글맵 딥링크를 연다.
class _PickupLocationMap extends StatelessWidget {
  const _PickupLocationMap({required this.onTap});

  final VoidCallback onTap;

  static const _pinSize = 36.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEBDF), width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    Image.asset(_staticMapAsset, fit: BoxFit.cover),
                    // 핀 끝(뾰족한 하단 중앙)이 이미지 정중앙(=픽업 장소 좌표)을 가리키도록
                    // 아이콘 바운딩박스를 위로 절반만큼 보정한다.
                    Transform.translate(
                      offset: const Offset(0, -_pinSize / 2),
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.pink500,
                        size: _pinSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _pickupAddress,
              style: AppTextStyles.body(
                fontSize: 14,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '탭하면 구글맵으로 길찾기 🧭',
              style: AppTextStyles.body(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              '지도 데이터 © OpenStreetMap contributors',
              style: AppTextStyles.caption(fontSize: 10),
            ),
          ],
        ),
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
            if (organization.url != null)
              IconButton(
                onPressed: () =>
                    _launchExternalUrl(context, organization.url!),
                icon: const Icon(Icons.open_in_new),
                iconSize: 18,
                color: AppColors.textMuted,
                tooltip: '자세히 보기',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            const SizedBox(width: 4),
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
