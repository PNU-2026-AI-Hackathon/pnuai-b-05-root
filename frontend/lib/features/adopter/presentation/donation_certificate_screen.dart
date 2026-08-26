import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/download/image_downloader.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/season_badge.dart';
import '../../../shared/widgets/pig_character.dart';
import '../../../shared/widgets/pigfig_app_bar.dart';

/// `/adopter/donation-certificate` route argument.
class DonationCertificateArgs {
  const DonationCertificateArgs({
    required this.seedlingId,
    required this.seedlingName,
    required this.organizationName,
    this.startedAt,
    this.completedAt,
    this.heightCm,
    this.finalIllustrationUrl,
  });

  // 인증서 이미지 저장/공유 시 파일명(pigfig_certificate_{id}.png)에 쓴다.
  final int seedlingId;
  final String seedlingName;
  final String organizationName;
  // 과거 데이터 등으로 하나라도 없을 수 있어 nullable로 받는다 — 없으면
  // "함께한 N일" 계산 대신 안전한 폴백 문구를 보여준다.
  final DateTime? startedAt;
  final DateTime? completedAt;
  // 완성 신고 시 재배자가 입력한 최종 키(cm). 도입 이전 완료분에는 없다.
  final int? heightCm;
  // 완성 사진을 Gemini로 변환한 일러스트 URL. 있으면 인증서 안 손그림 나무 대신 이걸 보여준다.
  final String? finalIllustrationUrl;
}

/// completed_at(초 단위까지)을 "🐣 2026. 08. 20 · 14:32:07"로 만든다 —
/// "탄생 시간" 연출용. completed_at은 UTC일 수 있어 반드시 로컬로 변환 후 포맷한다
/// (`formatCertificatePeriod`와 달리 시:분:초까지 노출).
String? formatBirthMoment(DateTime? completedAt) {
  if (completedAt == null) return null;
  final d = completedAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '🐣 ${d.year}. ${two(d.month)}. ${two(d.day)} · '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// "☀️ 한여름에 완성" (+ 키가 있으면 " · 34cm") 한 줄. completed_at이 없으면 null.
String? formatSeasonLine(DateTime? completedAt, int? heightCm) {
  if (completedAt == null) return null;
  final badge = seasonBadgeFor(completedAt);
  final height = heightCm == null ? '' : ' · ${heightCm}cm';
  return '${badge.emoji} ${badge.label}에 완성$height';
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

/// 기부 인증서를 저장/공유용 파일명으로 변환한다(순수 함수라 단독 테스트 가능) —
/// `diary_detail_screen.dart`의 `buildDiaryImageFilename`과 같은 결.
String buildCertificateImageFilename(int seedlingId) =>
    'pigfig_certificate_$seedlingId.png';

/// 1p — 기부 인증서: 디지털 발급 화면. 입양자 닉네임은 실제 로그인 계정 값을
/// 조회해 보여준다. `ModalRoute` 인자 읽기 + 닉네임 로드만 담당하는 얇은
/// wrapper이며, 실제 콘텐츠(이미지 저장/공유 포함)는 [DonationCertificateCard]가 그린다.
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
      body: SafeArea(
        child: DonationCertificateCard(args: args, nickname: _nickname),
      ),
    );
  }
}

/// 기부 인증서 카드 콘텐츠 — 단독 라우트(`DonationCertificateScreen`)와
/// 기부 인증서 목록 화면의 카드 모드(세로 `PageView`) 양쪽에서 재사용된다.
/// `ModalRoute`에 의존하지 않고 필요한 데이터를 전부 생성자로 받는다.
///
/// 인증서 콘텐츠는 [RepaintBoundary]로 감싸 "이미지 저장"(`saveImageBytes`)과
/// "공유하기"(`SharePlus`)에서 화면에 보이는 그대로 PNG로 캡처한다 —
/// `diary_detail_screen.dart`가 `PhotoFrameCarousel`로 하는 것과 동일한 패턴이지만,
/// 여기는 캐러셀이 아니라 고정 카드 하나라 카드가 직접 boundary를 쥔다.
class DonationCertificateCard extends StatefulWidget {
  const DonationCertificateCard({
    super.key,
    required this.args,
    required this.nickname,
  });

  final DonationCertificateArgs args;
  final String nickname;

