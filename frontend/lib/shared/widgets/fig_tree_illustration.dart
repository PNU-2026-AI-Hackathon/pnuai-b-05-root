import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 나무 방치 상태. 가장 최근 케어([CareStorage.mostRecentCompletion]) 이후 경과일에 따라
/// 홈 화면이 계산해 [FigTreeIllustration]에 전달한다.
enum TreeStatus { healthy, wilted, pigInfested }

/// 원 3개(잎) + 사각형(줄기) 조합으로 만드는 무화과 나무 일러스트.
/// 디자인 문서의 홈 화면(1f) 일러스트를 [width] 기준으로 비례 축소/확대한다.
/// [status]에 따라 색상이 탁해지고(방치), `pigInfested`면 돼지 이모지가 함께 나타난다.
class FigTreeIllustration extends StatelessWidget {
  const FigTreeIllustration({
    super.key,
    this.width = 220,
    this.status = TreeStatus.healthy,
  });

  final double width;
  final TreeStatus status;

  /// "시든 갈색" — [AppColors.brown600]보다 어둡고 탁한 톤. 잎/줄기 모두 이 색으로
  /// 수렴시켜 방치 정도가 뚜렷하게 보이게 한다(1차 제안 hex, 실제 렌더링 보고 조정 가능).
  static const _wiltedBrown = Color(0xFF5C3A22);

  /// 방치 정도에 따라 기본 색상을 [_wiltedBrown] 쪽으로 섞어 톤을 낮춘다.
  Color _tone(Color base) {
    final t = switch (status) {
      TreeStatus.healthy => 0.0,
      TreeStatus.wilted => 0.65,
      TreeStatus.pigInfested => 0.85,
    };
    return Color.lerp(base, _wiltedBrown, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final leafSize = width * 0.545;
    final trunkWidth = width * 0.136;
    final trunkHeight = width * 0.59;
    final height = width * 1.27;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            left: width * 0.09,
            child: _leaf(leafSize, _tone(AppColors.green800)),
          ),
          Positioned(
            top: height * 0.043,
            right: width * 0.064,
            child: _leaf(leafSize * 0.93, _tone(const Color(0xFF456B3A))),
          ),
          Positioned(
            top: height * 0.2,
            left: width * 0.255,
            child: _leaf(leafSize * 0.87, _tone(AppColors.green800)),
          ),
          Container(
            width: trunkWidth,
            height: trunkHeight,
            decoration: BoxDecoration(
              color: _tone(AppColors.brown600),
              borderRadius: BorderRadius.circular(trunkWidth / 3.5),
            ),
          ),
          if (status == TreeStatus.pigInfested)
            Positioned(
              top: height * 0.05,
              right: width * 0.02,
              child: Text('🐷', style: TextStyle(fontSize: width * 0.22)),
            ),
        ],
      ),
    );
  }

  Widget _leaf(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
