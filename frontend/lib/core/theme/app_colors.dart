import 'package:flutter/material.dart';

/// Pig.Fig 디자인 시스템 색상 토큰 (claude.ai/design "PigFig Screens" 1a 섹션 기준).
class AppColors {
  AppColors._();

  static const pink500 = Color(0xFFF794A4);
  static const pink100 = Color(0xFFFBD3DB);
  static const green500 = Color(0xFF7CC47F);
  static const green800 = Color(0xFF4F7A42);
  static const brown600 = Color(0xFF8B5E3C);
  static const beigeBg = Color(0xFFFBF6EC);
  static const blue400 = Color(0xFF6FB9E8);
  static const orange400 = Color(0xFFF5A93B);

  // 화면별로 반복 사용되는 보조 색상
  static const cardWhite = Color(0xFFFFFDFA);
  static const textPrimary = Color(0xFF3A3A3A);
  static const textMuted = Color(0xFF8A8578);
  static const textCaption = Color(0xFF999999);
  static const outline = Color(0xFFE4E0D4);
  static const dotInactive = Color(0xFFDDD9CC);
  static const badgePinkText = Color(0xFFB95F73);
  static const badgeGreenBg = Color(0xFFEAF5E6);
  static const badgeGreenText = Color(0xFF6DAF62);
  static const errorRed = Color(0xFFF05B72);
  static const warningPink = Color(0xFFE8879B); // 재배자 화면 "주의" 배지/경고 텍스트
}
