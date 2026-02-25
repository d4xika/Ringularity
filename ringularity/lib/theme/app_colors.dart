import 'package:flutter/material.dart';

/// A centralized registry of all foundational colors used throughout the application.
///
/// Defines the core brand palette (mainColor, backgrounds) as well as specific
/// semantic colors used consistently for charting and metric visualization
/// (e.g. sleep stages).
class AppColors {
  /// The primary brand color (Neon Cyan/Mint) used for buttons, active icons, and primary highlights.
  static const Color mainColor = Color.fromARGB(255, 0, 255, 195);

  /// The deep navy/black color used for the main scaffold background.
  static const Color background = Color.fromARGB(255, 14, 23, 43);

  /// A slightly lighter navy used for elevated cards, modal sheets, and dialogue backgrounds.
  static const Color cardBackground = Color.fromARGB(255, 28, 39, 64);

  static const Color accentBlue = Color(0xFF2E8AF6);
  static const Color accentCyan = Color(0xFF00D7E7);
  static const Color accentGreen = Color(0xFF00E676);

  /// Standard color for primary reading text and titles.
  static const Color textPrimary = Colors.white;

  /// Standard color for secondary text, labels, and disabled states.
  static const Color textSecondary = Colors.grey;

  // --- Semantic Data Visualization Colors ---

  static const Color deepSleep = Color(0xFF1E4578);
  static const Color lightSleep = Color(0xFF4B98F5);
  static const Color remSleep = Color(0xFF9D4BF5);
  static const Color awake = Color(0xFFFF9B9B);
}
