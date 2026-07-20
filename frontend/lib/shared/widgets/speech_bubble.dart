import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 꼬리가 아래쪽에 붙는 말풍선. 홈 화면에서 피그 캐릭터 대사에 사용.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.background = Colors.white});

  final String text;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubbleTailPainter(background),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(text, style: AppTextStyles.body(fontSize: 14).copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width - 26, size.height - 2)
      ..lineTo(size.width - 16, size.height + 10)
      ..lineTo(size.width - 8, size.height - 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) => oldDelegate.color != color;
}
