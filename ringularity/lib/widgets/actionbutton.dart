import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.mainColor),
      onPressed: onPressed,
      // Optional: Constraints entfernen, falls der Button kompakter sein soll
      // padding: EdgeInsets.zero,
      // constraints: const BoxConstraints(),
    );
  }
}