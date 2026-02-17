import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/activity_service.dart';
import 'package:ringularity/services/ble/ble_api_sync.dart';
import 'package:ringularity/services/ble/ble_logger.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/services/goal_service.dart';

import '../screens/animated_splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      ],
      child: const SmartRingApp(),
    ),
  );
}

class SmartRingApp extends StatelessWidget {
  const SmartRingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
