import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_controller.dart';

class LiquidGlassTheme {
  // Dynamic Background & Surface palette from ThemeController
  static Color get bgScaffold => ThemeController.instance.scaffoldBg;
  static Color get bgSurface => ThemeController.instance.surfaceBg;
  static Color get bgCard => ThemeController.instance.cardBg;
  static Color get borderSubtle => ThemeController.instance.border;
  static Color get dividerHairline => ThemeController.instance.divider;
  static Color get inputFill => ThemeController.instance.inputFill;
  static bool get isDark => ThemeController.instance.isDark;

  // Clay White Dim legacy compatibility tokens
  static const Color bgClayDim = Color(0xFFE8ECEF);
  static const Color bgClayDimDarker = Color(0xFFDFE4E8);
  static const Color bgClaySurface = Color(0xFFFFFFFF);
  static const Color clayShadow = Color(0xFFCAD2DC);
  static const Color bgDark = Color(0xFF0F172A);
  static const Color bgSecondary = Color(0xFF1E293B);

  // Dynamic Text tokens
  static Color get textPrimary => ThemeController.instance.textPrimary;
  static Color get textSecondary => ThemeController.instance.textSecondary;
  static Color get textMuted => ThemeController.instance.textMuted;

  // Dynamic Accents from ThemeController
  static Color get accentBlue => ThemeController.instance.primaryColor;
  static Color get accentIndigo => ThemeController.instance.secondaryColor;
  static const Color accentEmerald = Color(0xFF10B981);

  // Clean glass surface colors
  static Color get glassBackground => bgSurface.withOpacity(0.85);
  static Color get glassBackgroundActive => bgSurface;
  static Color get glassInputFill => inputFill;

  // Dynamic borders
  static Color get glassBorder => borderSubtle;
  static Color get glassBorderFocus => ThemeController.instance.primaryColor;

  // Dynamic button styling
  static LinearGradient get primaryButtonGradient => ThemeController.instance.primaryGradient;

  // Typography
  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get titleLarge => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      );
}
