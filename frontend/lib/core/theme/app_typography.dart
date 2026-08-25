import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

/// Type scale. Families come from [AppFonts].
abstract class AppTypography {
  static TextStyle _display({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: AppFonts.display,
      fontFamilyFallback: AppFonts.displayFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle _body({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.bodyFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ─── Display ────────────────────────────────────────────────────────────
  static TextStyle displayHero({Color color = AppColors.text}) {
    return _display(
      fontSize: 42,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.15,
    );
  }

  static TextStyle displayTitle({Color color = AppColors.text}) {
    return _display(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.2,
    );
  }

  static TextStyle displaySubtitle({Color color = AppColors.text}) {
    return _display(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.25,
    );
  }

  static TextStyle displayStat({Color color = AppColors.text}) {
    return _display(fontSize: 26, fontWeight: FontWeight.w600, color: color);
  }

  // ─── Body ───────────────────────────────────────────────────────────────
  static TextStyle bodyLarge({Color color = AppColors.text}) {
    return _body(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.5,
    );
  }

  static TextStyle bodyMedium({Color color = AppColors.text}) {
    return _body(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.45,
    );
  }

  static TextStyle bodySmall({Color color = AppColors.textMuted}) {
    return _body(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.4,
    );
  }

  // ─── Label ──────────────────────────────────────────────────────────────
  static TextStyle labelLarge({Color color = AppColors.text}) {
    return _body(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.3,
    );
  }

  static TextStyle labelMedium({Color color = AppColors.text}) {
    return _body(fontSize: 13, fontWeight: FontWeight.w500, color: color);
  }

  static TextStyle labelSmall({Color color = AppColors.textMuted}) {
    return _body(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: color,
      letterSpacing: 0.5,
    );
  }

  // Corbel defaults to old-style figures; force lining.
  static TextStyle numeric({
    Color color = AppColors.text,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return _body(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    ).copyWith(
      fontFeatures: const [
        FontFeature.liningFigures(),
        FontFeature.tabularFigures(),
      ],
    );
  }

  // ─── Arabic ─────────────────────────────────────────────────────────────
  static TextStyle arabicHeader({Color color = AppColors.text}) {
    return TextStyle(
      fontFamily: AppFonts.arabic,
      fontFamilyFallback: AppFonts.arabicFallback,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static TextStyle arabicBody({Color color = AppColors.text}) {
    return TextStyle(
      fontFamily: AppFonts.arabic,
      fontFamilyFallback: AppFonts.arabicFallback,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }
}
