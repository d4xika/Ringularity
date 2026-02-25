import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/screens/auth/start_screen.dart';
import 'package:ringularity/screens/home/main_screen.dart';

import '../services/api/api_service.dart';
import '../services/ble/ble_api_sync.dart';
import '../services/ble/ble_service.dart';
import '../services/network_status_service.dart';
import '../services/user/storage_service.dart';

/// The entry point of the application, serving as a gateway and initialization layer.
///
/// While displaying a visual loading animation, this screen asynchronously:
/// 1. Checks backend connectivity (online/offline mode) via polling logic.
/// 2. Validates existing user sessions stored securely on the device.
/// 3. Authenticates the user with the backend API.
/// 4. Pre-fetches the current day's health data from the cloud.
/// 5. Routes the user to either the [StartScreen] (if logged out) or [MainScreen] (if logged in).
class AnimatedSplashScreen extends StatefulWidget {
  /// Creates a new [AnimatedSplashScreen] instance.
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ApiService _apiService = ApiService();

  /// Provides access to the backend API for session validation.
  ApiService get apiService => _apiService;

  @override
  void initState() {
    super.initState();
    // Configures the continuous rotation animation for the loading icon.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    final navigator = Navigator.of(context);

    // Forces a minimum 3-second delay to ensure the splash screen animation is visible
    // before executing heavy initialization logic.
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        final session = await StorageService.getUserSession();
        final bool hasSession =
            session['auth_key'] != null && session['user_id'] != null;

        // Step 1: Check server health
        final bool alive = await _apiService.checkIfAlive();

        // Step 2: Establish base network configuration for the remaining app lifecycle
        if (mounted) {
          final networkStatus = Provider.of<NetworkStatusService>(
            context,
            listen: false,
          );
          networkStatus.setOnline(alive);
          networkStatus.startPolling();
        }

        if (!alive) {
          // OFFLINE MODE: Route based on whether we have a cached local session.
          if (!hasSession) {
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => const StartScreen(isOffline: true),
              ),
            );
          } else {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
          return;
        }

        if (!hasSession) {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const StartScreen()),
          );
          return;
        }

        try {
          // Step 3: Validate existing session via the API
          final response = await _apiService.authorizeUser(session);

          // If the token is invalid, clear local data and force a fresh login.
          if (response.statusCode > 300) {
            await StorageService.deleteUserSession();
            navigator.pushReplacement(
              MaterialPageRoute(builder: (context) => const StartScreen()),
            );
            return;
          }

          final data = json.decode(response.body);
          await StorageService.saveUserSession(
            data['auth_key'],
            data['user_id'].toString(),
          );

          if (!mounted) return;

          // Step 4: Pre-fetch today's data to make the dashboard feel instant.
          try {
            final api = Provider.of<BleApiSync>(context, listen: false);
            final ble = Provider.of<BleService>(context, listen: false);
            final today = DateTime.now();
            await api
                .downloadForDate(date: today, dataManager: ble.dataManager)
                .timeout(const Duration(seconds: 12));
          } catch (_) {
            // Silently catch fetch timeouts to prevent the app from getting stuck on the splash screen.
          }

          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } catch (e) {
          debugPrint(
            "Error during Auth: Proceeding with cached session. Error: $e",
          );
          // Fallback if the authorization request fails unexpectedly.
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _controller.drive(Tween<double>(begin: 1.0, end: 0.0)),
              child: Image.asset(
                'assets/loader/swirl.png',
                width: 260,
                height: 260,
              ),
            ),
            Image.asset(
              'assets/loader/logo_circle.png',
              width: 260,
              height: 260,
            ),
          ],
        ),
      ),
    );
  }
}
