import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ble/ble_service.dart';
import 'history/history_screen.dart';
import 'measurements/measurement_menu_screen.dart';
import 'debug/debug_screen.dart';
import 'settings/settings_screen.dart';
import 'dashboard/dashboard_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Listen for connection changes to kick user to dashboard if disconnected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = Provider.of<BleService>(context, listen: false);
      ble.addListener(_handleConnectionChange);
    });
  }

  @override
  void dispose() {
    final ble = Provider.of<BleService>(context, listen: false);
    ble.removeListener(_handleConnectionChange);
    super.dispose();
  }

  void _handleConnectionChange() {
    final ble = Provider.of<BleService>(context, listen: false);
    // Safety Check: If we lose connection and are not on the dashboard, kick back to dashboard.
    // This prevents users from being stuck on screens that require active connection (like 'Measure').
    if (!ble.isConnected && _selectedIndex != 0) {
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Connection lost. Returning to Dashboard.")),
        );
      }
    }
  }

  // Pages for Navigation
  // 0: Dashboard
  // 1: Measure
  // 2: History
  // 3: Debug
  // 4: Settings

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pages List
    // We use an IndexStack-like approach via switching the body widget.
    // Each page corresponds to an item in the BottomNavigationBar.
    final List<Widget> pages = [
      const DashboardScreen(),
      const MeasurementMenuScreen(),
      const HistoryScreen(),
      const DebugScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors),
            label: 'Measure',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bug_report),
            label: 'Debug',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
