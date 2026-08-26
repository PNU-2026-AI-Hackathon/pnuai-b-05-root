import 'package:flutter/material.dart';

/// 화면 하단을 가로지르는 흙/지평선 배경. [FigTreeIllustration]과 동일하게
/// 이미지 에셋이나 CustomPainter 없이 Container+BorderRadius 조합으로 그린다.
/// 상단 좌우 모서리 반지름을 각각 화면 폭의 절반(`Radius.elliptical(width / 2, ...)`)으로
/// 주면 두 모서리 곡선이 폭 전체에서 하나로 이어져 완만하게 위로 볼록한 언덕 모양이 된다.
///
/// [height]/[curveHeight]를 지정하지 않으면 화면 높이에 비례해 계산한다 — 예전엔
/// 160/50 고정 픽셀이라, 실기기 화면 크기에 따라 이 흙과 (화면 상단 기준으로 배치되던)
/// 나무 사이 간격이 어긋나는 문제가 있었다. 비율은 화면 높이 914(저장소
/// `safe_area_layout_test.dart`가 실기기 픽스처로 쓰는 논리 높이)에서 기존 160/50이
/// 그대로 나오도록 역산했다 — 흙 높이 160/914 ≈ 0.175, 곡선은 흙 높이의 50/160 = 0.3125.
class GroundIllustration extends StatelessWidget {
  const GroundIllustration({super.key, this.height, this.curveHeight});

  /// 흙 배경 전체 높이. null이면 화면 높이 × [_heightRatio]로 계산한다.
  final double? height;

  /// 상단 곡선의 볼록한 정도. null이면 실제 흙 높이 × [_curveRatio]로 계산한다
  /// (화면이 아니라 흙 높이에 비례 — 기존 50/160 내부 비율을 그대로 보존).
  final double? curveHeight;

  /// 흙 높이 = 화면 높이 × 이 비율.
  static const _heightRatio = 0.175;

  /// 곡선 높이 = 흙 높이 × 이 비율.
  static const _curveRatio = 0.3125;

  /// 이 위젯 전용 흙 색상 — [AppColors]에 대응하는 토큰이 없어 지역 상수로 둔다.
  static const _groundColor = Color(0xFFB1884C);

  @override
  Widget build(BuildContext context) {
    // 이 위젯은 홈 화면에서 `Positioned(bottom: 0)`으로만 배치돼 세로 제약이
    // unbounded라 LayoutBuilder로는 높이를 받을 수 없다 — 가로(width)만 LayoutBuilder로
    // 받고, 높이는 화면 크기에서 직접 읽는다.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final resolvedHeight = height ?? screenHeight * _heightRatio;
    final resolvedCurveHeight = curveHeight ?? resolvedHeight * _curveRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: resolvedHeight,
          decoration: BoxDecoration(
            color: _groundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.elliptical(width / 2, resolvedCurveHeight),
            ),
          ),
        );
      },
    );
  }
}
