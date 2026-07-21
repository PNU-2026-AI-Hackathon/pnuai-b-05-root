import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 원+사각형 조합으로 만드는 Pig.Fig 돼지 캐릭터 일러스트.
class PigCharacter extends StatelessWidget {
  const PigCharacter({super.key, this.width = 66});

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 0.91;
    final earSize = width * 0.24;
    final eyeSize = width * 0.106;
    final snoutWidth = width * 0.3;
    final snoutHeight = width * 0.21;
    final nostril = width * 0.045;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            top: -height * 0.067,
            left: width * 0.06,
            child: _circle(earSize, AppColors.pink500),
          ),
          Positioned(
            top: -height * 0.067,
            right: width * 0.06,
            child: _circle(earSize, AppColors.pink500),
          ),
          Positioned.fill(child: _circle(width, const Color(0xFFF9A8B6))),
          Positioned(
            top: height * 0.37,
            left: width * 0.21,
            child: _circle(eyeSize, const Color(0xFF2B2B2B)),
          ),
          Positioned(
            top: height * 0.37,
            right: width * 0.21,
            child: _circle(eyeSize, const Color(0xFF2B2B2B)),
          ),
          Positioned(
            top: height * 0.58,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: snoutWidth,
                height: snoutHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFF08CA0),
                  borderRadius: BorderRadius.circular(snoutHeight / 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _nostril(nostril),
                    SizedBox(width: nostril * 0.6),
                    _nostril(nostril),
                  ],
                ),
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

  Widget _nostril(double size) => Container(
    width: size,
    height: size * 1.4,
    decoration: BoxDecoration(
      color: const Color(0xFFC9647C),
      borderRadius: BorderRadius.circular(size / 2),
    ),
  );
}
