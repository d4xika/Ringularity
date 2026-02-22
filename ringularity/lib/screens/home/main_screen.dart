import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/network_status_service.dart';
import '../../widgets/common/bottom_navigation.dart';
import 'activity_view.dart';
import 'home_view.dart';
import 'settings_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;
  bool _offlineSnackbarShown = false;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeView(onNavigateToSettings: _goToSettings),
      const ActivityView(),
      const SettingsView(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show the offline snackbar once when the screen first appears offline.
    final networkStatus = context.watch<NetworkStatusService>();
    if (!networkStatus.isOnline && !_offlineSnackbarShown) {
      _offlineSnackbarShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Cloud sync is not working. Entering Offline Mode.",
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    } else if (networkStatus.isOnline) {
      // Reset so the snackbar can show again if connectivity drops and returns.
      _offlineSnackbarShown = false;
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
