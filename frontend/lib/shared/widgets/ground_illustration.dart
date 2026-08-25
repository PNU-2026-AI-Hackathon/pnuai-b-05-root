import 'package:flutter/material.dart';

/// 화면 하단을 가로지르는 흙/지평선 배경. [FigTreeIllustration]과 동일하게
/// 이미지 에셋이나 CustomPainter 없이 Container+BorderRadius 조합으로 그린다.
/// 상단 좌우 모서리 반지름을 각각 화면 폭의 절반(`Radius.elliptical(width / 2, ...)`)으로
/// 주면 두 모서리 곡선이 폭 전체에서 하나로 이어져 완만하게 위로 볼록한 언덕 모양이 된다.
class GroundIllustration extends StatelessWidget {
  const GroundIllustration({
    super.key,
    this.height = 160,
    this.curveHeight = 50,
  });

  /// 흙 배경 전체 높이.
  final double height;

  /// 상단 곡선의 볼록한 정도(1차 제안값 — 실제 렌더링 보고 조정 가능).
  final double curveHeight;

  /// 이 위젯 전용 흙 색상 — [AppColors]에 대응하는 토큰이 없어 지역 상수로 둔다.
  static const _groundColor = Color(0xFFB1884C);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: _groundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.elliptical(width / 2, curveHeight),
            ),
          ),
        );
      },
    );
  }
}
