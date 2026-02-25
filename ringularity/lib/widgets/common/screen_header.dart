import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// A standard app bar replacement used across secondary screens.
///
/// Features a back arrow, a centered title, and an optional action widget
/// (like a calendar icon) on the far right.
class ScreenHeader extends StatelessWidget {
  final String title;

  /// Optional widget displayed on the far right (e.g., an [IconButton]).
  final Widget? actionWidget;

  /// Overrides the default `Navigator.pop(context)` behavior of the back button.
  final VoidCallback? onBackPressed;

  /// Creates a new [ScreenHeader] instance.
  const ScreenHeader({
    super.key,
    required this.title,
    this.actionWidget,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.mainColor),
          onPressed: onBackPressed ?? () => Navigator.pop(context),
        ),
        Text(title, style: AppTextStyles.title),
        actionWidget ?? const SizedBox(width: 48, height: 48),
      ],
    );
  }
}
