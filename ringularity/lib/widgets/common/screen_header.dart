import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? actionWidget;
  final VoidCallback? onBackPressed;

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
