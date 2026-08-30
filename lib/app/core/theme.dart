import 'package:flutter/material.dart';

/// Warna aplikasi yang bersumber dari token desain Figma.
abstract final class AppColors {
  static const navy = Color(0xFF081C2D);
  static const navyBlue = navy;
  static const green = Color(0xFF1F7A63);
  static const softWhite = Color(0xFFF5F7FA);
  static const gray = Color(0xFF9AA3A8);
  static const lightGreen = Color(0xFFE2EFEC);
  static const white = Color(0xFFFFFFFF);
}

/// Tipografi aplikasi Motorix.
abstract final class AppTypography {
  static const fontFamily = 'SF Pro';
  static const fontSFPro = fontFamily;
  static const fontInter = 'Inter';

  static const largeTitle = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 60 / 40,
    color: AppColors.navy,
  );

  static const title1 = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 51 / 34,
    color: AppColors.navy,
  );

  static const title2 = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 42 / 28,
    color: AppColors.navy,
  );

  static const title3 = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 39 / 26,
    color: AppColors.navy,
  );

  static const headline = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 36 / 24,
    color: AppColors.navy,
  );

  static const body = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 28.8 / 24,
    color: AppColors.navy,
  );

  static const subhead = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 24 / 20,
    color: AppColors.navy,
  );

  static const footnote = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 21.6 / 18,
    color: AppColors.navy,
  );

  static const caption1 = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 24 / 16,
    color: AppColors.navy,
  );

  static const caption2 = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 21 / 14,
    color: AppColors.navy,
  );

  static const caption3 = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
    color: AppColors.navy,
  );

  static const caption4 = TextStyle(
    fontFamily: fontSFPro,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 15 / 10,
    color: AppColors.navy,
  );

  static const text = TextStyle(
    fontFamily: fontInter,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 14.4 / 12,
    color: AppColors.navy,
  );

  static const textTheme = TextTheme(
    displaySmall: largeTitle,
    headlineMedium: headline,
    titleLarge: title1,
    titleMedium: title2,
    titleSmall: title3,
    bodyLarge: body,
    bodyMedium: subhead,
    bodySmall: footnote,
    labelLarge: caption1,
    labelMedium: caption2,
    labelSmall: caption3,
  );
}
