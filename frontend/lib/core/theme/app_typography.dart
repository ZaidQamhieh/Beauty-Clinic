import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography System for Beauty Clinic App
/// Uses Google Fonts:
/// - DM Sans: Clean, modern sans-serif for body, buttons, and UI controls
/// - Cormorant Upright: Elegant serif for headers, titles, and display numbers
/// - Noto Naskh Arabic: For Arabic typography and localization
abstract class AppTypography {
  // ─── Display Styles (Cormorant Upright) ─────────────────────────────────
  static TextStyle displayHero({Color color = AppColors.text}) {
    return GoogleFonts.cormorantUpright(
      fontSize: 42,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.15,
    );
  }

  static TextStyle displayTitle({Color color = AppColors.text}) {
    return GoogleFonts.cormorantUpright(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.2,
    );
  }

  static TextStyle displaySubtitle({Color color = AppColors.text}) {
    return GoogleFonts.cormorantUpright(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.25,
    );
  }

  static TextStyle displayStat({Color color = AppColors.text}) {
    return GoogleFonts.cormorantUpright(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  // ─── Body Styles (DM Sans) ──────────────────────────────────────────────
  static TextStyle bodyLarge({Color color = AppColors.text}) {
    return GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.5,
    );
  }

  static TextStyle bodyMedium({Color color = AppColors.text}) {
    return GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.45,
    );
  }

  static TextStyle bodySmall({Color color = AppColors.textMuted}) {
    return GoogleFonts.dmSans(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.4,
    );
  }

  // ─── Label / Button / Navigation Styles (DM Sans) ───────────────────────
  static TextStyle labelLarge({Color color = AppColors.text}) {
    return GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.3,
    );
  }

  static TextStyle labelMedium({Color color = AppColors.text}) {
    return GoogleFonts.dmSans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: color,
    );
  }

  static TextStyle labelSmall({Color color = AppColors.textMuted}) {
    return GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: color,
      letterSpacing: 0.5,
    );
  }

  // ─── Arabic Typography (Noto Naskh Arabic) ─────────────────────────────
  static TextStyle arabicHeader({Color color = AppColors.text}) {
    return GoogleFonts.notoNaskhArabic(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static TextStyle arabicBody({Color color = AppColors.text}) {
    return GoogleFonts.notoNaskhArabic(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }
}
