import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 줄기+새싹이 달린 화분 일러스트. 이미지 파일 대신 도형 조합으로 그린다
/// (다른 화면 일러스트와 동일한 컨벤션, 예: [FigTreeIllustration]).
/// 케어 화면(물주기/영양제)에서 공통으로 쓰며, [overlay]로 화분 몸통 위에
/// 드롭 타겟 링 같은 요소를 겹쳐 그릴 수 있다.
class CarePotIllustration extends StatelessWidget {
  const CarePotIllustration({super.key, this.overlay});

  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-6, 0),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.green800,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(6, 0),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3E6B33),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(width: 4, height: 22, color: AppColors.brown600),
        Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 8,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A4E30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 100,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.brown600,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(22),
                    ),
                  ),
                ),
              ],
            ),
            ?overlay,
          ],
        ),
      ],
    );
  }
}
