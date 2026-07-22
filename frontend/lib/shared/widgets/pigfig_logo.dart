import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// [PigFigLogo]의 두 가지 형태 (claude.ai/design "PigFig Screens" 2a/2b 섹션).
enum PigFigLogoVariant {
  /// 2a — 배경 없이 무화과 몸통 실루엣 마크만 단독으로 쓴다. 현재 앱 전체에서
  /// 쓰는 기본값(로그인 화면·`PigFigAppBar` 모두 이 variant로 통일).
  symbol,

  /// 2b — pink500 라운드 사각형 안에 흰색 마크를 넣은 앱 아이콘/헤더 락업.
  /// 지금 당장 쓰는 곳은 없지만 나중에 필요해질 수 있어(예: 런처 아이콘, 파비콘)
  /// 위젯은 남겨둔다 — 삭제하지 말 것.
  iconLockup,
}

/// Pig.Fig 로고: 무화과 몸통(위가 뾰족, 아래가 둥근 형태) 실루엣 안에 돼지 얼굴을
/// 담은 심볼. claude.ai/design "PigFig Screens" 2a(메인 심볼)/2b(앱 아이콘 락업)
/// 섹션을 그대로 옮겼다. [FigTreeIllustration], [PigCharacter]와 동일하게 이미지
/// 파일이 아니라 도형 조합(Container+Stack)으로 그린다.
///
/// [size] 하나로 전체 크기를 받아 내부 비율을 유지한 채 스케일된다 — 로그인
/// 화면(74px)과 [PigFigAppBar](30px) 양쪽에서 크기만 다르게 재사용한다.
class PigFigLogo extends StatelessWidget {
  const PigFigLogo({
    super.key,
    this.size = 74,
    this.variant = PigFigLogoVariant.symbol,
  });

  final double size;
  final PigFigLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == PigFigLogoVariant.symbol) {
      return _FigPigMark(
        width: size,
        bodyColor: AppColors.pink500,
        snoutColor: AppColors.pink100,
        nostrilColor: AppColors.pink500,
        eyeColor: AppColors.textPrimary,
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.pink500,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink500.withValues(alpha: 0.35),
            blurRadius: size * 0.14,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: _FigPigMark(
        width: size * 0.55,
        bodyColor: Colors.white,
        snoutColor: AppColors.pink500,
        nostrilColor: Colors.white,
        eyeColor: AppColors.pink500,
      ),
    );
  }
}

/// 줄기 + 잎 + 무화과 몸통 실루엣 + 눈 2개 + 주둥이. [width] 기준으로 모든 조각이
/// 비례 축소/확대된다(디자인 문서 2a의 150x170 기준 좌표를 비율로 변환).
class _FigPigMark extends StatelessWidget {
  const _FigPigMark({
    required this.width,
    required this.bodyColor,
    required this.snoutColor,
    required this.nostrilColor,
    required this.eyeColor,
  });

  final double width;
  final Color bodyColor;
  final Color snoutColor;
  final Color nostrilColor;
  final Color eyeColor;

  @override
  Widget build(BuildContext context) {
    final height = width * (170 / 150);
    final bodyHeight = width * (154 / 150);
    final stemWidth = width * 0.08;
    final leafWidth = width * 0.29333;
    final leafHeight = width * 0.2;
    final eyeSize = width * 0.07333;
    final snoutWidth = width * 0.25333;
    final snoutHeight = width * 0.17333;
    final nostrilWidth = width * 0.03333;
    final nostrilHeight = width * 0.06;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 줄기
          Positioned(
            top: -width * 0.04,
            left: (width - stemWidth) / 2,
            child: Container(
              width: stemWidth,
              height: width * 0.17333,
              decoration: BoxDecoration(
                color: AppColors.brown600,
                borderRadius: BorderRadius.circular(stemWidth / 2),
              ),
            ),
          ),
          // 잎
          Positioned(
            top: -width * 0.06667,
            left: width * 0.54,
            child: Transform.rotate(
              angle: -18 * math.pi / 180,
              child: Container(
                width: leafWidth,
                height: leafHeight,
                decoration: BoxDecoration(
                  color: AppColors.green800,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(width * 0.02667),
                    topRight: Radius.circular(width * 0.16),
                    bottomRight: Radius.circular(width * 0.02667),
                    bottomLeft: Radius.circular(width * 0.16),
                  ),
                ),
              ),
            ),
          ),
          // 몸통 — 무화과 실루엣(위가 뾰족, 아래가 둥근 형태)
          Positioned(
            top: width * 0.10667,
            left: 0,
            child: Container(
              width: width,
              height: bodyHeight,
              decoration: BoxDecoration(
                color: bodyColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.elliptical(width * 0.46, bodyHeight * 0.62),
                  topRight: Radius.elliptical(width * 0.46, bodyHeight * 0.62),
                  bottomRight: Radius.elliptical(
                    width * 0.50,
                    bodyHeight * 0.42,
                  ),
                  bottomLeft: Radius.elliptical(
                    width * 0.50,
                    bodyHeight * 0.42,
                  ),
                ),
              ),
            ),
          ),
          // 눈 2개
          Positioned(
            top: width * 0.45333,
            left: width * 0.25333,
            child: _circle(eyeSize, eyeColor),
          ),
          Positioned(
            top: width * 0.45333,
            right: width * 0.25333,
            child: _circle(eyeSize, eyeColor),
          ),
          // 주둥이
          Positioned(
            top: width * 0.57333,
            left: (width - snoutWidth) / 2,
            child: Container(
              width: snoutWidth,
              height: snoutHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: snoutColor,
                borderRadius: BorderRadius.circular(snoutHeight / 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _nostril(nostrilWidth, nostrilHeight, nostrilColor),
                  SizedBox(width: width * 0.024),
                  _nostril(nostrilWidth, nostrilHeight, nostrilColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _nostril(double w, double h, Color color) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(w / 2),
    ),
  );
}