  @override
  State<DonationCertificateCard> createState() =>
      _DonationCertificateCardState();
}

class _DonationCertificateCardState extends State<DonationCertificateCard> {
  bool _downloading = false;
  bool _sharing = false;
  // 인증서 콘텐츠를 감싼 RepaintBoundary를 캡처하기 위한 키.
  final _boundaryKey = GlobalKey();

  /// 인증서 카드(RepaintBoundary로 감싼 영역)를 화면에 보이는 그대로 PNG로 캡처한다 —
  /// `photo_frame_carousel.dart`의 `captureCurrentFrame()`과 동일한 방식.
  Future<Uint8List?> _capture() async {
    if (!mounted) return null;
    final renderObject = _boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(
      pixelRatio: View.of(context).devicePixelRatio,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        throw Exception('이미지를 불러오지 못했어요.');
      }
      await saveImageBytes(
        bytes,
        buildCertificateImageFilename(widget.args.seedlingId),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('인증서를 저장했어요 📥')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증서 저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        throw Exception('이미지를 불러오지 못했어요.');
      }
      final filename = buildCertificateImageFilename(widget.args.seedlingId);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: filename)],
          fileNameOverrides: [filename],
        ),
      );
      // 사용자가 공유 시트를 취소한 것은 실패가 아니므로 에러로 안내하지 않는다.
      if (result.status == ShareResultStatus.dismissed) {
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공유에 실패했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final displayName = widget.nickname.isEmpty ? '입양자' : widget.nickname;
    // 저장/공유 중에는 두 버튼을 모두 잠근다(diary_detail_screen.dart와 동일).
    final busy = _downloading || _sharing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: _CertificateContent(args: args, displayName: displayName),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: busy ? null : _download,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6B675C),
                      side: const BorderSide(
                        color: AppColors.outline,
                        width: 1.5,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: _buttonChild(
                      loading: _downloading,
                      label: '이미지 저장',
                      color: const Color(0xFF6B675C),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: busy ? null : _share,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green500,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: _buttonChild(
                      loading: _sharing,
                      label: '공유하기',
                      color: Colors.white,
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

  /// 로딩 중이면 스피너, 아니면 라벨 텍스트 — 두 버튼이 공유하는 child 빌더
  /// (`PigFigButton`의 loading 스타일과 동일: 20x20 / strokeWidth 2.4).
  Widget _buttonChild({
    required bool loading,
    required String label,
    required Color color,
  }) {
    if (loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
      );
    }
    return Text(label, style: AppTextStyles.button(fontSize: 14, color: color));
  }
}

/// 인증서 콘텐츠(흰 카드 + 핑크 테두리 안의 인증 문구 전체) — [RepaintBoundary]로
/// 감싸 이미지로 캡처하는 대상이라 별도 위젯으로 분리했다.
class _CertificateContent extends StatelessWidget {
  const _CertificateContent({required this.args, required this.displayName});

  final DonationCertificateArgs args;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
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
            _CertificateArtwork(illustrationUrl: args.finalIllustrationUrl),
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
            if (formatSeasonLine(args.completedAt, args.heightCm)
                case final seasonLine?) ...[
              const SizedBox(height: 4),
              Text(
                seasonLine,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.badgeGreenText,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
            if (formatBirthMoment(args.completedAt) case final birthMoment?) ...[
              const SizedBox(height: 2),
              Text(
                birthMoment,
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: const Color(0xFFB7B2A4),
                ),
              ),
            ],
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
    );
  }
}

/// 인증서 안의 대표 그림 자리. 완성 사진의 Gemini 일러스트([illustrationUrl])가 있으면
/// 그걸 둥근 액자로 보여주고, 없거나(미변환·과거 데이터) 로딩 실패면 기존 손그림
/// 무화과나무 아이콘으로 폴백한다 — `growth_timeline_screen.dart`의
/// `illustrationUrl ?? photoUrl ?? placeholder` 우선순위와 같은 결.
class _CertificateArtwork extends StatelessWidget {
  const _CertificateArtwork({this.illustrationUrl});

  final String? illustrationUrl;

  @override
  Widget build(BuildContext context) {
    final url = illustrationUrl;
    if (url == null) return const _CertificateTreeIcon();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _CertificateTreeIcon(),
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
