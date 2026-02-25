import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A primary, full-width action button used extensively across the app.
class BigButton extends StatelessWidget {
  /// The contents of the button, typically a Text or Icon widget.
  final Widget child;

  /// Callback executed when the button is tapped.
  final VoidCallback onPressed;

  /// Optional background color override. Defaults to [AppColors.cardBackground].
  final Color? backgroundColor;

  /// Creates a new [BigButton] instance.
  const BigButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.cardBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}
