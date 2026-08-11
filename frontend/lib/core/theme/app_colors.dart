import 'package:flutter/material.dart';

/// Beauty Clinical light & dark color palette tokens
/// Extracted from design tokens (src/tokens.ts)
abstract class AppColors {
  // Grounds / Backgrounds
  static const Color bg = Color(0xFFFCFAFB);
  static const Color bgAlt = Color(0xFFF7F3F5);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgRose = Color(0xFFFDF0F3);
  static const Color bgLavender = Color(0xFFF5F2FA);
  static const Color bgSage = Color(0xFFEEF4F1);
  static const Color bgSidebar = Color(0xFF2A1E28);

  // Borders
  static const Color border = Color(0xFFEDE5E8);
  static const Color borderRose = Color(0xFFE0C8CF);
  static const Color borderLav = Color(0xFFD8D0EA);

  // Text Colors
  static const Color text = Color(0xFF2A2030);
  static const Color textMuted = Color(0xFF8A7A85);
  static const Color textSub = Color(0xFF6A5A65);
  static const Color textSide = Color(0xFFC4B0BC);
  static const Color textSideMuted = Color(0xFF6A4E60);

  // Primary - Rose
  static const Color rose = Color(0xFFB87A86);
  static const Color roseDark = Color(0xFF8C5868);
  static const Color roseLight = Color(0xFFD4A0AA);
  static const Color rosePale = Color(0xFFFDEEF1);

  // Secondary - Lavender
  static const Color lav = Color(0xFF9B8FB5);
  static const Color lavDark = Color(0xFF7060A0);
  static const Color lavPale = Color(0xFFF0ECF8);

  // Tertiary - Sage
  static const Color sage = Color(0xFF6A9878);
  static const Color sageDark = Color(0xFF4A7058);
  static const Color sagePale = Color(0xFFEBF5EF);

  // Accent - Gold
  static const Color gold = Color(0xFFB0904A);
  static const Color goldPale = Color(0xFFFAF3E0);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color hairline = Color(0xFFF0EAED);
  static const Color shadow = Color(0x0D2A2030); // 5% opacity dark shadow
}
