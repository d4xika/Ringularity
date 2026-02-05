import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int)? onTap;

  const CustomNavBar({super.key, this.selectedIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.mainColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: selectedIndex,
        onTap: onTap,
        items: [
          _buildNavItem(Icons.home_rounded, "Home"),
          _buildNavItem(Icons.directions_run_rounded, "Activity"),
          _buildNavItem(Icons.settings_rounded, "Settings"),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Icon(icon, size: 24),
      ),
      label: label,
    );
  }
}
