import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_typography.dart';

/// Central ThemeData for the clinic app.
class AppTheme {
  // Two radii, not one: a single flat value looks fine on a tall filled
  // button but reads as almost a pill on a chip or text button, which are
  // roughly a third shorter. Scaling the radius down with the component
  // keeps the roundedness looking consistent instead of exaggerated on the
  // smaller ones.
  static const double buttonRadius = 10;
  static const double compactRadius = 8;

  static final RoundedRectangleBorder _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(buttonRadius),
  );

  static final RoundedRectangleBorder _compactShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(compactRadius),
  );

  static const EdgeInsets _buttonPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.rose,
        primaryContainer: AppColors.rosePale,
        secondary: AppColors.lav,
        secondaryContainer: AppColors.lavPale,
        tertiary: AppColors.sage,
        tertiaryContainer: AppColors.sagePale,
        surface: AppColors.bgCard,
        error: Color(0xFFDC2626),
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.text,
        outline: AppColors.border,
      ),
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.bodyFallback,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.text),
        actionsIconTheme: IconThemeData(color: AppColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        hintStyle: AppTypography.bodyMedium(color: AppColors.textMuted),
        labelStyle: AppTypography.labelMedium(color: AppColors.textSub),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgCard,
        selectedColor: AppColors.rose,
        checkmarkColor: AppColors.white,
        side: const BorderSide(color: AppColors.border),
        shape: _compactShape,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: AppTypography.labelMedium(color: AppColors.textSub),
        secondaryLabelStyle: AppTypography.labelMedium(color: AppColors.white),
        showCheckmark: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: _buttonPadding,
          shape: _buttonShape,
          textStyle: AppTypography.labelLarge(color: AppColors.white),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: AppColors.white,
          padding: _buttonPadding,
          shape: _buttonShape,
          textStyle: AppTypography.labelLarge(color: AppColors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.rose,
          side: const BorderSide(color: AppColors.borderRose, width: 1.2),
          padding: _buttonPadding,
          shape: _buttonShape,
          textStyle: AppTypography.labelLarge(color: AppColors.rose),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.rose,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: _compactShape,
          textStyle: AppTypography.labelMedium(color: AppColors.rose),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.bgSidebar,
        selectedIconTheme: IconThemeData(color: AppColors.roseLight),
        unselectedIconTheme: IconThemeData(color: AppColors.textSideMuted),
        indicatorColor: Color(0x26B87A86), // 15% rose
      ),
    );
  }
}
