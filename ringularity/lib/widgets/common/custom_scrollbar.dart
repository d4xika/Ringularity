import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CustomScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController controller;

  const CustomScrollbar({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: controller,
      thumbColor: AppColors.mainColor.withValues(alpha: 0.6),
      radius: const Radius.circular(8),
      thickness: 6,
      thumbVisibility: true,
      trackVisibility: true,
      trackColor: Colors.white.withValues(alpha: 0.05),
      padding: const EdgeInsets.only(right: 2, top: 2, bottom: 2),
      child: child,
    );
  }
}
