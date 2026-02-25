import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_api_sync.dart';
import 'package:ringularity/services/ble/ble_logger.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/services/daily_summary_service.dart';
import 'package:ringularity/services/health/activity_service.dart';
import 'package:ringularity/services/health/goal_service.dart';
import 'package:ringularity/services/health/vitals_storage_service.dart';
import 'package:ringularity/services/network_status_service.dart';
import 'package:ringularity/services/notifications_service.dart';
import 'package:ringularity/widgets/app/lifecycle_manager.dart';

import '../screens/animated_splash_screen.dart';

/// The primary entry point of the Ringularity application.
///
/// Responsible for executing critical asynchronous initializations before the UI renders,
/// such as binding native platforms, configuring local notifications, optimizing Google Maps,
/// and bootstrapping the global state management (Provider) tree.
void main() async {
  // Ensure native bindings are fully established before invoking platform channels.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background notification channels and clear any stale alerts.
  await NotificationService.initializeNotification();
  await NotificationService.updateAllSchedules();
  await NotificationService.resetNotifications();

  // Enforce modern Android View Surfaces for Google Maps to prevent rendering glitches.
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  runApp(
    MultiProvider(
      providers: [
        // 1. NetworkStatusService must be instantiated first as other services depend on it.
        ChangeNotifierProvider(
          create: (_) => NetworkStatusService(),
          lazy: false,
        ),

        // 2. Core BLE Service. Injects the previously built NetworkStatusService to handle offline states.
        ChangeNotifierProvider(
          create: (ctx) {
            final networkStatus = ctx.read<NetworkStatusService>();
            final bleService = BleService()..init();
            bleService.initNetworkStatus(networkStatus);
            return bleService;
          },
          lazy: false,
        ),

        // 3. Cloud synchronization manager.
        ChangeNotifierProvider(
          create: (ctx) => BleApiSync(
            logger: BleLogger(),
            networkStatus: ctx.read<NetworkStatusService>(),
          ),
          lazy: false,
        ),

        // 4. Fitness and User Goals manager.
        ChangeNotifierProvider(
          create: (_) => GoalService()..init(),
          lazy: false,
        ),

        // 5. Activity, Vitals, and Summary local storage layers.
        ChangeNotifierProvider(create: (_) => ActivityService(), lazy: false),
        ChangeNotifierProvider(create: (_) => VitalsStorageService()),
        ChangeNotifierProvider(create: (_) => DailySummaryService()),
      ],
      child: const SmartRingApp(),
    ),
  );
}

/// The root material application widget.
///
/// Wraps the entire application in a [LifecycleManager] to respond to OS-level
/// foreground/background events. Defines the global dark theme, standard typography,
/// and designates the [AnimatedSplashScreen] as the initial route.
class SmartRingApp extends StatelessWidget {
  /// Creates a new [SmartRingApp] instance.
  const SmartRingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LifecycleManager(
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          textTheme: GoogleFonts.spaceGroteskTextTheme(
            Theme.of(context).textTheme,
          ).apply(),
        ),
        debugShowCheckedModeBanner: false,
        title: 'Ringularity',
        home: const AnimatedSplashScreen(),
      ),
    );
  }
}
