import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Subtitle extends StatelessWidget {
  final String text;
  final double fontSize;

  const Subtitle({
    super.key,
    required this.text,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:  TextStyle(
        color: AppColors.textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}