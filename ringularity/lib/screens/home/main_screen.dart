import 'package:flutter/material.dart';

import '../../widgets/common/bottom_navigation.dart';
import 'activity_view.dart';
import 'home_view.dart';
import 'settings_view.dart';

class MainScreen extends StatefulWidget {
  final bool isOffline;

  const MainScreen({super.key, this.isOffline = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeView(onNavigateToSettings: _goToSettings),
      const ActivityView(),
      const SettingsView(),
    ];

    if (widget.isOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cloud sync is not working. Entering Offline Mode."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      });
    }
  }

  void _goToSettings() {
    setState(() {
      _currentIndex = 2;
    });
  }

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
