import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 디자인 시스템 타이포그래피: Display=Gaegu, 나머지=Noto Sans KR.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({double fontSize = 30, Color color = AppColors.pink500}) =>
      GoogleFonts.gaegu(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: fontSize * 0.08,
      );

  static TextStyle title({double fontSize = 19, Color color = AppColors.textPrimary}) =>
      GoogleFonts.notoSansKr(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color,
      );

  static TextStyle guide({double fontSize = 16, Color color = AppColors.green800}) =>
      GoogleFonts.notoSansKr(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle body({double fontSize = 14, Color color = AppColors.textPrimary}) =>
      GoogleFonts.notoSansKr(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle caption({double fontSize = 12, Color color = AppColors.textCaption}) =>
      GoogleFonts.notoSansKr(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle button({double fontSize = 16, Color color = Colors.white}) =>
      GoogleFonts.notoSansKr(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.beigeBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.pink500,
        secondary: AppColors.green500,
        surface: Colors.white,
        error: AppColors.errorRed,
      ),
      textTheme: GoogleFonts.notoSansKrTextTheme(base.textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pink500,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.button(),
          elevation: 0,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.orange400,
        inactiveTrackColor: const Color(0xFFF3EAD3),
        thumbColor: Colors.white,
        overlayColor: AppColors.orange400.withValues(alpha: 0.2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.outline, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.pink500, width: 1.5),
        ),
      ),
    );
  }
}
