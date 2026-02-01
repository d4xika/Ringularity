import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BigButton extends StatelessWidget {
  final Widget child; 
  final VoidCallback onPressed;

  const BigButton({
    super.key,
    required this.child, 
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardBackground,
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