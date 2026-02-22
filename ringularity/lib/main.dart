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
import 'package:ringularity/services/notifications_service.dart';
import 'package:ringularity/widgets/app/lifecycle_manager.dart';

import '../screens/animated_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initializeNotification();
  await NotificationService.updateAllSchedules();
  await NotificationService.resetNotifications();

  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BleService()..init(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => BleApiSync(logger: BleLogger()),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => GoalService()..init(),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => ActivityService(), lazy: false),
        ChangeNotifierProvider(create: (_) => VitalsStorageService()),
        ChangeNotifierProvider(create: (_) => DailySummaryService()),
      ],
      child: const SmartRingApp(),
    ),
  );
}

class SmartRingApp extends StatelessWidget {
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
