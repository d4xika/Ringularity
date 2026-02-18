import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ringularity/screens/auth/start_screen.dart';
import 'package:ringularity/screens/home/main_screen.dart';
import 'package:provider/provider.dart';
import '../services/secure_storage_service.dart';
import '../services/api/api_service.dart';
import '../services/ble/ble_api_sync.dart';
import '../services/ble/ble_service.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ApiService _apiService = ApiService();
  ApiService get apiService => _apiService;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    final navigator = Navigator.of(context);

    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        final session = await StorageService.getUserSession();

        if (session['auth_key'] == null || session['user_id'] == null) {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const StartScreen()),
          );
        } else {
          try {
            final response = await _apiService.authorizeUser(session);

            if (response.statusCode > 300) {
              StorageService.deleteUserSession();
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

            // Prefetch today's data from cloud into the shared DataManager
            try {
              final api = Provider.of<BleApiSync>(context, listen: false);
              final ble = Provider.of<BleService>(context, listen: false);
              final today = DateTime.now();
              await api
                  .downloadForDate(date: today, dataManager: ble.dataManager)
                  .timeout(const Duration(seconds: 12));
            } catch (_) {}

            navigator.pushReplacement(
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          } catch (e) {
            debugPrint(
              "Offline or Timeout during Auth: Proceeding with cached session. Error: $e",
            );
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MainScreen(isOffline: true),
              ),
            );
          }
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
