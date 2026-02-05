import 'package:flutter/material.dart';
import 'home_view.dart'; // Import von oben
import '../../widgets/common/bottom_navigation.dart';
import 'activity_view.dart';
import 'settings_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeView(),
    const ActivityView(),
    const SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: _pages[_currentIndex],

      bottomNavigationBar: CustomNavBar(
        selectedIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
