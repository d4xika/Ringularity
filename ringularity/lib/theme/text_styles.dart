import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// A centralized registry of all typography styles used throughout the application.
///
/// Ensures consistent font families, weights, sizes, and colors across all screens.
/// Uses `GoogleFonts` for specialized branding headers (Michroma).
class AppTextStyles {
  /// Large, stylized header font used for main screen titles.
  static TextStyle title = GoogleFonts.michroma(
    fontSize: 25.0,
    fontWeight: FontWeight.bold,
    color: AppColors.mainColor,
    letterSpacing: 0.7,
  );

  /// Slightly smaller stylized header used for section titles.
  static TextStyle subtitle = GoogleFonts.michroma(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Standard sans-serif bold text used for sub-sections and prominent labels.
  static const TextStyle subsubtitle = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Standard sans-serif muted text used for descriptions and metadata.
  static const TextStyle bodygrey = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  /// The standard font configuration for primary action buttons.
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Standard sans-serif white text used for primary reading copy.
  static const TextStyle bodywhite = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );
}
