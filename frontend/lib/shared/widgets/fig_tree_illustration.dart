import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 원 3개(잎) + 사각형(줄기) 조합으로 만드는 무화과 나무 일러스트.
/// 디자인 문서의 홈 화면(1f) 일러스트를 [width] 기준으로 비례 축소/확대한다.
class FigTreeIllustration extends StatelessWidget {
  const FigTreeIllustration({super.key, this.width = 220});

  final double width;

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
            child: _leaf(leafSize, AppColors.green800),
          ),
          Positioned(
            top: height * 0.043,
            right: width * 0.064,
            child: _leaf(leafSize * 0.93, const Color(0xFF456B3A)),
          ),
          Positioned(
            top: height * 0.2,
            left: width * 0.255,
            child: _leaf(leafSize * 0.87, AppColors.green800),
          ),
          Container(
            width: trunkWidth,
            height: trunkHeight,
            decoration: BoxDecoration(
              color: AppColors.brown600,
              borderRadius: BorderRadius.circular(trunkWidth / 3.5),
            ),
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
