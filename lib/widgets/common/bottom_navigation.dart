import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A stylized, floating bottom navigation bar with a glassmorphism blur effect.
class CustomNavBar extends StatelessWidget {
  /// The index of the currently active tab.
  final int selectedIndex;

  /// Callback providing the index of the newly tapped tab.
  final Function(int)? onTap;

  /// Creates a new [CustomNavBar] instance.
  const CustomNavBar({super.key, this.selectedIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAnimatedButton(Icons.home_rounded, 0),
                _buildAnimatedButton(Icons.directions_run_rounded, 1),
                _buildAnimatedButton(Icons.settings_rounded, 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single icon button that enlarges and highlights when selected.
  Widget _buildAnimatedButton(IconData icon, int index) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap?.call(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected
                      ? AppColors.mainColor
                      : Colors.grey.withValues(alpha: 0.5),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isSelected
                      ? AppColors.mainColor
                      : Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
